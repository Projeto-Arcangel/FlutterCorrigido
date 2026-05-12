import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../providers/lesson_providers.dart';
import '../../domain/entities/lesson.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLessons = ref.watch(allLessonsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1D2428), // fundo escuro igual ao original
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: avatar + level + moedas ──────────────────────
            _TrailHeader(onLogout: () =>
                ref.read(loginControllerProvider.notifier).signOut()),
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
                  return _TrailList(lessons: lessons);
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
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceDark,
                child: const Icon(Icons.person,
                    color: Colors.white70, size: 28),
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

// ── Lista em zigue-zague ────────────────────────────────────────────────────
class _TrailList extends StatelessWidget {
  const _TrailList({required this.lessons});
  final List<Lesson> lessons;

  /// Mesma lógica do calcularPosicao original:
  /// índice % 3 → 0 = esquerda, 1 = centro, 2 = direita
  double _offsetForIndex(int index) {
    final pos = index % 3;
    if (pos == 0) return 40.0;
    if (pos == 1) return 120.0;
    return 40.0; // pos == 2, volta para direita espelhada abaixo
  }

  CrossAxisAlignment _alignForIndex(int index) {
    final pos = index % 3;
    if (pos == 1) return CrossAxisAlignment.end;
    return CrossAxisAlignment.start;
  }

  @override
  Widget build(BuildContext context) {
    // Inverte a lista para mostrar da última para a primeira (como no original)
    final reversed = lessons.reversed.toList();

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final lesson = reversed[i];
        final originalIndex = reversed.length - 1 - i;
        return _PhaseNode(
          lesson: lesson,
          index: originalIndex,
          offset: _offsetForIndex(originalIndex),
          align: _alignForIndex(originalIndex),
        );
      },
    );
  }
}

// ── Nó individual da fase ───────────────────────────────────────────────────
class _PhaseNode extends StatelessWidget {
  const _PhaseNode({
    required this.lesson,
    required this.index,
    required this.offset,
    required this.align,
  });

  final Lesson lesson;
  final int index;
  final double offset;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          if (align == CrossAxisAlignment.start)
            SizedBox(width: offset),
          _PhaseButton(lesson: lesson, index: index),
          if (align == CrossAxisAlignment.end)
            SizedBox(width: offset),
        ],
      ),
    );
  }
}

// ── Botão da fase (oval marrom + cadeado) ──────────────────────────────────
class _PhaseButton extends StatelessWidget {
  const _PhaseButton({required this.lesson, required this.index});
  final Lesson lesson;
  final int index;

  // A fase 0 é sempre desbloqueada; as demais são bloqueadas até implementar lógica real
  bool get _unlocked => index == 0;

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
                ),
              );
            },
      child: _OvalPhase(unlocked: _unlocked, index: index),
    );
  }
}

// ── Oval marrom com cadeado (substitui a imagem TipoFase_7_(marrom).png) ──
class _OvalPhase extends StatelessWidget {
  const _OvalPhase({required this.unlocked, required this.index});
  final bool unlocked;
  final int index;

  // Cores que mudam por fase (simulando as imagens do original)
  static const _shades = [
    Color(0xFF6F574A), // marrom mais escuro - fase mais avançada
    Color(0xFF5C4438),
    Color(0xFF4A3328),
    Color(0xFF3D2A20),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _shades[index.clamp(0, _shades.length - 1)];

    return Container(
      width: 98,
      height: 79,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: unlocked
            ? const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 36)
            : Icon(
                Icons.lock_outlined,
                color: Colors.white.withOpacity(0.5),
                size: 28,
              ),
      ),
    );
  }
}

// ── Trilha vazia (quando não há dados no Firebase) ─────────────────────────
class _EmptyTrail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Mostra 4 fases bloqueadas como placeholder (igual ao screenshot do original)
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 4,
      itemBuilder: (context, i) {
        const offsets = [40.0, 120.0, 40.0, 120.0];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              SizedBox(width: offsets[i % 4]),
              _OvalPhase(unlocked: false, index: i),
            ],
          ),
        );
      },
    );
  }
}