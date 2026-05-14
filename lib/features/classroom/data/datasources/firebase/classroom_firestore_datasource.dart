import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../lesson/data/models/question_model.dart';
import '../../../../lesson/domain/entities/question.dart';
import '../../models/classroom_model.dart';
import '../../models/classroom_phase_model.dart';
import '../../models/classroom_result_model.dart';

/// Camada de acesso ao Firestore para a feature `classroom`.
///
/// Segue o mesmo padrão de `LessonFirestoreDataSource`:
/// isola o SDK do Firestore para que domain/ e presentation/
/// não conheçam detalhes de persistência.
///
/// **Coleções:**
/// - `Classrooms` — documentos de sala
/// - `Classrooms/{id}/questions` — subcoleção de questões
/// - `Classrooms/{id}/results` — subcoleção de resultados
class ClassroomFirestoreDatasource {
  ClassroomFirestoreDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _classrooms =>
      _firestore.collection('Classrooms');

  // ─── Sala ──────────────────────────────────────────────────────

  /// Cria uma sala com código único de 6 caracteres.
  Future<ClassroomModel> createClassroom({
    required String name,
    required String description,
    required String teacherId,
    required String teacherName,
  }) async {
    final code = await _generateUniqueCode();
    final now = DateTime.now();

    final docRef = await _classrooms.add({
      'code': code,
      'name': name,
      'description': description,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'studentIds': <String>[],
      'createdAt': Timestamp.fromDate(now),
      'isActive': true,
    });

    return ClassroomModel(
      id: docRef.id,
      code: code,
      name: name,
      description: description,
      teacherId: teacherId,
      teacherName: teacherName,
      studentIds: const <String>[],
      createdAt: now,
      isActive: true,
      questions: const <QuestionModel>[],
    );
  }

  /// Atualiza nome e descrição de uma sala.
  Future<void> updateClassroom({
    required String classroomId,
    required String name,
    required String description,
  }) async {
    await _classrooms.doc(classroomId).update({
      'name': name,
      'description': description,
    });
  }

  /// Busca uma sala pelo código de 6 caracteres.
  Future<ClassroomModel?> fetchByCode(String code) async {
    final snap = await _classrooms
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final questions = await _fetchQuestions(doc.id);
    return ClassroomModel.fromSnapshot(doc, questions);
  }

  /// Lista todas as salas de um professor.
  Future<List<ClassroomModel>> fetchTeacherClassrooms(String teacherId) async {
    final snap = await _classrooms
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .get();

    final classrooms = <ClassroomModel>[];
    for (final doc in snap.docs) {
      final questions = await _fetchQuestions(doc.id);
      classrooms.add(ClassroomModel.fromSnapshot(doc, questions));
    }
    return classrooms;
  }

  /// Retorna a sala em que o aluno está (ou null).
  Future<ClassroomModel?> fetchStudentClassroom(String studentId) async {
    final snap = await _classrooms
        .where('studentIds', arrayContains: studentId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final questions = await _fetchQuestions(doc.id);
    return ClassroomModel.fromSnapshot(doc, questions);
  }

  // ─── Aluno entra/sai ──────────────────────────────────────────

  /// Adiciona o uid do aluno ao array `studentIds`.
  Future<void> joinClassroom({
    required String classroomId,
    required String studentId,
  }) async {
    await _classrooms.doc(classroomId).update({
      'studentIds': FieldValue.arrayUnion([studentId]),
    });
  }

  /// Remove o uid do aluno do array `studentIds`.
  Future<void> leaveClassroom({
    required String classroomId,
    required String studentId,
  }) async {
    await _classrooms.doc(classroomId).update({
      'studentIds': FieldValue.arrayRemove([studentId]),
    });
  }

  // ─── Questões (subcoleção) ────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _questionsRef(
    String classroomId,
  ) =>
      _classrooms.doc(classroomId).collection('questions');

  /// Busca todas as questões de uma sala, ordenadas por `order`.
  Future<List<QuestionModel>> _fetchQuestions(String classroomId) async {
    final snap = await _questionsRef(classroomId)
        .orderBy('order')
        .get();
    return snap.docs.map<QuestionModel>(QuestionModel.fromSnapshot).toList();
  }

  /// Busca pública de questões (usada pelo repository).
  Future<List<QuestionModel>> fetchQuestions(String classroomId) {
    return _fetchQuestions(classroomId);
  }

  /// Adiciona uma questão à subcoleção.
  Future<void> addQuestion({
    required String classroomId,
    required Question question,
  }) async {
    // Calcula a próxima ordem.
    final existing = await _questionsRef(classroomId).count().get();
    final nextOrder = (existing.count ?? 0) + 1;

    await _questionsRef(classroomId).add({
      'text': question.text,
      'options': question.options,
      'correct_answer': question.correctAnswer,
      'explanation': question.explanation,
      'type': _questionTypeToInt(question.type),
      'image_url': question.imageUrl,
      'image_author': question.imageAuthor,
      'image_source': question.imageSource,
      'order': nextOrder,
    });
  }

