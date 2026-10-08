// Leitura de texto de PDF. Na web usa o pdf.js (web/pdf_extract.js); o app
// desta versão é só web, então fora dela a leitura de PDF não é suportada.
export 'pdf_text_extractor_stub.dart'
    if (dart.library.js_interop) 'pdf_text_extractor_web.dart';
