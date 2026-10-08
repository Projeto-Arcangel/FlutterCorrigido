/// Fatia trabalho longo na thread da interface: depois de ~[budget] de
/// processamento, devolve a vez ao navegador para ele desenhar a tela e
/// tratar cliques. Na web o Dart não tem threads (isolates), então sem isso
/// a leitura de um arquivo grande congelaria a página.
///
/// Uso num laço quente (um item por volta):
/// ```dart
/// for (final item in items) {
///   if (slicer.tick()) await slicer.yieldNow();
///   ...
/// }
/// ```
/// Uma instância por arquivo: a contagem segue entre partes pequenas (slides),
/// então o arquivo inteiro respeita o orçamento, não só cada parte.
class TimeSlicer {
  TimeSlicer({this.budget = const Duration(milliseconds: 12)});

  /// Abaixo de um quadro de 60 fps (~16 ms), deixando folga para o desenho.
  final Duration budget;

  final _watch = Stopwatch()..start();
  var _ticks = 0;

  bool get overBudget => _watch.elapsed >= budget;

  /// Barato o bastante para chamar a cada item: só consulta o relógio a cada
  /// 256 chamadas. `true` = hora de ceder a vez ([yieldNow]).
  bool tick() => (++_ticks & 255) == 0 && overBudget;

  Future<void> yieldNow() async {
    await Future<void>.delayed(Duration.zero);
    _watch.reset();
  }

  Future<void> yieldIfBusy() async {
    if (overBudget) await yieldNow();
  }
}
