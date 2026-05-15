import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/classroom.dart';
import '../providers/classroom_providers.dart';

/// Abre o bottom sheet de turmas.
void showClassroomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ClassroomSheet(),
  );
}

// ─── Sheet principal ─────────────────────────────────────────────────────────

class _ClassroomSheet extends ConsumerStatefulWidget {
  const _ClassroomSheet();

  @override
  ConsumerState<_ClassroomSheet> createState() => _ClassroomSheetState();
}

class _ClassroomSheetState extends ConsumerState<_ClassroomSheet> {
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMsg;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onJoin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMsg = null);

    final (error, classroom) = await ref
        .read(joinClassroomNotifierProvider.notifier)
        .join(_codeCtrl.text.trim());

    if (!mounted) return;

    if (error != null) {
      setState(() => _errorMsg = error);
    } else if (classroom != null) {
      Navigator.of(context).pop();
      context.push(
        AppRoutes.classroomTrailPath(classroom.id),
        extra: classroom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(joinClassroomNotifierProvider).isLoading;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ─────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Título ─────────────────────────────────────────────────
          Text(
            'Turmas',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entre com um código ou selecione uma turma existente.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8FA3AE),
            ),
          ),
          const SizedBox(height: 24),

          // ── Formulário de código ───────────────────────────────────
          _CodeForm(
            formKey: _formKey,
            controller: _codeCtrl,
            errorMsg: _errorMsg,
            isLoading: isLoading,
            onJoin: _onJoin,
          ),

          const SizedBox(height: 28),

          // ── Minhas turmas ──────────────────────────────────────────
          Text(
            'MINHAS TURMAS',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8FA3AE),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),

          _ClassroomList(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Formulário de código ─────────────────────────────────────────────────────

class _CodeForm extends StatelessWidget {
  const _CodeForm({
    required this.formKey,
    required this.controller,
    required this.errorMsg,
    required this.isLoading,
    required this.onJoin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final String? errorMsg;
  final bool isLoading;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9]'),
                    ),
                    LengthLimitingTextInputFormatter(6),
                    _UpperCaseFormatter(),
                  ],
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'EX: ABC12345',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white24,
                      letterSpacing: 2,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.white12,
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1.5,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.tag_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    errorStyle: const TextStyle(height: 0),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 4)
                          ? ''
                          : null,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: isLoading ? null : onJoin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Entrar',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (errorMsg != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorMsg!,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Lista de turmas do aluno ─────────────────────────────────────────────────

class _ClassroomList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClassrooms = ref.watch(userClassroomsProvider);

    return asyncClassrooms.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
      error: (_, __) => _EmptyClassrooms(
        message: 'Não foi possível carregar as turmas.',
      ),
      data: (classrooms) {
        if (classrooms.isEmpty) {
          return _EmptyClassrooms(
            message: 'Você ainda não está em nenhuma turma.',
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: classrooms
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ClassroomCard(classroom: c),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _EmptyClassrooms extends StatelessWidget {
  const _EmptyClassrooms({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.school_outlined,
            color: Colors.white24,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8FA3AE),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.classroom});
  final Classroom classroom;

  // Mesma paleta usada nas matérias
  Color get _color => AppColors.primary;

  IconData get _icon => Icons.school_outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _color.withOpacity(0.35),
          width: 1.3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: _color.withOpacity(0.08),
          onTap: () {
            Navigator.of(context).pop();
            context.push(
              AppRoutes.classroomTrailPath(classroom.id),
              extra: classroom,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Ícone da matéria
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: _color, size: 22),
                ),
                const SizedBox(width: 14),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classroom.name,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Prof. ${classroom.teacherName}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8FA3AE),
                        ),
                      ),
                    ],
                  ),
                ),

                // Código no canto direito
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    classroom.code,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _color,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Formatter para maiúsculas automáticas ────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}