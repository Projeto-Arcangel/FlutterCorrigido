import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/router/app_router.dart';
import '../providers/ia_quiz_providers.dart';

/// Avisa, em qualquer tela, quando a geração de questões termina com a tela
/// de criação fechada: o professor pode sair dela enquanto a IA trabalha.
///
/// Fica no `builder` do MaterialApp, acima de todas as rotas. Com a tela de
/// criação aberta, quem trata o resultado é ela (abre a revisão direto).
class IaGenerationWatcher extends ConsumerStatefulWidget {
  const IaGenerationWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IaGenerationWatcher> createState() =>
      _IaGenerationWatcherState();
}

class _IaGenerationWatcherState extends ConsumerState<IaGenerationWatcher> {
  /// Aviso "questões prontas" na tela; `null` depois que ele fecha.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _readyNotice;

  IaGenerationNotifier get _generation =>
      ref.read(iaGenerationNotifierProvider.notifier);

  void _onChange(
    AsyncValue<IaGenerationOutcome?>? previous,
    AsyncValue<IaGenerationOutcome?> next,
  ) {
    if (next.isLoading) return;
    if (next.hasError) {
      // Com a tela aberta, ela mesma mostra o erro.
      if (_generation.hasOpenScreen) return;
      _generation.reset();
      final error = next.error;
      _showError(
        error is Failure
            ? error.message
            : 'Falha ao gerar questões. Tente novamente.',
      );
      return;
    }
    final outcome = next.valueOrNull;
    if (outcome == null) {
      // Resultado entregue (pelo aviso ou pela tela de criação).
      _closeReadyNotice();
      return;
    }
    if (!_generation.hasOpenScreen) _showReady(outcome);
  }

  void _closeReadyNotice() {
    final notice = _readyNotice;
    _readyNotice = null;
    notice?.close();
  }

  /// Fonte do tema do app (Nunito); a cor vem do estilo do snackbar.
  TextStyle _textStyle(FontWeight weight) => TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontWeight: weight,
      );

  /// Cor do texto do snackbar no tema do app. O X e a ação usam a mesma: o
  /// padrão do Material 3 (cores "inversas") some sobre o fundo do tema.
  Color? get _contentColor =>
      Theme.of(context).snackBarTheme.contentTextStyle?.color;

  void _openReview() {
    final outcome = _generation.take();
    if (outcome == null) return;
    ref.read(appRouterProvider).push(
          AppRoutes.teacherIaQuizReview,
          extra: outcome.reviewExtra(fromCreation: false),
        );
  }

  void _showReady(IaGenerationOutcome outcome) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final count = outcome.result.questions.length;
    _closeReadyNotice();
    // O aviso passa à frente de avisos passageiros: só o snackbar atual pode
    // ser fechado depois (quando o resultado for entregue por outro caminho).
    messenger.clearSnackBars();
    final notice = messenger.showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Sua questão gerada com IA está pronta.'
              : 'Suas $count questões geradas com IA estão prontas.',
          style: _textStyle(FontWeight.w700),
        ),
        action: SnackBarAction(
          label: 'Revisar',
          textColor: _contentColor,
          onPressed: _openReview,
        ),
        // Fica até o professor revisar ou fechar. Fechado, o resultado
        // continua guardado e abre ao voltar para "Questões com IA".
        duration: const Duration(days: 1),
        showCloseIcon: true,
        closeIconColor: _contentColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    _readyNotice = notice;
    // Fechado pelo professor (X) ou ao revisar: não há mais o que fechar.
    notice.closed.then((_) {
      if (identical(_readyNotice, notice)) _readyNotice = null;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'Não consegui gerar as questões. $message',
          style: _textStyle(FontWeight.w600),
        ),
        duration: const Duration(seconds: 8),
        showCloseIcon: true,
        closeIconColor: _contentColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(iaGenerationNotifierProvider, _onChange);
    return widget.child;
  }
}
