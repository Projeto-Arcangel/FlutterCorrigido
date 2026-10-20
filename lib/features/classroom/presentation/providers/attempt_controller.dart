import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../../../lesson/domain/entities/question_kinds.dart';
import '../../domain/entities/phase_attempt.dart';
import '../../domain/repositories/classroom_repository.dart';
import 'classroom_providers.dart';

typedef AttemptArgs = ({String classroomId, String phaseId});

enum AttemptStage {
  /// Abrindo (ou retomando) a tentativa no servidor.
  loading,

  /// Com relógio: avisando o servidor que a questão apareceu.
  opening,

  /// Escolhendo a resposta.
  playing,

  /// Resposta enviada, esperando a correção.
  sending,

  /// Resposta travada: mostra se acertou e a certa.
  feedback,

  /// Tentativa entregue: mostra o resultado.
  finished,

  error,
}

/// Relógio do aparelho (trocado nos testes).
final attemptClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

class AttemptViewState {
  final AttemptStage stage;
  final PhaseAttempt? attempt;

  /// Questão atual, em `attempt.questions`.
  final int index;

  /// Alternativa marcada (ainda não confirmada), na múltipla escolha.
  final int? selected;

  /// Resposta em montagem nos tipos novos — ligar: `{'match': [...]}`
  /// (`null` = fio solto); ordenar: `{'order': [...]}`; lacunas:
  /// `{'blanks': [...]}` (`null` = vazia). Depois de confirmar, é a
  /// resposta que foi enviada.
  final Map<String, dynamic>? draft;

  /// Respostas travadas, por id da questão.
  final Map<String, AnswerFeedback> answers;
  final int points;
  final int streak;

  /// Relógio da questão atual: até quando dá para responder e o total.
  final DateTime? deadline;
  final int? limitS;

  final AttemptResult? result;
  final String? error;

  /// Recusa das regras da fase (fechou, bloqueada): repetir não adianta.
  final bool errorIsFinal;

  const AttemptViewState({
    this.stage = AttemptStage.loading,
    this.attempt,
    this.index = 0,
    this.selected,
    this.draft,
    this.answers = const {},
    this.points = 0,
    this.streak = 0,
    this.deadline,
    this.limitS,
    this.result,
    this.error,
    this.errorIsFinal = false,
  });

  Question? get question {
    final qs = attempt?.questions;
    return qs == null || index >= qs.length ? null : qs[index];
  }

  /// Correção da questão atual (depois de confirmar).
  AnswerFeedback? get feedback {
    final q = question;
    return q == null ? null : answers[q.id];
  }

  int get total => attempt?.questions.length ?? 0;

  /// Dá para confirmar: na múltipla escolha, marcou; no ligar, todos os
  /// fios ligados; nas lacunas, todas preenchidas; no ordenar, sempre (a
  /// ordem atual é a resposta).
  bool get canConfirm {
    final q = question;
    if (stage != AttemptStage.playing || q == null) return false;
    return switch (q.type) {
      QuestionType.matchColumns =>
        (draft?['match'] as List?)?.every((m) => m != null) ?? false,
      QuestionType.fillBlanks =>
        (draft?['blanks'] as List?)?.every((b) => b != null) ?? false,
      // Cruzadinha e caça-palavras: entrega o que tiver (vale por palavra).
      QuestionType.crossword || QuestionType.wordSearch => draft != null,
      QuestionType.ordering => draft?['order'] is List,
      _ => selected != null,
    };
  }

