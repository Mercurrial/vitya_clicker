import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/bootstrap.dart';
import 'package:idle_game/core/game_clock.dart';
import 'package:idle_game/core/home_screen.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/main.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/providers/ios_launch_provider.dart';
import 'package:idle_game/ui/screens/home_screen_hint.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/moments.dart';

/// Подсказка «поставь на экран Домой» на iPhone.
///
/// У иконки на экране «Домой» своё хранилище, отдельное от Safari, а во
/// вкладке Safari сейв стирается после недели без игры (`home_screen.dart`).
/// Игрок, которому этого не сказали, теряет гараж. Сказать надо во вкладке
/// на iOS, один раз и не поперёк сообщений о сейве; вне iOS и с экрана
/// «Домой» — никогда.
///
/// Браузер здесь не нужен: платформа подменяется через [iosLaunchProvider],
/// а её определение проверяется на настоящих строках user agent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Настоящие шрифты: «влезает ли в 320×640» зависит от ширины букв.
    const fonts = {
      GType.uiFamily: ['Rubik-Variable.ttf'],
      GType.numFamily: [
        'IBMPlexMono-Regular.ttf',
        'IBMPlexMono-Medium.ttf',
        'IBMPlexMono-SemiBold.ttf',
        'IBMPlexMono-Bold.ttf',
      ],
    };
    for (final MapEntry(key: family, value: files) in fonts.entries) {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });

  group('Как открыта игра', () {
    const iphoneSafari = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac '
        'OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
        'Mobile/15E148 Safari/604.1';
    // С экрана «Домой» и во встроенном браузере мессенджера строка без
    // «Safari/» — по ней одной их не различить.
    const iphoneWebView = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac '
        'OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
    const iphoneChrome = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac '
        'OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
        'CriOS/126.0.6478.54 Mobile/15E148 Safari/604.1';
    // iPad по умолчанию просит «версию для компьютера» и выглядит Маком.
    const macSafari = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
        'Safari/605.1.15';
    const androidChrome = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile '
        'Safari/537.36';
    const windowsChrome = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 '
        'Safari/537.36';

    IosLaunch of(String ua, {int touches = 5, bool standalone = false}) =>
        iosLaunchOf(
          userAgent: ua,
          maxTouchPoints: touches,
          standalone: standalone,
        );

    test('вкладка на iPhone — любая: Safari, Chrome, мессенджер', () {
      expect(of(iphoneSafari), IosLaunch.browserTab);
      expect(of(iphoneChrome), IosLaunch.browserTab);
      expect(of(iphoneWebView), IosLaunch.browserTab);
    });

    test('с экрана «Домой» — не вкладка', () {
      expect(of(iphoneWebView, standalone: true), IosLaunch.homeScreen);
    });

    test('iPad, который выдаёт себя за Мак, узнаётся по касаниям', () {
      expect(of(macSafari, touches: 5), IosLaunch.browserTab);
      expect(of(macSafari, touches: 5, standalone: true),
          IosLaunch.homeScreen);
    });

    test('Мак, Android и Windows — не iOS, даже приложением', () {
      expect(of(macSafari, touches: 0), IosLaunch.other);
      expect(of(macSafari, touches: 0, standalone: true), IosLaunch.other,
          reason: 'приложение в Dock на Маке — не iPhone');
      expect(of(androidChrome), IosLaunch.other);
      expect(of(androidChrome, standalone: true), IosLaunch.other);
      expect(of(windowsChrome, touches: 10), IosLaunch.other,
          reason: 'сенсорный ноутбук — не iPad');
    });
  });

  group('Показать или нет', () {
    test('только во вкладке на iOS и пока не закрыли', () async {
      final settings = MemorySettingsStore();
      expect(shouldSuggestHomeScreen(IosLaunch.browserTab, settings), isTrue);
      expect(shouldSuggestHomeScreen(IosLaunch.homeScreen, settings), isFalse);
      expect(shouldSuggestHomeScreen(IosLaunch.other, settings), isFalse);

      await markHomeScreenHintSeen(settings);
      expect(shouldSuggestHomeScreen(IosLaunch.browserTab, settings), isFalse);
    });
  });

  group('При запуске', () {
    final clock = GameClock(now: () => quietMoment);

    /// Игра, собранная так же, как в `main`, на платформе [launch].
    Future<void> start(
      WidgetTester tester,
      IosLaunch launch, {
      Size size = const Size(390, 844),
    }) async {
      final boot = await bootstrapGame(clock: clock);
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...bootOverrides(boot),
          timeProvider.overrideWithValue(() => quietMoment),
          clockProvider.overrideWithValue(clock),
          iosLaunchProvider.overrideWithValue(launch),
        ],
        child: VityaApp(boot: boot),
      ));
      // Первый кадр, потом вступления и анимация диалога.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// Закрыть верхний диалог, как закрыл бы игрок.
    Future<void> close(WidgetTester tester) async {
      await tester.tap(find.text('Понятно'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// Выгрузить игру, как при закрытии вкладки.
    Future<void> quit(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    Future<String?> stored() async => (await SharedPreferences.getInstance())
        .getString('vitya_setting_${SettingsKeys.homeScreenHint}');

    testWidgets('во вкладке на iPhone — один раз, и только закрытая',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await start(tester, IosLaunch.browserTab);
      expect(find.byType(HomeScreenHint), findsOneWidget,
          reason: 'новичок во вкладке не знает, что прогресс не переедет');
      await quit(tester);

      // Не закрыл, а ушёл ставить иконку — во вкладке напомнят снова.
      await start(tester, IosLaunch.browserTab);
      expect(find.byType(HomeScreenHint), findsOneWidget);
      await close(tester);
      expect(find.byType(HomeScreenHint), findsNothing);
      expect(await stored(), isNotNull,
          reason: 'закрытая подсказка должна пережить перезапуск');
      await quit(tester);

      await start(tester, IosLaunch.browserTab);
      expect(find.byType(HomeScreenHint), findsNothing,
          reason: 'одна подсказка, один раз');
    });

    testWidgets('с экрана «Домой» и вне iOS — никогда', (tester) async {
      for (final launch in [IosLaunch.homeScreen, IosLaunch.other]) {
        SharedPreferences.setMockInitialValues({});
        await start(tester, launch);
        expect(find.byType(HomeScreenHint), findsNothing, reason: '$launch');
        expect(find.byType(AlertDialog), findsNothing,
            reason: 'у новичка на $launch при запуске окон нет вовсе');
        expect(await stored(), isNull);
        await quit(tester);
      }
    });

    testWidgets('не перебивает сообщение о сейве, а идёт следом',
        (tester) async {
      // Играл в тестовую сборку в Safari: гараж начнётся заново, и сперва
      // игрок должен узнать об этом.
      SharedPreferences.setMockInitialValues({
        'vitya_save_v1': '{"version": 5, "ml": 0, "money": 5000000}',
      });

      await start(tester, IosLaunch.browserTab);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(HomeScreenHint), findsNothing,
          reason: 'первым — что стало с сейвом');

      await close(tester);
      expect(find.byType(HomeScreenHint), findsOneWidget,
          reason: 'гараж и так пустой — самое время поставить иконку');

      await close(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('влезает в 320×640: кнопка на виду', (tester) async {
      const narrow = Size(320, 640);
      SharedPreferences.setMockInitialValues({});
      await start(tester, IosLaunch.browserTab, size: narrow);

      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.text('Понятно'));
      expect(
        button.left >= 0 &&
            button.top >= 0 &&
            button.right <= narrow.width &&
            button.bottom <= narrow.height,
        isTrue,
        reason: '$button за краем экрана 320×640',
      );
      await close(tester);
      expect(find.byType(HomeScreenHint), findsNothing);
    });
  });
}
