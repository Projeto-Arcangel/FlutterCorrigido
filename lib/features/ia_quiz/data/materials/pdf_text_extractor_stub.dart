import 'dart:typed_data';

import 'material_read_exception.dart';

/// Texto de cada página do PDF. [onProgress] recebe (páginas lidas, total).
Future<List<String>> extractPdfPages(
  Uint8List bytes, {
  void Function(int done, int total)? onProgress,
}) {
  throw const MaterialReadException(
    'A leitura de PDF está disponível apenas na versão web.',
  );
}
