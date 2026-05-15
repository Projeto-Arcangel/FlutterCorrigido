import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../classroom/presentation/widgets/classroom_sheet.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../domain/entities/subject.dart';
import '../providers/subject_providers.dart';
import '../widgets/subject_button.dart';

class SubjectChoicePage extends ConsumerWidget {
  const SubjectChoicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSubjects = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () =>
                ref.read(loginControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncSubjects.when(
          // Carregando
          loading: () => const Center(child: CircularProgressIndicator()),

          // Erro (não bloqueia — usa catálogo como fallback)
          error: (err, _) => _SubjectList(
            subjects: Subject.catalog
                .map((s) => s.copyWith(unlocked: s.id == SubjectId.history))
                .toList(),
            ref: ref,
          ),

          // Dados carregados
          data: (subjects) => _SubjectList(subjects: subjects, ref: ref),
        ),
      ),
    );
  }
}

// Widget interno extraído para não duplicar a lista nos 3 estados
class _SubjectList extends StatelessWidget {
  const _SubjectList({required this.subjects, required this.ref});

  final List<Subject> subjects;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Qual caminho você\ndeseja trilhar?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            for (final subject in subjects) ...[
              SubjectButton(
                subject: subject,
                onTap: () {
                  ref.read(selectedSubjectProvider.notifier).state = subject;
                  context.go(AppRoutes.lessons);
                },
              ),
              const SizedBox(height: 16),
            ],
              _EnterClassroomButton(),
          ],
        ),
      ),
    );
  }
}
class _EnterClassroomButton extends StatelessWidget {
  const _EnterClassroomButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => showClassroomSheet(context),
        icon: const Icon(
          Icons.group_add_rounded,
          size: 20,
        ),
        label: const Text(
          'Entrar em Turma',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF72ACD0),
          side: const BorderSide(
            color: Color(0xFF72ACD0),
            width: 1.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }
}