  /// Atualiza uma questão existente.
  Future<void> updateQuestion({
    required String classroomId,
    required Question question,
  }) async {
    await _questionsRef(classroomId).doc(question.id).update({
      'text': question.text,
      'options': question.options,
      'correct_answer': question.correctAnswer,
      'explanation': question.explanation,
      'type': _questionTypeToInt(question.type),
      'image_url': question.imageUrl,
      'image_author': question.imageAuthor,
      'image_source': question.imageSource,
    });
  }

  /// Exclui uma questão.
  Future<void> deleteQuestion({
    required String classroomId,
    required String questionId,
  }) async {
    await _questionsRef(classroomId).doc(questionId).delete();
  }

  // ─── Resultados (subcoleção) ──────────────────────────────────

  CollectionReference<Map<String, dynamic>> _resultsRef(
    String classroomId,
  ) =>
      _classrooms.doc(classroomId).collection('results');

  /// Salva (ou sobrescreve) o resultado de um aluno.
  /// O document ID é o uid do aluno — garante 1 resultado por aluno.
  Future<void> submitResult({
    required String classroomId,
    required ClassroomResultModel result,
  }) async {
    await _resultsRef(classroomId)
        .doc(result.studentId)
        .set(result.toFirestore());
  }

  /// Retorna todos os resultados de uma sala.
  Future<List<ClassroomResultModel>> fetchResults(String classroomId) async {
    final snap = await _resultsRef(classroomId).get();
    return snap.docs.map<ClassroomResultModel>(ClassroomResultModel.fromSnapshot).toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────

  /// Gera um código de 6 caracteres sem ambiguidades e verifica
  /// no Firestore se já existe. Repete até encontrar um único.
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();

    while (true) {
      final code = List.generate(
        6,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();

      final exists = await _classrooms
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (exists.docs.isEmpty) return code;
    }
  }

  int _questionTypeToInt(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 0;
      case QuestionType.fillBlanks:
        return 1;
      case QuestionType.trueFalse:
        return 2;
      case QuestionType.unknown:
        return -1;
    }
  }

  // ─── Fases de sala (subcoleção phases dentro de Classrooms) ────

  /// Referência à subcoleção `phases` de uma sala.
  CollectionReference<Map<String, dynamic>> _phasesRef(
    String classroomId,
  ) =>
      _classrooms.doc(classroomId).collection('phases');

  /// Referência à subcoleção `questions` de uma fase dentro de uma sala.
  CollectionReference<Map<String, dynamic>> _phaseQuestionsRef(
    String classroomId,
    String phaseId,
  ) =>
      _phasesRef(classroomId).doc(phaseId).collection('questions');

  /// Cria uma fase vinculada a uma sala de aula e salva todas as questões
  /// como subcoleção da fase.
  ///
  /// Estrutura: `Classrooms/{classroomId}/phases/{phaseId}/questions/{qId}`
  ///
  /// Usa batch write para garantir atomicidade: ou tudo é criado,
  /// ou nada.
  Future<ClassroomPhaseModel> saveQuizAsPhase({
    required String classroomId,
    required String title,
    required String description,
    required List<Question> questions,
  }) async {
    // Calcula a próxima ordem para fases desta sala.
    final existingSnap = await _phasesRef(classroomId).get();
    final nextOrder = existingSnap.docs.length + 1;

    final now = DateTime.now();
    final batch = _firestore.batch();

    // 1. Cria o documento da fase na subcoleção.
    final phaseRef = _phasesRef(classroomId).doc();
    batch.set(phaseRef, {
      'name': title,
      'description': description,
      'order': nextOrder,
      'createdAt': Timestamp.fromDate(now),
    });

    // 2. Cria cada questão como subdocumento da fase.
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final questionRef = phaseRef.collection('questions').doc();
      batch.set(questionRef, {
        'text': q.text,
        'options': q.options,
        'correct_answer': q.correctAnswer,
        'explanation': q.explanation,
        'type': _questionTypeToInt(q.type),
        'image_url': q.imageUrl,
        'image_author': q.imageAuthor,
        'image_source': q.imageSource,
        'order': i + 1,
      });
    }

    await batch.commit();

    // Retorna o model com as questões incluídas.
    return ClassroomPhaseModel(
      id: phaseRef.id,
      classroomId: classroomId,
      title: title,
      description: description,
      order: nextOrder,
      createdAt: now,
      questions: questions,
    );
  }

  /// Retorna todas as fases vinculadas a uma sala de aula,
  /// ordenadas por `order`.
  Future<List<ClassroomPhaseModel>> fetchClassroomPhases(
    String classroomId,
  ) async {
    final snap = await _phasesRef(classroomId)
        .orderBy('order')
        .get();

    final phases = <ClassroomPhaseModel>[];
    for (final doc in snap.docs) {
      // Busca as questões da subcoleção desta fase.
      final questionsSnap = await doc.reference
          .collection('questions')
          .orderBy('order')
          .get();
      final questions =
          questionsSnap.docs.map(QuestionModel.fromSnapshot).toList();
      phases.add(ClassroomPhaseModel.fromSnapshot(doc, questions));
    }
    return phases;
  }
}
