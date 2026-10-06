// Lê a preferência "reduzir movimento" do sistema também no navegador.
//
// No Flutter web, `MediaQuery.disableAnimations` NÃO acompanha o
// `prefers-reduced-motion` do navegador; o app aplica isso na raiz
// (ver `ArcangelApp`), e o resto do código só consulta o MediaQuery.
export 'reduced_motion_stub.dart'
    if (dart.library.js_interop) 'reduced_motion_web.dart';
