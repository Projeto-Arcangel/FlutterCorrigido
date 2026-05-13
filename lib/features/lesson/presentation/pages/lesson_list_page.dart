import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../providers/lesson_providers.dart';
import '../../domain/entities/lesson.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLessons = ref.watch(allLessonsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final asyncProgress =
        user == null ? null : ref.watch(userProgressProvider(user.id));
    final currentPhase = asyncProgress?.valueOrNull?.currentPhase ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF1D2428),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: avatar + level + moedas ──────────────────────
            _TrailHeader(
              onLogout: () =>
                  ref.read(loginControllerProvider.notifier).signOut(),
            ),
            const SizedBox(height: 12),

            // ── Lista de fases ────────────────────────────────────────
            Expanded(
              child: asyncLessons.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => _EmptyTrail(),
                data: (lessons) {
                  if (lessons.isEmpty) return _EmptyTrail();
                  return _TrailList(
                    lessons: lessons,
                    currentPhase: currentPhase,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────
class _TrailHeader extends StatelessWidget {
  const _TrailHeader({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Ícone de configurações / chá (lado esquerdo)
          const Icon(Icons.local_cafe_outlined,
              color: Colors.white54, size: 28),

          const Spacer(),

          // Avatar + level (centro)
          Column(
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.profile),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surfaceDark,
                  child:
                      const Icon(Icons.person, color: Colors.white70, size: 28),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '[level]',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),

          const Spacer(),

          // Moedas (lado direito)
          Row(
            children: const [
              FaIcon(FontAwesomeIcons.coins,
                  color: Color(0xFFEAD47F), size: 24),
              SizedBox(width: 6),
              Text('0000',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),

          const SizedBox(width: 12),

          // Logout
          GestureDetector(
            onTap: onLogout,
            child: const Icon(Icons.logout, color: Colors.white38, size: 22),
          ),
        ],
      ),
    );
  }
}

// ── Zigue-zague responsivo: 3 colunas centralizadas na tela ─────────────────
//
// Em vez de espalhar os botões nas bordas da tela (`Alignment.centerLeft` /
// `centerRight`), encerramos a trilha num container de largura fixa
// `_kTrailMaxWidth` centralizado horizontalmente. Dentro dele há sempre 3
// colunas de igual largura — a posição do botão é decidida por `index % 3`:
//   • 0 → coluna esquerda
//   • 1 → coluna do meio
//   • 2 → coluna direita
//
// Vantagens vs. a abordagem anterior:
//   1. Em qualquer tamanho de tela os botões mantêm a mesma distância
//      entre si (≈ _kTrailMaxWidth / 3 − largura do botão).
//   2. Tablet/desktop não esticam a trilha para o lado — fica visualmente
//      consistente com o mobile.
//   3. Estrutura semanticamente clara: "3 colunas com uma fase em uma
//      delas por linha".
const double _kTrailMaxWidth = 320;

Widget _trailRow({required int index, required Widget cell}) {
  final col = index % 3;
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kTrailMaxWidth),
      child: Row(
        children: List.generate(3, (c) {
          return Expanded(
            child: Center(
              child: c == col ? cell : const SizedBox.shrink(),
            ),
          );
        }),
      ),
    ),
  );
}

// ── Lista em zigue-zague ────────────────────────────────────────────────────
class _TrailList extends StatelessWidget {
  const _TrailList({
    required this.lessons,
    required this.currentPhase,
  });
  final List<Lesson> lessons;
  final int currentPhase;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: lessons.length,
      itemBuilder: (context, i) => _PhaseNode(
        lesson: lessons[i],
        index: i,
        currentPhase: currentPhase,
      ),
    );
  }
}

// ── Nó individual da fase ───────────────────────────────────────────────────
class _PhaseNode extends StatelessWidget {
  const _PhaseNode({
    required this.lesson,
    required this.index,
    required this.currentPhase,
  });

  final Lesson lesson;
  final int index;
  final int currentPhase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _trailRow(
        index: index,
        cell: _PhaseButton(
          lesson: lesson,
          index: index,
          currentPhase: currentPhase,
        ),
      ),
    );
  }
}

// ── Botão da fase (oval marrom + cadeado) ──────────────────────────────────
class _PhaseButton extends StatelessWidget {
  const _PhaseButton({
    required this.lesson,
    required this.index,
    required this.currentPhase,
  });
  final Lesson lesson;
  final int index;
  final int currentPhase;

  /// A primeira fase (index 0) está SEMPRE desbloqueada — é o ponto de
  /// entrada obrigatório, independente do valor de `order` no Firestore
  /// e do `currentPhase` salvo. As demais seguem a regra:
  /// `lesson.order <= currentPhase + 1`.
  /// • novo usuário → apenas a primeira fase
  /// • completou a primeira → primeira (✓) + segunda (▶)
  /// • e assim por diante.
  bool get _unlocked => index == 0 || lesson.order <= currentPhase + 1;

  /// Fase já concluída pelo usuário (apenas para feedback visual).
  bool get _completed => lesson.order <= currentPhase;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unlocked
          ? () => context.push(AppRoutes.lessonPath(lesson.id))
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conclua a fase anterior'),
                  backgroundColor: Color(0xFF282932),
                  duration: Duration(seconds: 2),
                ),
              );
            },
      child: _OvalPhase(
        unlocked: _unlocked,
        completed: _completed,
        index: index,
      ),
    );
  }
}

// ── Oval marrom com cadeado / play / check ─────────────────────────────────
class _OvalPhase extends StatelessWidget {
  const _OvalPhase({
    required this.unlocked,
    required this.completed,
    required this.index,
  });
  final bool unlocked;
  final bool completed;
  final int index;

  // Cores que mudam por fase (simulando as imagens do original)
  static const _shades = [
    Color(0xFF6F574A),
    Color(0xFF5C4438),
    Color(0xFF4A3328),
    Color(0xFF3D2A20),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _shades[index.clamp(0, _shades.length - 1)];

    final Widget icon;
    if (!unlocked) {
      icon = Icon(
        Icons.lock_outlined,
        color: Colors.white.withValues(alpha: 0.5),
        size: 28,
      );
    } else if (completed) {
      icon = const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 36,
      );
    } else {
      icon = const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 36,
      );
    }

    return Container(
      width: 98,
      height: 79,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: icon),
    );
  }
}

// ── Trilha vazia (quando não há dados no Firebase) ─────────────────────────
class _EmptyTrail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 4,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _trailRow(
            index: i,
            cell: _OvalPhase(unlocked: false, completed: false, index: i),
          ),
        );
      },
    );
  }
}
