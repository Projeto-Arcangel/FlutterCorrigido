import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_button.dart';

class QuizResultView extends StatelessWidget {
  const QuizResultView({
    super.key,
    required this.total,
    required this.correct,
    required this.xpEarned,
    required this.goldEarned,
    required this.onRestart,
  });

  final int total;
  final int correct;
  final double xpEarned;
  final int goldEarned;
  final VoidCallback onRestart;

  int get _percent => total == 0 ? 0 : ((correct / total) * 100).round();
  bool get _passed => _percent >= 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              size: 96,
              color: _passed ? const Color(0xFFFFD700) : cs.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _passed ? 'Lição concluída!' : 'Quase lá!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _passed
                  ? 'Você acertou $correct de $total questões.'
                  : 'Você acertou $correct de $total. Tente novamente!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _percent / 100,
                minHeight: 12,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _passed ? cs.primary : cs.error,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_percent% de aproveitamento',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            if (xpEarned > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded,
                        color: cs.onPrimaryContainer, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '+${xpEarned.toInt()} XP ganhos!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            if (goldEarned > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAD47F).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      FontAwesomeIcons.coins,
                      color: Color(0xFFEAD47F),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+$goldEarned moedas ganhas!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEAD47F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            AppButton(
              onPressed: onRestart,
              label: 'Tentar novamente',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.lessons),
              child: const Text('Voltar à trilha'),
            ),
          ],
        ),
      ),
    );
  }
}
