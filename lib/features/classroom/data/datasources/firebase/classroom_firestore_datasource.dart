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

  /// Apaga a sala e todas as suas subcoleções (questions, results,
  /// phases e as questões aninhadas em cada phase).
  ///
  /// O Firestore não cascateia delete automaticamente — sem essa
  /// limpeza manual, os documentos ficariam órfãos consumindo storage
  /// e poderiam ser lidos por queries cross-collection.
  ///
  /// Estratégia: coleta todos os refs, particiona em batches de até
  /// 500 operações (limite do Firestore) e commita em sequência.
  Future<void> deleteClassroom(String classroomId) async {
    final classroomRef = _classrooms.doc(classroomId);
    final refs = <DocumentReference<Map<String, dynamic>>>[];

    // Subcoleções planas: questions, results
    final flatSubcollections = ['questions', 'results'];
    for (final name in flatSubcollections) {
      final snap = await classroomRef.collection(name).get();
      refs.addAll(snap.docs.map((d) => d.reference));
    }

    // Subcoleção phases (cada uma com sua subcoleção questions)
    final phasesSnap = await classroomRef.collection('phases').get();
    for (final phaseDoc in phasesSnap.docs) {
      final phaseQuestionsSnap =
          await phaseDoc.reference.collection('questions').get();
      refs.addAll(phaseQuestionsSnap.docs.map((d) => d.reference));
      refs.add(phaseDoc.reference);
    }

    // Documento da própria sala — por último.
    refs.add(classroomRef);

    // Commita em chunks de 500 (limite do WriteBatch).
    const chunkSize = 500;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final end = (i + chunkSize) > refs.length ? refs.length : i + chunkSize;
      final batch = _firestore.batch();
      for (final ref in refs.sublist(i, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Busca uma sala pelo código de 6 caracteres.
  Future<ClassroomModel?> fetchByCode(String code) async {
    final snap = await _classrooms
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    List<QuestionModel> questions = [];
    try {
      questions = await _fetchQuestions(doc.id);
    } catch (_) {}
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
    List<QuestionModel> questions = [];
    try {
      questions = await _fetchQuestions(doc.id);
    } catch (_) {}
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

  /// Cria uma fase vazia (sem questões) com `order` igual ao final da
  /// lista — assim a fase nova aparece no fim da trilha.
  Future<ClassroomPhaseModel> createEmptyPhase({
    required String classroomId,
    required String title,
    required String description,
  }) async {
    final existingSnap = await _phasesRef(classroomId).get();
    final nextOrder = existingSnap.docs.length + 1;
    final now = DateTime.now();

    final phaseRef = await _phasesRef(classroomId).add({
      'name': title,
      'description': description,
      'order': nextOrder,
      'createdAt': Timestamp.fromDate(now),
    });

    return ClassroomPhaseModel(
      id: phaseRef.id,
      classroomId: classroomId,
      title: title,
      description: description,
      order: nextOrder,
      createdAt: now,
      questions: const [],
    );
  }

  /// Atualiza apenas o nome e a descrição de uma fase existente.
  Future<void> updatePhase({
    required String classroomId,
    required String phaseId,
    required String title,
    required String description,
  }) async {
    await _phasesRef(classroomId).doc(phaseId).update({
      'name': title,
      'description': description,
    });
  }

  /// Apaga uma fase e todas as questões dela. Renumera o `order` das
  /// fases restantes para manter a sequência contínua (1..N).
  Future<void> deletePhase({
    required String classroomId,
    required String phaseId,
  }) async {
    final phaseRef = _phasesRef(classroomId).doc(phaseId);

    // 1. Coleta refs das questões aninhadas.
    final questionsSnap = await phaseRef.collection('questions').get();

    // 2. Apaga em batches de 500.
    final refs = <DocumentReference<Map<String, dynamic>>>[
      ...questionsSnap.docs.map((d) => d.reference),
      phaseRef,
    ];
    const chunkSize = 500;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final end = (i + chunkSize) > refs.length ? refs.length : i + chunkSize;
      final batch = _firestore.batch();
      for (final ref in refs.sublist(i, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    // 3. Renumera as fases restantes.
    await _renumberPhases(classroomId);
  }

  /// Renumera o campo `order` das fases para garantir uma sequência
  /// contínua começando em 1.
  Future<void> _renumberPhases(String classroomId) async {
    final snap = await _phasesRef(classroomId).orderBy('order').get();
    final batch = _firestore.batch();
    for (var i = 0; i < snap.docs.length; i++) {
      batch.update(snap.docs[i].reference, {'order': i + 1});
    }
    await batch.commit();
  }

  /// Reordena fases conforme a nova lista de IDs (do topo para o fim).
  ///
  /// O índice do ID na lista vira o novo `order` (1-based).
  Future<void> reorderPhases({
    required String classroomId,
    required List<String> orderedPhaseIds,
  }) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedPhaseIds.length; i++) {
      batch.update(
        _phasesRef(classroomId).doc(orderedPhaseIds[i]),
        {'order': i + 1},
      );
    }
    await batch.commit();
  }

  /// Adiciona novas questões a uma fase JÁ existente, preservando as
  /// que já estão lá. O `order` das novas continua a partir do maior
  /// `order` atual.
  Future<void> addQuestionsToPhase({
    required String classroomId,
    required String phaseId,
    required List<Question> questions,
  }) async {
    if (questions.isEmpty) return;

    final existingSnap = await _phaseQuestionsRef(classroomId, phaseId).get();
    var nextOrder = existingSnap.docs.length;

    final batch = _firestore.batch();
    for (final q in questions) {
      nextOrder += 1;
      final qRef = _phaseQuestionsRef(classroomId, phaseId).doc();
      batch.set(qRef, {
        'text': q.text,
        'options': q.options,
        'correct_answer': q.correctAnswer,
        'explanation': q.explanation,
        'type': _questionTypeToInt(q.type),
        'image_url': q.imageUrl,
        'image_author': q.imageAuthor,
        'image_source': q.imageSource,
        'order': nextOrder,
      });
    }
    await batch.commit();
  }

  /// Reordena as questões dentro de uma fase, conforme a nova lista
  /// ordenada de IDs.
  Future<void> reorderQuestionsInPhase({
    required String classroomId,
    required String phaseId,
    required List<String> orderedQuestionIds,
  }) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedQuestionIds.length; i++) {
      batch.update(
        _phaseQuestionsRef(classroomId, phaseId).doc(orderedQuestionIds[i]),
        {'order': i + 1},
      );
    }
    await batch.commit();
  }

  /// Atualiza uma questão dentro de uma fase específica.
  Future<void> updateQuestionInPhase({
    required String classroomId,
    required String phaseId,
    required Question question,
  }) async {
    await _phaseQuestionsRef(classroomId, phaseId).doc(question.id).update({
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

  /// Apaga uma questão de uma fase e renumera as restantes.
  Future<void> deleteQuestionFromPhase({
    required String classroomId,
    required String phaseId,
    required String questionId,
  }) async {
    await _phaseQuestionsRef(classroomId, phaseId).doc(questionId).delete();

    // Renumera para manter sequência contínua.
    final snap = await _phaseQuestionsRef(classroomId, phaseId)
        .orderBy('order')
        .get();
    final batch = _firestore.batch();
    for (var i = 0; i < snap.docs.length; i++) {
      batch.update(snap.docs[i].reference, {'order': i + 1});
    }
    await batch.commit();
  }
}
