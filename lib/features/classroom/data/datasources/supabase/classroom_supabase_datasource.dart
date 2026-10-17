import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../lesson/data/models/question_model.dart';
import '../../../../lesson/domain/entities/question.dart';
import '../../../domain/entities/bank_question.dart';
import '../../../domain/entities/classroom_activity.dart';
import '../../../domain/entities/phase_attempt.dart';
import '../../../domain/entities/phase_rules.dart';
import '../../models/classroom_model.dart';
import '../../models/classroom_phase_model.dart';
import '../../models/classroom_result_model.dart';
import '../../models/phase_attempt_model.dart';

/// Acesso ao Supabase para a feature `classroom`.
///
/// Leituras que precisam de nomes de outros usuários (listas de salas,
/// resultados/ranking) passam por RPCs `SECURITY DEFINER` que devolvem JSON
/// pronto — contornam a RLS de `profiles`. As escritas de conteúdo (fases,
/// questões) vão direto pela tabela (gated pela RLS de dono).
class ClassroomSupabaseDatasource {
  ClassroomSupabaseDatasource(this._client);

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

  /// Envia as respostas para correção no servidor (RPC `submit_quiz`).
  /// [answers] = `{ questionId: índiceEscolhido }`.
  // ─── Tentativas (resposta a resposta, corrigidas no servidor) ───

  /// Abre uma tentativa na fase, ou retoma a que ficou pela metade.
  Future<PhaseAttempt> startAttempt({
    required String classroomId,
    required String phaseId,
  }) async {
    final data = await _client.rpc<dynamic>('start_attempt', params: {
      'p_classroom': classroomId,
      'p_phase': phaseId,
    },);
    return AttemptJson.attempt(Map<String, dynamic>.from(data as Map));
  }

  /// Com relógio: marca no servidor a hora em que a questão apareceu.
  Future<OpenedQuestion> openQuestion({
    required String attemptId,
    required String questionId,
  }) async {
    final data = await _client.rpc<dynamic>('open_question', params: {
      'p_attempt': attemptId,
      'p_question': questionId,
    },);
    return AttemptJson.opened(Map<String, dynamic>.from(data as Map));
  }

  /// Envia UMA resposta (`null` = sem resposta, quando o tempo acaba).
  Future<AnswerOutcome> answerQuestion({
    required String attemptId,
    required String questionId,
    Map<String, dynamic>? response,
  }) async {
    final data = await _client.rpc<dynamic>('answer_question', params: {
      'p_attempt': attemptId,
      'p_question': questionId,
      'p_response': response,
    },);
    return AttemptJson.outcome(Map<String, dynamic>.from(data as Map));
  }

