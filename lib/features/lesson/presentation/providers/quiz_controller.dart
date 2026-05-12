import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/auth/presentation/providers/login_controller.dart';
import '../../../../features/progress/presentation/providers/progress_providers.dart';
import '../../domain/entities/question.dart';

part 'quiz_controller.g.dart';

class QuizState {
  final int currentIndex;
  final Map<int, int> answers;
  final bool finished;
  final int correctCount;
  final double xpEarned;
  final bool xpSaved;
  final bool confirmed;

  const QuizState({
    this.currentIndex = 0,
    this.answers = const {},
    this.finished = false,
    this.correctCount = 0,
    this.xpEarned = 0,
    this.xpSaved = false,
    this.confirmed = false,
  });

  QuizState copyWith({
    int? currentIndex,
    Map<int, int>? answers,
    bool? finished,
    int? correctCount,
    double? xpEarned,
    bool? xpSaved,
    bool? confirmed,
  }) {
    return QuizState(
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      finished: finished ?? this.finished,
      correctCount: correctCount ?? this.correctCount,
      xpEarned: xpEarned ?? this.xpEarned,
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

  Future<void> next() async {
    if (state.currentIndex < _questions.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        confirmed: false,
      );
    } else {
      final correct = state.answers.entries
          .where((e) => _questions[e.key].isCorrect(e.value))
          .length;

      final xp = correct * 50.0; // ← calcula uma vez e guarda no estado

      state = state.copyWith(
        finished: true,
        correctCount: correct,
        xpEarned: xp,  // ← NOVO: estado passa a carregar o valor
      );

      await _saveXp(correct, xp); // ← passa xp calculado para evitar recalcular
    }
  }

  Future<void> _saveXp(int correct, double xpGained) async {
    if (state.xpSaved) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    if (xpGained <= 0) return;

    final repo = ref.read(progressRepositoryProvider);
    await repo.addXp(userId: user.id, amount: xpGained);

    state = state.copyWith(xpSaved: true);
  }

  void reset() => state = const QuizState();
}