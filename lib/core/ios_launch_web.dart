/// Веб: спросить браузер, где он. См. `ios_launch.dart`.
///
/// Через `dart:js_interop` по той же причине, что и `page_reload_web.dart`.
library;

import 'dart:js_interop';

import 'home_screen.dart';

IosLaunch detectIosLaunch() => iosLaunchOf(
      userAgent: _navigator.userAgent,
      maxTouchPoints: _navigator.maxTouchPoints ?? 0,
      // `navigator.standalone` — только у iOS, и только он там надёжен: так
      // WebKit сам отвечает «открыто с экрана Домой». Медиазапрос —
      // стандартный способ на случай, если старое свойство когда-нибудь
      // уберут. Вне iOS ответ всё равно не важен: там `other`.
      standalone: _navigator.standalone == true ||
          _matchMedia('(display-mode: standalone)').matches,
    );

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external String get userAgent;
  external int? get maxTouchPoints;
  external bool? get standalone;
}

@JS('matchMedia')
external _MediaQueryList _matchMedia(String query);

extension type _MediaQueryList._(JSObject _) implements JSObject {
  external bool get matches;
}
