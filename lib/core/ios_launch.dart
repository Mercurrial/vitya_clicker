/// Как открыта игра на iOS — спросить браузер.
///
/// Условный импорт, как у `page_reload.dart`: вне веба браузера нет, и ответ
/// всегда [IosLaunch.other]. Само правило «показать подсказку или нет» — в
/// `home_screen.dart`, отдельно от браузера, чтобы его проверял тест.
library;

export 'ios_launch_stub.dart'
    if (dart.library.js_interop) 'ios_launch_web.dart';
