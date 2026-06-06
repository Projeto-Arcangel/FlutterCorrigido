import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/question.dart';

part 'quiz_controller.g.dart';

class QuizState {
  final int currentIndex;
  final Map<int, int> answers;
  final bool finished;
  final int correctCount;
  final double xpEarned;
  final int goldEarned;
  final bool xpSaved;
  final bool confirmed;

  const QuizState({
    this.currentIndex = 0,
    this.answers = const {},
    this.finished = false,
    this.correctCount = 0,
    this.xpEarned = 0,
    this.goldEarned = 0,
    this.xpSaved = false,
    this.confirmed = false,
  });

  QuizState copyWith({
    int? currentIndex,
    Map<int, int>? answers,
    bool? finished,
    int? correctCount,
    double? xpEarned,
    int? goldEarned,
    bool? xpSaved,
    bool? confirmed,
  }) {
    return QuizState(
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      finished: finished ?? this.finished,
      correctCount: correctCount ?? this.correctCount,
      xpEarned: xpEarned ?? this.xpEarned,
      goldEarned: goldEarned ?? this.goldEarned,
      xpSaved: xpSaved ?? this.xpSaved,
      confirmed: confirmed ?? this.confirmed,
    );
  }
}

@riverpod
class QuizController extends _$QuizController {
  late List<Question> _questions;

  @override
  QuizState build(List<Question> questions) {
    _questions = questions;
    return const QuizState();
  }

  void answer(int optionIndex) {
    if (state.confirmed) return;
    final updated = {...state.answers, state.currentIndex: optionIndex};
    state = state.copyWith(answers: updated);
  }

  void confirm() {
    if (!state.answers.containsKey(state.currentIndex)) return;
    state = state.copyWith(confirmed: true);
  }

  void next() {
    if (state.currentIndex < _questions.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        confirmed: false,
      );
    } else {
      // XP/gold NÃO são concedidos aqui: a correção e os prêmios acontecem no
      // servidor (RPC submit_quiz), disparada pela tela de quiz da turma.
      final correct = state.answers.entries
          .where((e) => _questions[e.key].isCorrect(e.value))
          .length;

      state = state.copyWith(
        finished: true,
        correctCount: correct,
      );
    }
  }

  void reset() => state = const QuizState();

  void setGoldEarned(int amount){
    state = state.copyWith(goldEarned: amount);
  }
}