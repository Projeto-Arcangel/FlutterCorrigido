import 'package:flutter/material.dart';
import '../../../../core/widgets/app_button.dart';

class QuizResultView extends StatelessWidget {
  const QuizResultView({
    super.key,
    required this.total,
    required this.correct,
    required this.onRestart,
  });

  final int total;
  final int correct;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    final xpGained = correct * 50; // mesmo cálculo do controller

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events,
            size: 96,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Você acertou $correct de $total',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text('$percent%', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 16),
          if (xpGained > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$xpGained XP',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
          const SizedBox(height: 32),
          AppButton(onPressed: onRestart, label: 'Tentar novamente'),
        ],
      ),
    );
  }
}