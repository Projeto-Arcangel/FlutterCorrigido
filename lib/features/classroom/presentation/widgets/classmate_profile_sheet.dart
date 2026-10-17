import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/domain/entities/classmate_profile.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/widgets/achievement_badge.dart';

/// Abre o perfil de um aluno da turma (tocando no ranking). [name] aparece
/// enquanto o perfil carrega.
Future<void> showClassmateProfile(
  BuildContext context, {
  required String classroomId,
  required String studentId,
  required String name,
  bool isCurrentUser = false,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassmateProfileSheet(
        classroomId: classroomId,
        studentId: studentId,
        name: name,
        isCurrentUser: isCurrentUser,
      ),
    );

/// Perfil do colega: nome, foto, nível, estrelas e fases nesta turma e as
/// conquistas liberadas. O servidor só devolve para quem é da turma.
class ClassmateProfileSheet extends ConsumerWidget {
  const ClassmateProfileSheet({
    super.key,
    required this.classroomId,
    required this.studentId,
    required this.name,
    this.isCurrentUser = false,
  });

  final String classroomId;
  final String studentId;
  final String name;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = (classroomId: classroomId, studentId: studentId);
    final asyncProfile = ref.watch(classmateProfileProvider(key));
    final muted = isDark ? Colors.white54 : AppColors.textSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...asyncProfile.when(
              loading: () => [
                _Header(name: name, isCurrentUser: isCurrentUser),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ],
              error: (err, _) => [
                _Header(name: name, isCurrentUser: isCurrentUser),
                const SizedBox(height: 24),
                Text(
                  ErrorMessages.from(
                    err,
                    fallback: 'Não foi possível carregar o perfil.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(classmateProfileProvider(key)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar de novo'),
                  ),
                ),
              ],
              data: (profile) => profile == null
                  ? [
                      _Header(name: name, isCurrentUser: isCurrentUser),
                      const SizedBox(height: 24),
                      Text(
                        'Este perfil não está disponível.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ]
                  : _content(profile, isDark, muted),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(ClassmateProfile p, bool isDark, Color muted) => [
        _Header(
          name: p.name.isEmpty ? name : p.name,
          photoUrl: p.photoUrl,
          level: p.level,
          isCurrentUser: isCurrentUser,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                icon: Icons.bolt_rounded,
                color: AppColors.primary,
                value: '${p.xp}',
                label: 'XP total',
              ),
              _Stat(
                icon: Icons.star_rounded,
                color: const Color(0xFFEAD47F),
                value: '${p.stars}',
                label: 'Estrelas na turma',
              ),
              _Stat(
                icon: Icons.flag_rounded,
                color: const Color(0xFF72D082),
                value: '${p.phasesDone}',
                label: p.phasesDone == 1 ? 'Fase feita' : 'Fases feitas',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Conquistas',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${p.achievements.length} / ${p.achievementsTotal}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (p.achievements.isEmpty)
          Text(
            isCurrentUser
                ? 'Você ainda não liberou nenhuma conquista.'
                : 'Ainda não liberou nenhuma conquista.',
            style: TextStyle(color: muted, fontSize: 13),
          )
        else
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: p.achievements.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) =>
                AchievementBadge(achievement: p.achievements[i]),
          ),
      ];
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    this.photoUrl,
    this.level,
    required this.isCurrentUser,
  });

  final String name;
  final String? photoUrl;
  final int? level;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              child: photoUrl == null
                  ? fallback
                  : ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photoUrl!,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => fallback,
                      ),
                    ),
            ),
            if (level != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Nv. $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isCurrentUser)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Você',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white38 : AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
