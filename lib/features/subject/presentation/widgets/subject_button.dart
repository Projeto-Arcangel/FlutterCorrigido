import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/subject.dart';

/// Botão oval de matéria com suporte a estado bloqueado/desbloqueado.
///
/// Usa [Subject.lightText] para decidir automaticamente a cor do texto/ícone,
/// garantindo contraste adequado (WCAG AA) em qualquer cor de fundo.
class SubjectButton extends StatelessWidget {
  const SubjectButton({
    super.key,
    required this.subject,
    required this.onTap,
  });

  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = subject.lightText
        ? AppColors.onSubjectLight
        : AppColors.onSubject;

    return SizedBox(
      width: 320,
      height: 60,
      child: Material(
        color: subject.color,
        borderRadius: BorderRadius.circular(50),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: subject.unlocked ? onTap : null,
          splashColor: Colors.black12,
          child: Center(
            child: subject.unlocked
                ? Text(
                    subject.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(
                    Icons.lock_outlined,
                    color: subject.lockColor,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}