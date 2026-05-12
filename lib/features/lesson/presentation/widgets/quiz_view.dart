import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/question.dart';
import '../providers/quiz_controller.dart';
import 'option_tile.dart';
import 'quiz_result_view.dart';

class QuizView extends ConsumerWidget {
  const QuizView({
    super.key,
    required this.title,
    required this.description,
    required this.questions,
  });

  final String title;
  final String description;
  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizControllerProvider(questions));
    final controller = ref.read(quizControllerProvider(questions).notifier);

    if (state.finished) {
      return QuizResultView(
        total: questions.length,
        correct: state.correctCount,
        onRestart: controller.reset,
      );
    }

    final question = questions[state.currentIndex];
    final selected = state.answers[state.currentIndex];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (state.currentIndex + 1) / questions.length,
          ),
          const SizedBox(height: 16),
          Text(
            'Pergunta ${state.currentIndex + 1} de ${questions.length}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 12),
          Text(question.text, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: question.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => OptionTile(
                label: question.options[i],
                selected: selected == i,
                onTap: () => controller.answer(i),
              ),
            ),
          ),
          AppButton(
            onPressed: selected == null ? null : () => controller.next(),
            label: state.currentIndex == questions.length - 1
                ? 'Finalizar'
                : 'Próxima',
          ),
        ],
      ),
    );
  }
}