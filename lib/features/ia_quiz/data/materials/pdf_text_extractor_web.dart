import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'material_read_exception.dart';

@JS('arcangelExtractPdfText')
external JSPromise<JSArray<JSString>> _extractPdfText(
  JSUint8Array bytes,
  JSFunction onProgress,
);

/// Texto de cada página do PDF. [onProgress] recebe (páginas lidas, total).
Future<List<String>> extractPdfPages(
  Uint8List bytes, {
  void Function(int done, int total)? onProgress,
}) async {
  if (!globalContext.has('arcangelExtractPdfText')) {
    throw const MaterialReadException(
      'O leitor de PDF não carregou. Recarregue a página e tente de novo.',
    );
  }

  void progress(JSNumber done, JSNumber total) =>
      onProgress?.call(done.toDartInt, total.toDartInt);

  try {
    final pages = await _extractPdfText(bytes.toJS, progress.toJS).toDart;
    return [for (final page in pages.toDart) page.toDart];
  } catch (error) {
    throw MaterialReadException(_messageFor(error));
  }
}

/// O script rejeita com `{ code, message }` (ver web/pdf_extract.js).
String _messageFor(Object error) {
  Object? code;
  try {
    code = (error as JSObject).getProperty<JSAny?>('code'.toJS).dartify();
  } catch (_) {
    // Erro que não veio do script: cai na mensagem genérica.
  }
  return switch (code) {
    'password' => 'Este PDF é protegido por senha. Remova a senha e envie '
        'novamente.',
    'invalid' => 'O arquivo não é um PDF válido ou está corrompido.',
    'load' => 'Não foi possível carregar o leitor de PDF. Verifique sua '
        'internet e tente de novo.',
    _ => 'Não foi possível ler este PDF.',
  };
}
