import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/pixel/garage_room.dart';
import 'package:idle_game/ui/pixel/pixel_sprite.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/pixel/still_sprites.dart';

/// Бюджеты производительности.
///
/// В игре будет становиться больше всего: аппаратов, эффектов, событий. Если
/// не мерить сейчас, каждое добавление будет незаметно откусывать по кадру, и
/// однажды окажется, что игра тормозит, а виноватых нет.
///
/// Числа — это не «сколько сейчас», а «сколько позволено». Они с запасом:
/// падение теста означает не «стало на 10 % медленнее», а «появилось что-то
/// принципиально дорогое».
///
/// Мерить в тестах шумно, поэтому берём медиану из нескольких прогонов и
/// держим пороги с запасом в разы.
void main() {
  /// Медианное время одного вызова [body] в микросекундах.
  double medianMicros(int runs, int iterations, void Function() body) {
    final samples = <double>[];
    for (var r = 0; r < runs; r++) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        body();
      }
      sw.stop();
      samples.add(sw.elapsedMicroseconds / iterations);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  /// Замер печатается всегда, а не только при провале: по этим строкам видно
  /// не «прошло», а «сколько осталось до потолка».
  void report(String what, double micros, double budget) {
    final share = (micros / budget * 100).toStringAsFixed(0);
    // ignore: avoid_print
    print('  ЗАМЕР  $what: ${micros.toStringAsFixed(1)} мкс '
        'из ${budget.toStringAsFixed(0)} ($share % бюджета)');
  }

  group('Движок укладывается в бюджет тика', () {
    late GameState rich;

    setUp(() {
      const engine = GameEngine();
      var s = GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: DateTime.utc(2026),
      );
      s = s.copyWith(resources: s.resources.copyWith(money: 1e30));
      // Поздняя игра: всё куплено пачками, все улучшения взяты.
      for (final g in kGenerators) {
        s = engine.buyGeneratorBulk(s, g.id, 120, DateTime.utc(2026));
      }
      for (final u in kUpgrades) {
        s = engine.buyUpgrade(s, u.id, DateTime.utc(2026));
      }
      rich = s;
    });

    test('тик поздней игры дешевле 200 микросекунд', () {
      const engine = GameEngine();
      var t = DateTime.utc(2026, 1, 1);
      final micros = medianMicros(5, 200, () {
        t = t.add(const Duration(milliseconds: 200));
        engine.processTick(rich, t);
      });

      // Тик идёт пять раз в секунду. 200 мкс — это 0.1 % кадрового бюджета,
      // то есть с огромным запасом.
      report('тик поздней игры', micros, 200);
      expect(micros, lessThan(200),
          reason: 'тик стал дорогим: ${micros.toStringAsFixed(1)} мкс');
    });

    test('пересчёт дохода не зависит от количества штук', () {
      // Доход обязан считаться по тринадцати аппаратам, а не по тысячам
      // купленных штук. Если кто-нибудь заменит формулу циклом по единицам,
      // поздняя игра встанет — этот тест поймает.
      const engine = GameEngine();
      var few = GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: DateTime.utc(2026),
      );
      few = few.copyWith(resources: few.resources.copyWith(money: 1e6));
      few = engine.buyGenerator(few, 'banka', DateTime.utc(2026));

      // Меряем не чтение кэша, а сам пересчёт: он случается при каждой покупке.
      final cheap = medianMicros(
        5,
        500,
        () => few.copyWith(generators: few.generators),
      );
      final expensive = medianMicros(
        5,
        500,
        () => rich.copyWith(generators: rich.generators),
      );

      report('пересчёт дохода (поздняя игра)', expensive, cheap + 50);
      expect(
        expensive,
        lessThan(cheap + 50),
        reason: 'стоимость пересчёта растёт с количеством штук: '
            '$cheap → $expensive мкс',
      );
    });

    test('покупка пачкой не считает штуки по одной', () {
      const engine = GameEngine();
      var s = GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: DateTime.utc(2026),
      );
      s = s.copyWith(resources: s.resources.copyWith(money: 1e30));

      final micros = medianMicros(
        5,
        50,
        () => engine.buyGeneratorBulk(s, 'banka', 5000, DateTime.utc(2026)),
      );
      report('покупка 5000 штук пачкой', micros, 500);
      expect(micros, lessThan(500),
          reason: 'пачка считается циклом, а не формулой: $micros мкс');
    });
  });

  group('Кадр не делает лишней работы', () {
    testWidgets('сцена гаража переживает секунду анимации в бюджете', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialStateProvider.overrideWithValue(_lateGame()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily),
            home: const Scaffold(body: GarageScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Секунда живой анимации, несколько раз, берём медиану.
      //
      // Одиночный замер здесь врёт: между прогонами одного и того же кода
      // выходило от 12 до 18 мс на кадр — машина в это время собирала проект.
      // Поэтому и порог стоит с большим запасом: этот тест ловит не «стало на
      // десять процентов медленнее», а «появилось что-то принципиально
      // дорогое». Тонкую разницу ловят замеры выше, они куда стабильнее.
      //
      // И отдельно: тестовый стенд рисует программно и в отладочном режиме,
      // так что абсолютные миллисекунды тут НЕ равны миллисекундам на
      // телефоне. Значение имеет только порядок величины.
      final samples = <double>[];
      for (var run = 0; run < 3; run++) {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 60);
      }
      samples.sort();
      final perFrame = samples[1];

      report('кадр сцены целиком (медиана 3 прогонов)', perFrame, 30000);
      expect(tester.takeException(), isNull);
      expect(
        perFrame,
        lessThan(30000),
        reason: 'кадр стал принципиально дороже: ${perFrame.toStringAsFixed(0)} мкс',
      );
    });
  });

  group('Отрисовка пикселей укладывается в кадр', () {
    testWidgets('неподвижный слой комнаты перерисовывается только со стадией',
        (tester) async {
      // Комната — самый дорогой рисунок в сцене: кирпич, пятна, обстановка.
      // Она обязана рисоваться один раз на стадию. Заведи в ней кто-нибудь
      // анимацию — перерисовка вернётся шестьдесят раз в секунду и потеряется
      // незаметно, поэтому контракт закреплён тестом.
      CustomPainter painterOf() =>
          tester.widget<CustomPaint>(find.byType(CustomPaint).first).painter!;

      await tester.pumpWidget(
        const SizedBox(
          width: 200,
          height: 200,
          child: RoomBackground(stage: GarageStage.garage),
        ),
      );
      final same = painterOf();

      await tester.pumpWidget(
        const SizedBox(
          width: 200,
          height: 200,
          child: RoomBackground(stage: GarageStage.garage),
        ),
      );
      expect(painterOf().shouldRepaint(same), isFalse,
          reason: 'та же стадия — перерисовывать нечего');

      await tester.pumpWidget(
        const SizedBox(
          width: 200,
          height: 200,
          child: RoomBackground(stage: GarageStage.plant),
        ),
      );
      expect(painterOf().shouldRepaint(same), isTrue,
          reason: 'смена стадии обязана перерисовать комнату');
    });

    test('спрайт рисуется за единицы микросекунд, а не десятки', () async {
      final sprite = stillSpriteFor('zmeevik');
      final painter = PixelPainter(sprite: sprite);
      const size = Size(56, 72);

      final micros = medianMicros(5, 200, () {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, size);
        recorder.endRecording().dispose();
      });

      // Шесть аппаратов на сцене, шестьдесят кадров в секунду: на всю
      // отрисовку есть примерно 2 мс, то есть около 300 мкс на аппарат.
      //
      // Порог стоит с запасом намеренно. При пороге 80 тест падал в общем
      // прогоне и проходил в одиночном: машина в это время занята другими
      // тестами, и замер уезжает вдвое. Ловить надо подорожание в разы, а не
      // загрузку машины.
      report('один спрайт', micros, 200);
      expect(micros, lessThan(200),
          reason: 'один спрайт стоит ${micros.toStringAsFixed(1)} мкс — '
              'шесть штук по 60 раз в секунду это не переживут');
    });

    test('вся сцена аппаратов дешевле трети кадра', () {
      const size = Size(56, 72);
      final sprites = [
        for (final id in ['banka', 'bidon', 'flyaga', 'dedov', 'zmeevik', 'tseh'])
          stillSpriteFor(id),
      ];

      final micros = medianMicros(5, 60, () {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        for (final s in sprites) {
          PixelPainter(sprite: s).paint(canvas, size);
        }
        recorder.endRecording().dispose();
      });

      report('шесть аппаратов', micros, 5000);
      expect(micros, lessThan(5000),
          reason: 'сцена стоит ${micros.toStringAsFixed(0)} мкс при бюджете '
              'кадра 16 000');
    });
  });
}

/// Поздняя игра: всё куплено, сцена забита аппаратами.
GameState _lateGame() {
  const engine = GameEngine();
  final t = DateTime.utc(2026);
  var s = GameState.initial(
    initialGenerators: kGenerators,
    initialUpgrades: kUpgrades,
    lastUpdateTime: t,
  );
  s = s.copyWith(resources: s.resources.copyWith(money: 1e30));
  for (final g in kGenerators) {
    s = engine.buyGeneratorBulk(s, g.id, 60, t);
  }
  for (final u in kUpgrades) {
    s = engine.buyUpgrade(s, u.id, t);
  }
  return s;
}
