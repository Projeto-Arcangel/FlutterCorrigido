import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'landing_layout.dart';
import 'landing_reveal.dart';

/// Conteúdo da seção "Sobre": recursos para o professor, como funciona e o
/// que o aluno ganha. Os textos descrevem só o que já existe no app.
class LandingAbout extends StatelessWidget {
  const LandingAbout({super.key, required this.onRegisterTap});

  final VoidCallback onRegisterTap;

  static const _features = [
    (
      Icons.auto_awesome_rounded,
      'Questões com IA',
      'Informe a disciplina e o tema e receba questões de múltipla escolha '
          'prontas. Você revisa, edita e salva só as que aprovar.',
    ),
    (
      Icons.history_edu_rounded,
      'Banco de questões do ENEM',
      'Busque questões de provas anteriores por ano e área e adicione '
          'direto às fases da sua turma.',
    ),
    (
      Icons.edit_note_rounded,
      'Suas próprias questões',
      'Escreva questões do seu jeito e combine com as geradas pela IA e as '
          'do ENEM na mesma fase.',
    ),
    (
      Icons.groups_rounded,
      'Turmas com código de acesso',
      'Crie a turma e compartilhe o código. Os alunos entram sozinhos, sem '
          'você precisar cadastrar ninguém.',
    ),
    (
      Icons.route_rounded,
      'Trilhas por fases',
      'Organize o conteúdo em fases que os alunos vão desbloqueando conforme '
          'avançam.',
    ),
    (
      Icons.insights_rounded,
      'Dashboard de desempenho',
      'Acompanhe a evolução de cada aluno e exporte as notas da turma em '
          'planilha (.xlsx).',
    ),
  ];

  static const _steps = [
    (
      'Crie sua turma',
      'Cadastre-se como professor e crie a turma em poucos cliques.',
    ),
    (
      'Monte as fases',
      'Adicione questões geradas com IA, do ENEM ou escritas por você.',
    ),
    (
      'Acompanhe a evolução',
      'Veja o desempenho de cada aluno e exporte as notas quando precisar.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = LandingBreakpoints.isDesktop(context);

    return Column(
      children: [
        LandingGrid(
          children: [
            for (var i = 0; i < _features.length; i++)
              LandingReveal(
                // Cards da mesma linha surgem em sequência.
                delay: Duration(milliseconds: 100 * (i % 3)),
                child: _FeatureCard(
                  icon: _features[i].$1,
                  title: _features[i].$2,
                  description: _features[i].$3,
                ),
              ),
          ],
        ),
        SizedBox(height: isDesktop ? 72 : 48),
        const LandingReveal(child: _SubsectionTitle('Como funciona')),
        const SizedBox(height: 24),
        LandingGrid(
          minItemWidth: 260,
          children: [
            for (var i = 0; i < _steps.length; i++)
              LandingReveal(
                delay: Duration(milliseconds: 100 * i),
                child: _StepCard(
                  number: i + 1,
                  title: _steps[i].$1,
                  description: _steps[i].$2,
                ),
              ),
          ],
        ),
        SizedBox(height: isDesktop ? 72 : 48),
        LandingReveal(child: _StudentsBanner(onRegisterTap: onRegisterTap)),
      ],
    );
  }
}

class _SubsectionTitle extends StatelessWidget {
  const _SubsectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    return LandingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LandingIconBadge(icon: icon),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Passo $number',
            excludeSemantics: true,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accentText,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color:
                      palette.isDark ? AppColors.backgroundDark : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: palette.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsBanner extends StatelessWidget {
  const _StudentsBanner({required this.onRegisterTap});

  final VoidCallback onRegisterTap;

  static const _highlights = [
    (Icons.lock_open_rounded, 'Avançam por fases'),
    (Icons.emoji_events_outlined, 'Desbloqueiam conquistas'),
    (Icons.trending_up_rounded, 'Acompanham a própria evolução'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDesktop = LandingBreakpoints.isDesktop(context);

    final copy = Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            'E para os alunos, estudar vira jogo',
            textAlign: isDesktop ? TextAlign.start : TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cada fase é um desafio. Os alunos entram na turma com o código, '
          'respondem às questões e veem o resultado do próprio esforço.',
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: palette.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            for (final (icon, label) in _highlights)
              _HighlightChip(icon: icon, label: label),
          ],
        ),
      ],
    );

    final cta = FilledButton(
      onPressed: onRegisterTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Criar conta grátis',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );

    return LandingCard(
      padding: EdgeInsets.all(isDesktop ? 40 : 24),
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      child: isDesktop
          ? Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 32),
                cta,
              ],
            )
          : Column(children: [copy, const SizedBox(height: 24), cta]),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.primarySubtle,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 18, color: palette.accentText),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
