import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/bootstrap.dart';
import 'package:idle_game/core/game_clock.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/prefs_storage.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/main.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/generator.dart';
import 'package:idle_game/models/upgrade.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/screens/save_rescue.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/moments.dart';

/// Нечитаемый сейв не пропадает молча.
///
/// Раньше битый сейв и сейв более новой версии игра одинаково меняла на
/// пустой гараж и через 20 секунд писала его поверх: прогресс пропадал без
/// копии и без слова. Самый вероятный путь — iPhone: игра с экрана «Домой»
/// открывается закэшированной старой сборкой и видит сейв «из будущего».
///
/// Проверяется настоящий запуск поверх настоящего хранилища: ключи
/// `vitya_save` и `vitya_save_rescue` здесь написаны буквально, потому что
/// переименовать их — значит потерять у игроков и сейв, и копии.
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

  const saveKey = 'vitya_save';
  const rescueKey = 'vitya_save_rescue';

  final clock = GameClock(now: () => quietMoment);
  const serializer = GameSerializer();
  const codec = SaveCodec();

  /// Сейв так, как его пишет игра: гараж с [lifetime] нагнанного.
  String saveOf({double lifetime = 0, double money = 0}) {
    final s = newGame(content: kGenerators, upgrades: kUpgrades, now: quietMoment);
    return codec.encode(serializer.toJson(
      s.copyWith(
        resources: s.resources.copyWith(money: money),
        prestige: s.prestige.copyWith(totalEverEarned: lifetime),
      ),
      lastSeenMillis: quietMoment.millisecondsSinceEpoch,
    ));
  }

  const broken = '{"version": 1, "ml": 12.5, "money": 40';
  const future = '{"version": ${kSaveVersion + 1}, "money": 900}';

  /// Что лежит в хранилище браузера прямо сейчас.
  Future<String?> stored() async =>
      (await SharedPreferences.getInstance()).getString(saveKey);
  Future<List<String>> copies() async => SaveService(
        storage: PrefsSaveStorage(await SharedPreferences.getInstance()),
      ).rescued();

  /// Игра, собранная так же, как в `main`.
  Future<ProviderContainer> launch(
    WidgetTester tester,
    Bootstrap boot, {
    Size size = const Size(390, 844),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...bootOverrides(boot),
        timeProvider.overrideWithValue(() => quietMoment),
        clockProvider.overrideWithValue(clock),
      ],
      child: VityaApp(boot: boot),
    ));
    // Первый кадр, потом вступления и анимация диалога.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  group('Битый сейв', () {
    test('копия ложится до первой записи и переживает её', () async {
      SharedPreferences.setMockInitialValues({saveKey: broken});
      final boot = await bootstrapGame(clock: clock);

      expect(boot.saveWasLost, isTrue);
      expect(boot.brokenSave, broken, reason: 'игроку нечего будет скопировать');
      expect(boot.brokenSaveKept, isTrue);

      // Запуск закончен, игры ещё нет, записей ещё не было.
      expect(await stored(), broken);
      expect(await copies(), [broken],
          reason: 'к первому кадру копия обязана уже лежать: автосейв и '
              'запись при сворачивании появляются вместе с игрой');

      // Первая запись нового гаража.
      await boot.saves.save(serializer.toJson(boot.state,
          lastSeenMillis: quietMoment.millisecondsSinceEpoch));
      expect(await stored(), isNot(broken));
      expect(await copies(), [broken]);
    });

    testWidgets('игроку говорят, и автосейв копию не трогает', (tester) async {
      SharedPreferences.setMockInitialValues({saveKey: broken});
      final boot = await bootstrapGame(clock: clock);
      await launch(tester, boot);

      expect(find.text('Сейв не читается'), findsOneWidget,
          reason: 'пустой гараж без слова читается как потеря прогресса');

      await tester.tap(find.text('Понятно'));
      await tester.pump(const Duration(seconds: 25));

      expect(codec.decode(await stored()).isEmpty, isFalse,
          reason: 'новый гараж записан');
      expect(await copies(), [broken]);
    });

    testWidgets('строка копируется целиком', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      SharedPreferences.setMockInitialValues({saveKey: broken});
      await launch(tester, await bootstrapGame(clock: clock));
      await tester.tap(find.text('Скопировать'));
      await tester.pump();
      await tester.pump();

      expect(copied, broken, reason: 'разработчику нужна строка как лежала');
      expect(find.textContaining('Скопировано'), findsOneWidget,
          reason: 'без отклика игрок не знает, получилось ли');
    });

    test('сейв, который не собрался в гараж, — тоже нечитаемый', () async {
      // JSON цел, но сериализатор бросает. Раньше это был белый экран на
      // каждом запуске.
      final save = saveOf(lifetime: 100);
      SharedPreferences.setMockInitialValues({saveKey: save});
      final boot =
          await bootstrapGame(clock: clock, serializer: const _Buggy());

      expect(boot.brokenSave, save);
      expect(await copies(), [save]);
      expect(boot.state.prestige.totalEverEarned, 0,
          reason: 'гараж начат заново, а не собран наполовину');
    });
  });

  group('Когда копия уже лежит', () {
    test('лежащая не перезаписывается, новая ложится рядом', () async {
      final saves = SaveService(storage: MemorySaveStorage());
      expect(await saves.rescue('первый'), isTrue);
      expect(await saves.rescue('второй'), isTrue);
      expect(await saves.rescued(), ['первый', 'второй']);
    });

    test('тот же битый сейв второй раз копию не дублирует', () async {
      // Игру закрыли раньше автосейва — под основным ключом тот же сейв.
      final saves = SaveService(storage: MemorySaveStorage());
      await saves.rescue('битый');
      expect(await saves.rescue('битый'), isTrue);
      expect(await saves.rescued(), ['битый']);
    });

    test('сверх потолка не ложится, и об этом говорят', () async {
      final saves = SaveService(storage: MemorySaveStorage());
      for (var i = 0; i < SaveService.maxRescued; i++) {
        await saves.rescue('копия $i');
      }
      expect(await saves.rescue('лишняя'), isFalse,
          reason: 'нельзя сказать игроку «отложено», если не отложено');
      expect(await saves.rescued(), hasLength(SaveService.maxRescued));
      expect((await saves.rescued()).first, 'копия 0',
          reason: 'первая копия ценнее: дальше — свежие гаражи');
    });

    testWidgets('не легла — игроку не обещают, что отложено', (tester) async {
      SharedPreferences.setMockInitialValues({
        saveKey: broken,
        rescueKey: '["a", "b", "c"]',
      });
      final boot = await bootstrapGame(clock: clock);
      expect(boot.brokenSaveKept, isFalse);

      await launch(tester, boot);
      expect(find.textContaining('Скопируй его сейчас'), findsOneWidget);
      expect(find.textContaining('не сотрётся'), findsNothing);
    });

    test('полный сброс копии не трогает', () async {
      final saves = SaveService(storage: MemorySaveStorage());
      await saves.rescue('битый');
      await saves.wipe();
      expect(await saves.rescued(), ['битый']);
    });
  });

  group('Сейв новой версии', () {
    test('не порча, и копии нет — он цел на своём месте', () async {
      expect(codec.decode(future).fromFuture, isTrue);
      expect(codec.decode(future).wasCorrupt, isFalse);

      SharedPreferences.setMockInitialValues({saveKey: future});
      final boot = await bootstrapGame(clock: clock);
      expect(boot.saveFromFuture, isTrue);
      expect(boot.saveWasLost, isFalse);
      expect(await copies(), isEmpty);
    });

    testWidgets('не перезаписывается ни автосейвом, ни при сворачивании',
        (tester) async {
      SharedPreferences.setMockInitialValues({saveKey: future});
      final game = await launch(tester, await bootstrapGame(clock: clock));
      addTearDown(() => tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed));

      expect(find.byType(SaveFromFutureScreen), findsOneWidget);
      expect(find.byType(GarageScreen), findsNothing,
          reason: 'в старой версии играть нельзя: всё сыгранное пропадёт');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // Даже если кто-то поднимет игру мимо экрана — писать ей нечем.
      await game.read(gameProvider.notifier).saveNow();
      await tester.pump(const Duration(seconds: 25));

      expect(await stored(), future);
    });
  });

  group('Восстановление из копии', () {
    /// Гараж сломался на старой версии, игрок начал новый, вышла версия,
    /// которая старый читает.
    Future<Bootstrap> afterUpdate() async {
      SharedPreferences.setMockInitialValues(
          {saveKey: saveOf(lifetime: 5e6, money: 777)});
      final old = await bootstrapGame(clock: clock, serializer: const _Buggy());
      expect(old.brokenSaveKept, isTrue);
      await old.saves.save(serializer.toJson(old.state,
          lastSeenMillis: quietMoment.millisecondsSinceEpoch));

      return bootstrapGame(clock: clock);
    }

    test('копия, которую теперь можно прочитать, предлагается', () async {
      final boot = await afterUpdate();
      expect(boot.rescuedGarage, isNotNull);
      expect(boot.rescuedGarage!.state.prestige.totalEverEarned, 5e6);
      expect(boot.state.prestige.totalEverEarned, 0,
          reason: 'до согласия игрока гараж нынешний');
    });

    testWidgets('«вернуть» возвращает гараж и убирает копию', (tester) async {
      final game = await launch(tester, await afterUpdate());
      expect(find.text('Старый гараж нашёлся'), findsOneWidget);

      await tester.tap(find.text('Вернуть старый'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final state = game.read(gameProvider);
      expect(state.prestige.totalEverEarned, 5e6);
      expect(state.resources.money, closeTo(777, 1e-6));
      final saved = codec.decode(await stored()).data!;
      expect(saved['lifetime'], 5e6, reason: 'вернувшийся гараж не записан');
      expect(await copies(), isEmpty, reason: 'вопрос повторится снова');
    });

    testWidgets('«оставить нынешний» гараж не трогает, копию выбрасывает',
        (tester) async {
      final game = await launch(tester, await afterUpdate());
      final before = await stored();

      await tester.tap(find.text('Оставить нынешний'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(game.read(gameProvider).prestige.totalEverEarned, 0);
      expect(await stored(), before);
      expect(await copies(), isEmpty);
    });

    test('нечитаемую копию не предлагают', () async {
      SharedPreferences.setMockInitialValues({
        saveKey: saveOf(),
        rescueKey: '["{не json"]',
      });
      final boot = await bootstrapGame(clock: clock);
      expect(boot.rescuedGarage, isNull);
      expect(await copies(), ['{не json'], reason: 'и не выбрасывают');
    });

    test('из нескольких читаемых — та, где нагнано больше', () async {
      final small = saveOf(lifetime: 10);
      final big = saveOf(lifetime: 1e9);
      SharedPreferences.setMockInitialValues({saveKey: saveOf()});
      final storage = PrefsSaveStorage(await SharedPreferences.getInstance());
      final saves = SaveService(storage: storage);
      await saves.rescue(small);
      await saves.rescue(big);

      final boot = await bootstrapGame(clock: clock);
      expect(boot.rescuedGarage!.raw, big);
    });
  });

  group('Экраны влезают в 320×640', () {
    const narrow = Size(320, 640);

    /// Целиком на экране — иначе до кнопки не дотянуться.
    void expectOnScreen(WidgetTester tester, Finder finder) {
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(
        rect.left >= 0 &&
            rect.top >= 0 &&
            rect.right <= narrow.width &&
            rect.bottom <= narrow.height,
        isTrue,
        reason: '$rect за краем экрана 320×640',
      );
    }

    testWidgets('сейв новой версии: кнопка на виду и работает', (tester) async {
      tester.view
        ..physicalSize = narrow
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var reloads = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily),
        home: SaveFromFutureScreen(canReload: true, onReload: () => reloads++),
      ));

      expect(tester.takeException(), isNull);
      expectOnScreen(tester, find.text('ПЕРЕЗАГРУЗИТЬ'));
      await tester.tap(find.text('ПЕРЕЗАГРУЗИТЬ'));
      expect(reloads, 1);
    });

    testWidgets('битый сейв: худший случай — копия не легла, буфер не дали',
        (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.setData'
            ? throw PlatformException(code: 'NotAllowedError')
            : null,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      SharedPreferences.setMockInitialValues({
        saveKey: '${saveOf(lifetime: 1e12, money: 1e9)}x',
        rescueKey: '["a", "b", "c"]',
      });
      await launch(tester, await bootstrapGame(clock: clock), size: narrow);

      await tester.tap(find.text('Скопировать'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SelectableText), findsOneWidget,
          reason: 'строку нельзя унести ни буфером, ни руками');
      expectOnScreen(tester, find.text('Скопировать'));
      expectOnScreen(tester, find.text('Понятно'));
    });

    testWidgets('старый гараж нашёлся: обе кнопки на виду', (tester) async {
      SharedPreferences.setMockInitialValues({
        saveKey: saveOf(lifetime: 3.3e33),
        rescueKey: jsonEncode([saveOf(lifetime: 7.7e77)]),
      });
      await launch(tester, await bootstrapGame(clock: clock), size: narrow);

      expect(tester.takeException(), isNull);
      expect(find.text('Старый гараж нашёлся'), findsOneWidget);
      expectOnScreen(tester, find.text('Вернуть старый'));
      expectOnScreen(tester, find.text('Оставить нынешний'));
    });
  });
}

/// Версия с поломкой в разборе: JSON читается, а гараж из него не собирается.
class _Buggy extends GameSerializer {
  const _Buggy();

  @override
  GameState fromJson(
    Map<String, dynamic> json, {
    required List<Generator> content,
    required List<Upgrade> upgrades,
    required DateTime now,
  }) =>
      throw StateError('поломка разбора');
}