  /// Alunos da turma (só o professor dono recebe a lista).
  Future<List<ClassroomMember>> fetchRoster(String classroomId) async {
    final data = await _client.rpc<dynamic>(
      'get_classroom_roster',
      params: {'p_classroom': classroomId},
    );
    return ((data as List?) ?? const [])
        .map((e) => AttemptJson.member(Map<String, dynamic>.from(e as Map)))
        .toList();
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

  /// Resultados POR FASE (cada item com `phaseId`) — para o dashboard.
  Future<List<ClassroomResultModel>> fetchPhaseResults(
    String classroomId,
  ) async {
    final data = await _client.rpc<dynamic>(
      'get_classroom_phase_results',
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
        'time_limit_s': q.timeLimitS,
        'content': q.content,
        'answer': q.answer,
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
    double weight = 1.0,
  }) async {
    final order = await _nextPhaseOrder(classroomId);
    final phaseRow = await _phases
        .insert({
          'classroom_id': classroomId,
          'title': title,
          'description': description,
          'sort_order': order,
          'weight': weight,
        })
        .select()
        .single();
    final phaseId = phaseRow['id'].toString();

    if (questions.isNotEmpty) {
      final rows = <Map<String, dynamic>>[
        for (var i = 0; i < questions.length; i++)
          _questionRow(questions[i], phaseId, i + 1),
      ];
      try {
        await _questions.insert(rows);
      } catch (_) {
        // Sem as questões (ex.: limite de armazenamento do plano), a fase
        // nova ficaria vazia na turma: desfaz e devolve o erro original.
        try {
          await _phases.delete().eq('id', phaseId);
        } catch (_) {}
        rethrow;
      }
    }

    return ClassroomPhaseModel.fromMap(
        phaseRow, questions.map(_toModel).toList(),);
  }

  /// Fases + questões de uma sala, COM gabarito — só o professor dono lê
  /// (a RLS de `questions` é só do dono). Usado pelas telas do professor.
  Future<List<ClassroomPhaseModel>> fetchClassroomPhases(
    String classroomId,
  ) async {
    // ATENÇÃO: no postgrest-dart, .order() é DECRESCENTE por padrão —
    // sem ascending: true, as fases apareciam de trás para frente para o
    // professor e a renumeração após exclusão invertia a ordem.
    final rows = await _phases
        .select('*, questions(*)')
        .eq('classroom_id', classroomId)
        .order('sort_order', ascending: true);

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

  /// Fases + questões para o ALUNO, SEM gabarito (RPC `get_student_phases`,
  /// `SECURITY DEFINER`). `correct_answer`/`explanation` não vêm no payload —
  /// o feedback só chega pela correção do servidor (`submit_quiz`) após o envio.
  Future<List<ClassroomPhaseModel>> fetchStudentPhases(
    String classroomId,
  ) async {
    final data = await _client.rpc<dynamic>(
      'get_student_phases',
      params: {'p_classroom': classroomId},
    );
    final list = (data as List?) ?? const [];
    final phases = <ClassroomPhaseModel>[];
    for (final raw in list) {
      final row = Map<String, dynamic>.from(raw as Map);
      final qRaw = ((row['questions'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
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
    double weight = 1.0,
  }) async {
    final order = await _nextPhaseOrder(classroomId);
    final phaseRow = await _phases
        .insert({
          'classroom_id': classroomId,
          'title': title,
          'description': description,
          'sort_order': order,
          'weight': weight,
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
    double weight = 1.0,
  }) async {
    await _phases.update({
      'title': title,
      'description': description,
      'weight': weight,
    }).eq('id', phaseId);
  }

  /// Prazo e nota mínima da fase. `null` limpa o ajuste (sem data / sem
  /// nota mínima).
  Future<void> updatePhaseRules({
    required String phaseId,
    required PhaseRules rules,
  }) async {
    await _phases.update({
      'opens_at': rules.opensAt?.toUtc().toIso8601String(),
      'closes_at': rules.closesAt?.toUtc().toIso8601String(),
      'pass_pct': rules.passPct,
      'timer_enabled': rules.timerEnabled,
      'timer_level': rules.timerLevel,
    }).eq('id', phaseId);
  }

  Future<void> deletePhase({
    required String classroomId,
    required String phaseId,
  }) async {
    await _phases.delete().eq('id', phaseId); // cascade apaga as questões
    await _renumberPhases(classroomId);
  }

  /// Fecha os buracos de posição deixados por uma exclusão (1, 2, 3...).
  Future<void> _renumberPhases(String classroomId) async {
    final rows = await _phases
        .select('id')
        .eq('classroom_id', classroomId)
        .order('sort_order', ascending: true);
    await reorderPhases(
      classroomId: classroomId,
      orderedPhaseIds: [
        for (final row in (rows as List).cast<Map<String, dynamic>>())
          row['id'].toString(),
      ],
    );
  }

  /// Grava a ordem inteira numa única operação no servidor: ou todas as
  /// fases mudam de posição, ou nenhuma (sem posições repetidas se a rede
  /// cair no meio). A lista precisa ter todas as fases da turma.
  Future<void> reorderPhases({
    required String classroomId,
    required List<String> orderedPhaseIds,
  }) async {
    await _client.rpc<void>(
      'reorder_phases',
      params: {'p_classroom': classroomId, 'p_phase_ids': orderedPhaseIds},
    );
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

  /// Questões de todas as turmas do professor logado (a RLS de `questions`
  /// só devolve as do dono), das mais novas para as mais antigas. Uma
  /// consulta só: a busca e os filtros rodam no app.
  Future<List<BankQuestion>> fetchQuestionBank() async {
    // Teto de segurança da consulta; os planos guardam até 600 questões.
    const maxRows = 2000;
    final rows = await _questions
        .select(
          'id, text, options, correct_answer, explanation, type, content, '
          'answer, time_limit_s, image_url, image_author, image_source, '
          'ai_generated, created_at, '
          'classroom_phases!inner(id, title, classrooms!inner(id, name))',
        )
        .order('created_at', ascending: false)
        .limit(maxRows);
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        _toBankQuestion(row),
    ];
  }

  BankQuestion _toBankQuestion(Map<String, dynamic> row) {
    final phase = Map<String, dynamic>.from(row['classroom_phases'] as Map);
    final classroom = Map<String, dynamic>.from(phase['classrooms'] as Map);
    return BankQuestion(
      question: QuestionModel.fromMap(row),
      classroomId: classroom['id'].toString(),
      classroomName: (classroom['name'] as String?) ?? '',
      phaseId: phase['id'].toString(),
      phaseTitle: (phase['title'] as String?) ?? '',
      aiGenerated: (row['ai_generated'] as bool?) ?? false,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
    );
  }

  /// Copia questões para o fim da fase numa única operação no servidor
  /// (RPC `copy_questions_to_phase`): ou todas entram, ou nenhuma. Cópia,
  /// não vínculo. Devolve quantas foram copiadas.
  Future<int> copyQuestionsToPhase({
    required String phaseId,
    required List<String> questionIds,
  }) async {
    final copied = await _client.rpc<dynamic>(
      'copy_questions_to_phase',
      params: {'p_phase': phaseId, 'p_question_ids': questionIds},
    );
    return (copied as num?)?.toInt() ?? 0;
  }

  /// Exclui questões das turmas do professor (pelo banco "Reutilizar
  /// minhas questões") numa única operação no servidor (RPC
  /// `delete_my_questions`): saem da fase em que estão e as fases afetadas
  /// são renumeradas. Devolve quantas foram excluídas.
  Future<int> deleteMyQuestions(List<String> questionIds) async {
    final deleted = await _client.rpc<dynamic>(
      'delete_my_questions',
      params: {'p_question_ids': questionIds},
    );
    return (deleted as num?)?.toInt() ?? 0;
  }

  /// Mesma garantia de [reorderPhases], para as questões de uma fase.
  Future<void> reorderQuestionsInPhase({
    required String classroomId,
    required String phaseId,
    required List<String> orderedQuestionIds,
  }) async {
    await _client.rpc<void>(
      'reorder_questions',
      params: {'p_phase': phaseId, 'p_question_ids': orderedQuestionIds},
    );
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
      'time_limit_s': question.timeLimitS,
      'content': question.content,
      'answer': question.answer,
    }).eq('id', question.id);
  }

  Future<void> deleteQuestionFromPhase({
    required String classroomId,
    required String phaseId,
    required String questionId,
  }) async {
    await _questions.delete().eq('id', questionId);
    // Renumera as questões restantes da fase (1, 2, 3...), de uma vez.
    final rows = await _questions
        .select('id')
        .eq('phase_id', phaseId)
        .order('sort_order', ascending: true);
    await reorderQuestionsInPhase(
      classroomId: classroomId,
      phaseId: phaseId,
      orderedQuestionIds: [
        for (final row in (rows as List).cast<Map<String, dynamic>>())
          row['id'].toString(),
      ],
    );
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
        timeLimitS: q.timeLimitS,
        content: q.content,
        answer: q.answer,
      );
}
