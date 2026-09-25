/// Веб: перезагрузить вкладку. См. `page_reload.dart`.
///
/// Через `dart:js_interop`, а не `dart:html`: на тот ругается линтер
/// (`avoid_web_libraries_in_flutter`), а `package:web` ради одного вызова
/// тащить незачем.
library;

import 'dart:js_interop';

const bool canReloadPage = true;

void reloadPage() => _location.reload();

@JS('location')
external _Location get _location;

extension type _Location._(JSObject _) implements JSObject {
  external void reload();
}
