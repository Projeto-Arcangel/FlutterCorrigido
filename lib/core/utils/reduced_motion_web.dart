import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('matchMedia')
external JSObject _matchMedia(String query);

bool browserPrefersReducedMotion() {
  final result = _matchMedia('(prefers-reduced-motion: reduce)');
  final matches = result.getProperty<JSAny?>('matches'.toJS);
  return matches is JSBoolean && matches.toDart;
}