  AttemptViewState copyWith({
    AttemptStage? stage,
    PhaseAttempt? attempt,
    int? index,
    int? Function()? selected,
    Map<String, dynamic>? Function()? draft,
    Map<String, AnswerFeedback>? answers,
    int? points,
    int? streak,
    DateTime? Function()? deadline,
    int? Function()? limitS,
    AttemptResult? Function()? result,
    String? Function()? error,
    bool? errorIsFinal,
  }) {
    return AttemptViewState(
      stage: stage ?? this.stage,
      attempt: attempt ?? this.attempt,
      index: index ?? this.index,
      selected: selected != null ? selected() : this.selected,
      draft: draft != null ? draft() : this.draft,
      answers: answers ?? this.answers,
      points: points ?? this.points,
      streak: streak ?? this.streak,
      deadline: deadline != null ? deadline() : this.deadline,
      limitS: limitS != null ? limitS() : this.limitS,
      result: result != null ? result() : this.result,
      error: error != null ? error() : this.error,
      errorIsFinal: errorIsFinal ?? this.errorIsFinal,
    );
  }
}

/// Uma tentativa da fase, resposta a resposta. Tudo que vale nota é
/// decidido no servidor; aqui só se mostra e se manda a resposta.
class AttemptController
    extends AutoDisposeFamilyNotifier<AttemptViewState, AttemptArgs> {
  Timer? _clock;
  bool _disposed = false;

  /// O que repetir depois de uma falha de rede.
  Future<void> Function()? _retry;

  ClassroomRepository get _repo => ref.read(classroomRepositoryProvider);
  DateTime _now() => ref.read(attemptClockProvider)();

  @override
  AttemptViewState build(AttemptArgs arg) {
    ref.onDispose(() {
      _disposed = true;
      _clock?.cancel();
    });
    Future.microtask(start);
    return const AttemptViewState();
  }

  /// Abre a tentativa, ou retoma a que ficou pela metade.
  Future<void> start() async {
    _clock?.cancel();
    _set(const AttemptViewState());
    final res = await _repo.startAttempt(
      classroomId: arg.classroomId,
      phaseId: arg.phaseId,
    );
    if (_disposed) return;
    res.fold(
      (f) => _fail(f, start),
      (attempt) {
        final answers = {for (final a in attempt.answers) a.questionId: a};
        final base = AttemptViewState(
          attempt: attempt,
          answers: answers,
          points: attempt.points,
          streak: attempt.streak,
          result: attempt.result,
        );
        if (attempt.finished) {
          _set(base.copyWith(stage: AttemptStage.finished));
          return;
        }
        final next = attempt.questions
            .indexWhere((q) => q.id == attempt.nextQuestionId);
        final index = next < 0 ? 0 : next;
        _set(base.copyWith(
          index: index,
          draft: () => index < attempt.questions.length
              ? _initialDraft(attempt.questions[index])
              : null,
        ),);
        _present(opened: attempt.opened);
      },
    );
  }

  /// Nova tentativa depois do resultado ("Tentar novamente").
  Future<void> restart() => start();

  /// Depois de um erro de rede: repete o que falhou.
  Future<void> retry() async {
    final again = _retry;
    if (again != null) await again();
  }

  void select(int option) {
    if (state.stage != AttemptStage.playing) return;
    _set(state.copyWith(selected: () => option));
  }

  /// Ligar/ordenar: atualiza a resposta em montagem.
  void setDraft(Map<String, dynamic> draft) {
    if (state.stage != AttemptStage.playing) return;
    _set(state.copyWith(draft: () => draft));
  }

  /// Atualiza só as chaves dadas da resposta em montagem (as palavras da
  /// cruzadinha sem perder as já conferidas, por exemplo).
  void patchDraft(Map<String, dynamic> patch) {
    if (state.stage != AttemptStage.playing) return;
    _set(state.copyWith(draft: () => {...?state.draft, ...patch}));
  }

  /// Cruzadinha com acertos na hora: confere a palavra [index] no servidor.
  /// Certa, entra em `ok` (fica travada na grade). [correct] nulo = não deu
  /// para conferir, e [error] diz por quê.
  Future<({bool? correct, String? error})> checkCrosswordWord(
    int index,
    String word,
  ) async {
    final q = state.question;
    final attempt = state.attempt;
    if (q == null || attempt == null || state.stage != AttemptStage.playing) {
      return (correct: null, error: null);
    }
    final res = await _repo.checkAnswerPart(
      attemptId: attempt.attemptId,
      questionId: q.id,
      part: {'index': index, 'word': word},
    );
    if (_disposed) return (correct: null, error: null);
    return res.fold(
      (f) => (correct: null, error: f.message),
      (check) {
        if (check.correct && _stillOn(q)) {
          final ok = {..._ints(state.draft?['ok']), index}.toList()..sort();
          patchDraft({'ok': ok});
        }
        return (correct: check.correct, error: null);
      },
    );
  }

  /// Caça-palavras com acertos na hora: confere no servidor uma marcação que
  /// pode ser uma palavra oculta. Achou: a marcação entra em `found` e a
  /// palavra em `known` (índice → texto), para a lista mostrá-la.
  Future<({bool found, String? error})> checkWordSearchMark(
    List<int> sel,
  ) async {
    final q = state.question;
    final attempt = state.attempt;
    if (q == null || attempt == null || state.stage != AttemptStage.playing) {
      return (found: false, error: null);
    }
    final res = await _repo.checkAnswerPart(
      attemptId: attempt.attemptId,
      questionId: q.id,
      part: {'sel': sel},
    );
    if (_disposed) return (found: false, error: null);
    return res.fold(
      (f) => (found: false, error: f.message),
      (check) {
        final index = check.index;
        final word = check.word;
        if (index == null || word == null) return (found: false, error: null);
        if (_stillOn(q)) {
          patchDraft({
            'found': [..._positions(state.draft?['found']), sel],
            'known': {
              ...?(state.draft?['known'] as Map?)
                  ?.map((k, v) => MapEntry('$k', '$v')),
              '$index': word,
            },
          });
        }
        return (found: true, error: null);
      },
    );
  }

  /// A conferência voltou e o aluno ainda está na mesma questão.
  bool _stillOn(Question q) =>
      state.question?.id == q.id && state.stage == AttemptStage.playing;

  static List<int> _ints(Object? value) => [
        for (final v in (value as List?) ?? const [])
          if (v is num) v.toInt(),
      ];

  static List<List<int>> _positions(Object? value) => [
        for (final p in (value as List?) ?? const [])
          if (p is List) [for (final v in p) (v as num).toInt()],
      ];

  /// Confirma a resposta: trava e manda corrigir.
  Future<void> confirm() async {
    if (!state.canConfirm) return;
    final q = state.question!;
    await _send(
      q.type.usesContent ? state.draft : {'choice': state.selected},
    );
  }

  /// Próxima questão (ou o resultado, se foi a última).
  Future<void> next() async {
    if (state.stage != AttemptStage.feedback) return;
    if (state.result != null) {
      _set(state.copyWith(stage: AttemptStage.finished));
      return;
    }
    final qs = state.attempt!.questions;
    var i = state.index + 1;
    while (i < qs.length && state.answers.containsKey(qs[i].id)) {
      i++;
    }
    if (i >= qs.length) {
      // Não falta nenhuma, mas o resultado não veio (a última travou por
      // tempo ao retomar): o servidor entrega ao reabrir.
      await start();
      return;
    }
    // O relógio já mostra o tempo cheio da próxima (parado até o servidor
    // abrir a questão), nunca o prazo vencido da anterior.
    final limit = state.attempt!.timeLimits[qs[i].id];
    _set(state.copyWith(
      index: i,
      selected: () => null,
      draft: () => _initialDraft(qs[i]),
      limitS: () => limit,
      deadline: () =>
          limit == null ? null : _now().add(Duration(seconds: limit)),
    ),);
    await _present();
  }

  /// Resposta inicial dos tipos novos: tudo solto (ligar), lacunas
  /// vazias ou a ordem em que os itens chegaram (ordenar).
  static Map<String, dynamic>? _initialDraft(Question q) => switch (q.type) {
        QuestionType.matchColumns => {
            'match': List<int?>.filled(q.matchLeft.length, null),
          },
        QuestionType.ordering => {
            'order': List<int>.generate(q.orderingItems.length, (i) => i),
          },
        QuestionType.fillBlanks => {
            'blanks': List<int?>.filled(q.interactions, null),
          },
        QuestionType.crossword => {
            'words': [for (final s in q.crosswordSlots) ' ' * s.len],
          },
        QuestionType.wordSearch => {'found': <List<int>>[]},
        _ => null,
      };

  // ── Interno ──────────────────────────────────────────────────────

  Future<void> _present({OpenedQuestion? opened}) async {
    final attempt = state.attempt!;
    final q = state.question!;
    if (!attempt.timerEnabled) {
      _set(state.copyWith(
        stage: AttemptStage.playing,
        deadline: () => null,
        limitS: () => null,
      ),);
      return;
    }

    var open = opened != null && opened.questionId == q.id ? opened : null;
    if (open == null) {
      _set(state.copyWith(stage: AttemptStage.opening));
      final res = await _repo.openQuestion(
        attemptId: attempt.attemptId,
        questionId: q.id,
      );
      if (_disposed) return;
      final failure = res.fold((f) => f, (_) => null);
      if (failure != null) {
        _fail(failure, _present);
        return;
      }
      open = (res as Right<Failure, OpenedQuestion>).value;
    }

    final expired = open.expired;
    if (expired != null) {
      // Saiu e voltou depois do tempo: a questão já valeu 0 (o relógio
      // aparece parado em 0, como num tempo esgotado na tela).
      _set(state.copyWith(
        stage: AttemptStage.feedback,
        answers: {...state.answers, q.id: expired},
        streak: 0,
        limitS: () => open!.limitS,
        deadline: _now,
      ),);
      return;
    }

    final remainingMs = ((open.remainingS ?? 0) * 1000).round();
    final deadline = _now().add(Duration(milliseconds: remainingMs));
    _set(state.copyWith(
      stage: AttemptStage.playing,
      deadline: () => deadline,
      limitS: () => open!.limitS,
    ),);
    _clock?.cancel();
    _clock = Timer(Duration(milliseconds: remainingMs), _timeUp);
  }

  /// O tempo acabou: manda sem resposta (o servidor dá 0).
  void _timeUp() {
    if (_disposed) return;
    if (state.stage == AttemptStage.playing) _send(null);
  }

  Future<void> _send(Map<String, dynamic>? response) async {
    _clock?.cancel();
    final attempt = state.attempt!;
    final q = state.question!;
    _set(state.copyWith(stage: AttemptStage.sending));
    final res = await _repo.answerQuestion(
      attemptId: attempt.attemptId,
      questionId: q.id,
      response: response,
    );
    if (_disposed) return;
    res.fold(
      (f) => _fail(f, () => _send(response)),
      // O relógio fica parado na tela (sem sumir e empurrar a questão).
      (outcome) => _set(state.copyWith(
        stage: AttemptStage.feedback,
        answers: {...state.answers, q.id: outcome.feedback},
        points: outcome.totalPoints,
        streak: outcome.feedback.streak,
        result: () => outcome.result,
      ),),
    );
  }

  void _fail(Failure f, Future<void> Function() retry) {
    _clock?.cancel();
    _retry = retry;
    _set(state.copyWith(
      stage: AttemptStage.error,
      error: () => f.message,
      errorIsFinal: f is ValidationFailure,
    ),);
  }

  void _set(AttemptViewState value) {
    if (!_disposed) state = value;
  }
}

final attemptControllerProvider = NotifierProvider.autoDispose
    .family<AttemptController, AttemptViewState, AttemptArgs>(
  AttemptController.new,
);
