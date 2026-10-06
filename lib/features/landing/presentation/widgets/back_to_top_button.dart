import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class BackToTopButton extends StatelessWidget {
  const BackToTopButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    // Oculto: sem clique, sem foco por teclado e fora do leitor de tela.
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            child: AnimatedScale(
              scale: visible ? 1 : 0.8,
              duration: duration,
              child: FloatingActionButton.small(
                onPressed: onPressed,
                tooltip: 'Voltar ao topo',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
