import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final bool xpSaved;

  const QuizState({
    this.currentIndex = 0,
    this.answers = const {},
    this.finished = false,
    this.correctCount = 0,
    this.xpSaved = false,
  });

  QuizState copyWith({
    int? currentIndex,
    Map<int, int>? answers,
    bool? finished,
    int? correctCount,
    bool? xpSaved,
  }) {
    return QuizState(
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      finished: finished ?? this.finished,
      correctCount: correctCount ?? this.correctCount,
      xpSaved: xpSaved ?? this.xpSaved,
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
    final updated = {...state.answers, state.currentIndex: optionIndex};
    state = state.copyWith(answers: updated);
  }

  Future<void> next() async {
    if (state.currentIndex < _questions.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    } else {
      final correct = state.answers.entries
          .where((e) => _questions[e.key].isCorrect(e.value))
          .length;

      state = state.copyWith(finished: true, correctCount: correct);

      await _saveXp(correct);
    }
  }

  Future<void> _saveXp(int correct) async {
    if (state.xpSaved) return; // guarda idempotência

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    // 50 XP por acerto — igual ao valor original do FlutterFlow
    final xpGained = correct * 50.0;

    if (xpGained <= 0) return;

    final repo = ref.read(progressRepositoryProvider);
    await repo.addXp(userId: user.id, amount: xpGained);

    state = state.copyWith(xpSaved: true);
  }

  void reset() => state = const QuizState();
}