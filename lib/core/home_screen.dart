/// Подсказка «поставь на экран Домой» — кому и когда её показывать.
///
/// iPhone получает игру веб-версией (docs/DECISIONS.md, «Платформа и
/// раздача»), а у iOS две особенности, о которых игрок узнаёт, когда уже
/// поздно:
///
/// * у иконки на экране «Домой» своё хранилище, отдельное от Safari. Кто
///   начал во вкладке, а потом поставил иконку, откроет пустой гараж. WebKit
///   делает так намеренно: webkit.org/tracking-prevention, баг 181849 на
///   bugs.webkit.org закрывать не собираются;
/// * во вкладке Safari всё, что сайт записал скриптом, — сейв лежит именно
///   там — стирается после 7 дней пользования Safari без захода на сайт
///   (ITP). Иконку на экране «Домой» это не касается.
///
/// Поэтому сказать надо до того, как игрок вложился в гараж во вкладке, и
/// один раз: уведомлений в игре минимум.
///
/// Правило — здесь, в чистом Dart, а браузер только отвечает на вопросы
/// (`ios_launch.dart`). Так оно проверяется тестом на строках user agent,
/// без браузера.
library;

import 'settings.dart';

/// Как открыта игра.
enum IosLaunch {
  /// Не iOS или не веб. Хранилище не делится, подсказка не нужна.
  other,

  /// Вкладка браузера на iPhone или iPad — Safari или встроенный браузер
  /// мессенджера. По user agent их надёжно не различить, да и незачем:
  /// хранилище у обоих не то, что у иконки.
  browserTab,

  /// Приложение с экрана «Домой».
  homeScreen,
}

/// Как открыта игра — по тому, что браузер говорит о себе.
///
/// iPad с iPadOS 13 по умолчанию представляется Маком. Отличает его только
/// сенсорный экран: у Маков его нет, и [maxTouchPoints] там 0.
/// [standalone] — открыто ли как приложение (`navigator.standalone`).
IosLaunch iosLaunchOf({
  required String userAgent,
  required int maxTouchPoints,
  required bool standalone,
}) {
  final ios = _iosDevice.hasMatch(userAgent) ||
      (userAgent.contains('Macintosh') && maxTouchPoints > 1);
  if (!ios) return IosLaunch.other;
  return standalone ? IosLaunch.homeScreen : IosLaunch.browserTab;
}

final _iosDevice = RegExp('iPhone|iPad|iPod');

/// Показать ли подсказку на этом запуске.
bool shouldSuggestHomeScreen(IosLaunch launch, SettingsStore settings) =>
    launch == IosLaunch.browserTab &&
    settings.read(SettingsKeys.homeScreenHint) == null;

/// Подсказку закрыли — больше не показывать.
Future<void> markHomeScreenHintSeen(SettingsStore settings) =>
    settings.write(SettingsKeys.homeScreenHint, 'seen');
