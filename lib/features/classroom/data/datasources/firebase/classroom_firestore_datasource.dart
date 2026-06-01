import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../lesson/data/models/question_model.dart';
import '../../../../lesson/domain/entities/question.dart';
import '../../../domain/entities/classroom_activity.dart';
import '../../models/classroom_model.dart';
import '../../models/classroom_phase_model.dart';
import '../../models/classroom_result_model.dart';

/// Acesso ao Supabase para a feature `classroom`.
///
/// Mantém o nome legado (`...FirestoreDatasource`) para não ripple no
/// repository/providers durante a migração; será renomeado na limpeza final.
///
/// Leituras que precisam de nomes de outros usuários (listas de salas,
/// resultados/ranking) passam por RPCs `SECURITY DEFINER` que devolvem JSON
/// pronto — contornam a RLS de `profiles`. As escritas de conteúdo (fases,
/// questões) vão direto pela tabela (gated pela RLS de dono).
class ClassroomFirestoreDatasource {
  ClassroomFirestoreDatasource(this._client);

  final SupabaseClient _client;

  // ─── Sala ──────────────────────────────────────────────────────

  Future<ClassroomModel> createClassroom({
    required String name,
    required String description,
    required String teacherId,
    required String teacherName,
  }) async {
    final data = await _client.rpc<dynamic>(
      'create_classroom',
      params: {'p_name': name, 'p_description': description},
    );
    final row = (data is List ? data.first : data) as Map<String, dynamic>;
    return ClassroomModel(
      id: row['id'].toString(),
      code: (row['code'] as String?) ?? '',
      name: name,
      description: description,
      teacherId: (row['teacher_id'] as String?) ?? teacherId,
      teacherName: teacherName,
      studentIds: const [],
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isActive: (row['is_active'] as bool?) ?? true,
      questions: const [],
    );
  }

  Future<void> updateClassroom({
    required String classroomId,
    required String name,
    required String description,
  }) async {
    await _client.from('classrooms').update(
        {'name': name, 'description': description},).eq('id', classroomId);
  }

  /// No Supabase o nome do professor vem por join (RPCs de leitura), então
  /// não há `teacher_name` desnormalizado para sincronizar. No-op.
  Future<void> updateTeacherName({
    required String teacherId,
    required String newName,
  }) async {}

  Future<void> deleteClassroom(String classroomId) async {
    // ON DELETE CASCADE apaga members, phases, questions, results e activities.
    await _client.from('classrooms').delete().eq('id', classroomId);
  }

