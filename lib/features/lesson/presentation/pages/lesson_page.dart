import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lesson_providers.dart';
import '../widgets/quiz_view.dart';

class LessonPage extends ConsumerWidget {
  const LessonPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLesson = ref.watch(lessonByIdProvider(lessonId));

    return Scaffold(
      appBar: AppBar(),
      body: asyncLesson.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro: $err', textAlign: TextAlign.center),
          ),
        ),
        data: (lesson) {
          if (lesson.questions.isEmpty) {
            return const Center(child: Text('Esta lição ainda não tem perguntas.'));
          }
          return QuizView(
            title: lesson.name,
            description: lesson.description,
            questions: lesson.questions,
          );
        },
      ),
    );
  }
}