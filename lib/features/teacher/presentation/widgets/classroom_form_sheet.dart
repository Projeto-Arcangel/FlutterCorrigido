import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../classroom/domain/entities/classroom.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../providers/teacher_dashboard_provider.dart';
import 'classroom_palette.dart';

/// Bottom sheet de criação ou edição de turma.
///
/// - Passe [classroom] = null para modo "Criar".
/// - Passe um [Classroom] existente para modo "Editar" (nome/descrição
///   vêm preenchidos).
///
/// Em ambos os casos invalida [teacherClassroomsProvider] e
/// [teacherDashboardProvider] ao final para forçar refresh das telas
/// que dependem desses dados.
class ClassroomFormSheet extends ConsumerStatefulWidget {
  const ClassroomFormSheet({
    super.key,
    required this.userId,
    required this.displayName,
    this.classroom,
  });

  final String userId;
  final String displayName;
  final Classroom? classroom;

  /// Helper para abrir o sheet com a configuração padrão.
  static Future<bool?> show({
    required BuildContext context,
    required String userId,
    required String displayName,
    Classroom? classroom,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ClassroomFormSheet(
        userId: userId,
        displayName: displayName,
        classroom: classroom,
      ),
    );
  }

  @override
  ConsumerState<ClassroomFormSheet> createState() => _ClassroomFormSheetState();
}

class _ClassroomFormSheetState extends ConsumerState<ClassroomFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  bool get _isEditing => widget.classroom != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.classroom?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.classroom?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final description = _descCtrl.text.trim();

    final result = _isEditing
        ? await ref.read(updateClassroomProvider)(
            classroomId: widget.classroom!.id,
            name: name,
            description: description,
          )
        : await ref.read(createClassroomProvider)(
            name: name,
            teacherId: widget.userId,
            teacherName: widget.displayName,
            description: description,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            f.message,
            style: GoogleFonts.nunito(color: Colors.white),
          ),
          backgroundColor: ClassroomPalette.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
      ),
      (_) {
        ref.invalidate(teacherClassroomsProvider(widget.userId));
        ref.invalidate(teacherDashboardProvider);
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color:
                          ClassroomPalette.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text(
                  _isEditing ? 'Editar Turma' : 'Nova Turma',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ClassroomPalette.primaryText(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditing
                      ? 'Atualize o nome e a descrição da turma.'
                      : 'Crie uma nova turma para gerenciar alunos e questões.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: ClassroomPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 18),

                _DarkTextField(
                  controller: _nameCtrl,
                  label: 'Nome da turma',
                  hint: 'Ex: 3ºA · Ciências Humanas',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Informe o nome da turma';
                    if (value.length < 3) return 'Mínimo 3 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _DarkTextField(
                  controller: _descCtrl,
                  label: 'Descrição (opcional)',
                  hint: 'Ex: Turma do 3º ano, período vespertino',
                  maxLines: 2,
                ),
                const SizedBox(height: 22),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isEditing
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            size: 20,
                          ),
                    label: Text(
                      _saving
                          ? 'Salvando…'
                          : (_isEditing ? 'Salvar' : 'Criar Turma'),
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ClassroomPalette.gold,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          ClassroomPalette.gold.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
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

/// Campo de texto compatível com o tema dark do app.
class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      validator: validator,
      style: GoogleFonts.nunito(
        fontSize: 15,
        color: ClassroomPalette.primaryText(isDark),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            GoogleFonts.nunito(fontSize: 14, color: ClassroomPalette.textMuted),
        hintStyle:
            GoogleFonts.nunito(fontSize: 14, color: ClassroomPalette.textMuted),
        filled: true,
        fillColor: ClassroomPalette.fieldFill(isDark),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ClassroomPalette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: ClassroomPalette.danger, width: 2),
        ),
        errorStyle:
            GoogleFonts.nunito(fontSize: 12, color: ClassroomPalette.danger),
      ),
    );
  }
}