  Future<ClassroomModel?> fetchByCode(String code) async {
    final data = await _client.rpc<dynamic>(
      'get_classroom_by_code',
      params: {'p_code': code},
    );
    if (data == null) return null;
    return ClassroomModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<List<ClassroomModel>> fetchTeacherClassrooms(String teacherId) async {
    final data = await _client.rpc<dynamic>('get_teacher_classrooms');
    return _mapClassrooms(data);
  }

  Future<List<ClassroomModel>> fetchStudentClassrooms(String studentId) async {
    final data = await _client.rpc<dynamic>('get_student_classrooms');
    return _mapClassrooms(data);
  }

  List<ClassroomModel> _mapClassrooms(dynamic data) {
    final list = (data as List?) ?? const [];
    return list
        .map((e) => ClassroomModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─── Aluno entra/sai ──────────────────────────────────────────

  Future<void> joinClassroom({
    required String classroomId,
    required String studentId,
    String? studentName,
  }) async {
    await _client
        .rpc<void>('join_classroom', params: {'p_classroom': classroomId});
  }

  Future<void> leaveClassroom({
    required String classroomId,
    required String studentId,
  }) async {
    await _client
        .from('classroom_members')
        .delete()
        .eq('classroom_id', classroomId)
        .eq('student_id', studentId);
  }

  // ─── Questões soltas de sala — não existem no schema Supabase ──
  // O conteúdo vive em fases. Métodos mantidos por contrato; getQuestions
  // devolve vazio e os mutadores são no-op.

  Future<List<QuestionModel>> fetchQuestions(String classroomId) async =>
      const [];

  Future<void> addQuestion({
    required String classroomId,
    required Question question,
  }) async {}

  Future<void> updateQuestion({
    required String classroomId,
    required Question question,
  }) async {}

  Future<void> deleteQuestion({
    required String classroomId,
    required String questionId,
  }) async {}

  // ─── Resultados ───────────────────────────────────────────────

  Future<void> submitResult({
    required String classroomId,
    required ClassroomResultModel result,
    String? phaseTitle,
  }) async {
    await _client.rpc<void>('submit_result', params: {
      'p_classroom': classroomId,
      'p_total': result.totalQuestions,
      'p_correct': result.correctAnswers,
      'p_phase_title': phaseTitle,
    },);
  }

  Future<List<ClassroomResultModel>> fetchResults(String classroomId) async {
    final data = await _client.rpc<dynamic>(
      'get_classroom_results',
      params: {'p_classroom': classroomId},
    );
    final list = (data as List?) ?? const [];
    return list
        .map((e) =>
            ClassroomResultModel.fromMap(Map<String, dynamic>.from(e as Map)),)
        .toList();
  }

  // ─── Fases ────────────────────────────────────────────────────

  SupabaseQueryBuilder get _phases => _client.from('classroom_phases');
  SupabaseQueryBuilder get _questions => _client.from('questions');

  Map<String, dynamic> _questionRow(Question q, String phaseId, int order) => {
        'phase_id': phaseId,
        'text': q.text,
        'options': q.options,
        'correct_answer': q.correctAnswer,
        'explanation': q.explanation,
        'type': QuestionModel.questionTypeToDb(q.type),
        'image_url': q.imageUrl,
        'image_author': q.imageAuthor,
        'image_source': q.imageSource,
        'sort_order': order,
      };

  Future<int> _nextPhaseOrder(String classroomId) async {
    final rows = await _phases.select('id').eq('classroom_id', classroomId);
    return (rows as List).length + 1;
  }

  Future<ClassroomPhaseModel> saveQuizAsPhase({
    required String classroomId,
    required String title,
    required String description,
    required List<Question> questions,
  }) async {
    final order = await _nextPhaseOrder(classroomId);
    final phaseRow = await _phases
        .insert({
          'classroom_id': classroomId,
          'title': title,
          'description': description,
          'sort_order': order,
        })
        .select()
        .single();
    final phaseId = phaseRow['id'].toString();

    if (questions.isNotEmpty) {
      final rows = <Map<String, dynamic>>[
        for (var i = 0; i < questions.length; i++)
          _questionRow(questions[i], phaseId, i + 1),
      ];
      await _questions.insert(rows);
    }

    return ClassroomPhaseModel.fromMap(
        phaseRow, questions.map(_toModel).toList(),);
  }

  Future<List<ClassroomPhaseModel>> fetchClassroomPhases(
    String classroomId,
  ) async {
    final rows = await _phases
        .select('*, questions(*)')
        .eq('classroom_id', classroomId)
        .order('sort_order');

    final phases = <ClassroomPhaseModel>[];
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final qRaw = ((row['questions'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
        ..sort((a, b) => ((a['sort_order'] as num?) ?? 0)
            .compareTo((b['sort_order'] as num?) ?? 0),);
      final questions = qRaw.map(QuestionModel.fromMap).toList();
      phases.add(ClassroomPhaseModel.fromMap(row, questions));
    }
    return phases;
  }

  Future<ClassroomPhaseModel> createEmptyPhase({
    required String classroomId,
    required String title,
    required String description,
  }) async {
    final order = await _nextPhaseOrder(classroomId);
    final phaseRow = await _phases
        .insert({
          'classroom_id': classroomId,
          'title': title,
          'description': description,
          'sort_order': order,
        })
        .select()
        .single();
    return ClassroomPhaseModel.fromMap(phaseRow, const []);
  }

  Future<void> updatePhase({
    required String classroomId,
    required String phaseId,
    required String title,
    required String description,
  }) async {
    await _phases
        .update({'title': title, 'description': description}).eq('id', phaseId);
  }

  Future<void> deletePhase({
    required String classroomId,
    required String phaseId,
  }) async {
    await _phases.delete().eq('id', phaseId); // cascade apaga as questões
    await _renumberPhases(classroomId);
  }

  Future<void> _renumberPhases(String classroomId) async {
    final rows = await _phases
        .select('id')
        .eq('classroom_id', classroomId)
        .order('sort_order');
    var order = 1;
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      await _phases
          .update({'sort_order': order}).eq('id', row['id'].toString());
      order++;
    }
  }

  Future<void> reorderPhases({
    required String classroomId,
    required List<String> orderedPhaseIds,
  }) async {
    for (var i = 0; i < orderedPhaseIds.length; i++) {
      await _phases.update({'sort_order': i + 1}).eq('id', orderedPhaseIds[i]);
    }
  }

  Future<void> addQuestionsToPhase({
    required String classroomId,
    required String phaseId,
    required List<Question> questions,
  }) async {
    if (questions.isEmpty) return;
    final existing = await _questions.select('id').eq('phase_id', phaseId);
    var order = (existing as List).length;
    final rows = <Map<String, dynamic>>[
      for (final q in questions) _questionRow(q, phaseId, ++order),
    ];
    await _questions.insert(rows);
  }

  Future<void> reorderQuestionsInPhase({
    required String classroomId,
    required String phaseId,
    required List<String> orderedQuestionIds,
  }) async {
    for (var i = 0; i < orderedQuestionIds.length; i++) {
      await _questions
          .update({'sort_order': i + 1}).eq('id', orderedQuestionIds[i]);
    }
  }

  Future<void> updateQuestionInPhase({
    required String classroomId,
    required String phaseId,
    required Question question,
  }) async {
    await _questions.update({
      'text': question.text,
      'options': question.options,
      'correct_answer': question.correctAnswer,
      'explanation': question.explanation,
      'type': QuestionModel.questionTypeToDb(question.type),
      'image_url': question.imageUrl,
      'image_author': question.imageAuthor,
      'image_source': question.imageSource,
    }).eq('id', question.id);
  }

  Future<void> deleteQuestionFromPhase({
    required String classroomId,
    required String phaseId,
    required String questionId,
  }) async {
    await _questions.delete().eq('id', questionId);
    // Renumera as questões restantes da fase.
    final rows = await _questions
        .select('id')
        .eq('phase_id', phaseId)
        .order('sort_order');
    var order = 1;
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      await _questions
          .update({'sort_order': order}).eq('id', row['id'].toString());
      order++;
    }
  }

  // ─── Atividades ───────────────────────────────────────────────

  Future<List<ClassroomActivity>> fetchRecentActivities(
    String teacherId, {
    int limit = 3,
  }) async {
    // A RLS já restringe às salas do professor logado.
    final rows = await _client
        .from('classroom_activities')
        .select('type, description, created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>().map((data) {
      return ClassroomActivity(
        type: (data['type'] as String?) ?? '',
        description: (data['description'] as String?) ?? '',
        createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  QuestionModel _toModel(Question q) => QuestionModel(
        id: q.id,
        text: q.text,
        options: q.options,
        correctAnswer: q.correctAnswer,
        explanation: q.explanation,
        type: q.type,
        imageUrl: q.imageUrl,
        imageAuthor: q.imageAuthor,
        imageSource: q.imageSource,
      );
}
