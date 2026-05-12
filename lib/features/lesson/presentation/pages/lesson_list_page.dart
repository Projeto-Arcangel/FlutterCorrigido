import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../providers/lesson_providers.dart';
import '../widgets/lesson_card.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLessons = ref.watch(allLessonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trilha'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () =>
                ref.read(loginControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: asyncLessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro: $err', textAlign: TextAlign.center),
          ),
        ),
        data: (lessons) {
          if (lessons.isEmpty) {
            return const Center(child: Text('Nenhuma lição disponível.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allLessonsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final lesson = lessons[i];
                return LessonCard(
                  order: lesson.order,
                  title: lesson.name,
                  description: lesson.description,
                  questionCount: lesson.totalQuestions,
                  onTap: () =>
                      context.push(AppRoutes.lessonPath(lesson.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}