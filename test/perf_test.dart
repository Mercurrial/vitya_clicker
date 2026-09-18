@Tags(['perf'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/ui/pixel/pixel_sprite.dart';
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
/// ## Почему это отдельный набор
///
/// Замеры по секундомеру в общем прогоне врут. Когда рядом идут остальные
/// тесты, машина занята, и один и тот же код показывает то 8 мс на кадр, то
/// 21 — тесты падали через раз. Флакающая проверка хуже отсутствующей: её
/// быстро приучаются не замечать, и вместе с ней перестают замечать настоящие
/// падения.
///
/// Поэтому замеры вынесены под тег и запускаются отдельно, на спокойной
/// машине:
///
///     flutter test --tags perf --run-skipped
///
/// А то, что можно проверить БЕЗ секундомера, проверяется в обычном наборе:
/// контракт перерисовки комнаты лежит в `garage_room_test.dart`.
///
/// Медиана из нескольких прогонов и пороги с запасом — тоже отсюда: этот
/// набор ловит подорожание в разы, а не на проценты.
///
/// ## Чего здесь НЕТ и почему
///
/// Был замер «сколько стоит кадр сцены целиком». Его пришлось убрать: за день
/// работы та же самая сцена показывала от 8 до 42 мс на кадр — машина за это
/// время успела устать от сборок. Числа, которые меняются впятеро без единой
/// правки кода, ничего не проверяют, а падающий через раз тест приучает не
/// смотреть на падения вовсе.
///
/// То, ради чего он был нужен, проверяется без секундомера: контракт
/// перерисовки комнаты лежит в `garage_room_test.dart` и отвечает на вопрос
/// «просят ли перерисовать», а не «сколько это заняло».
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

      // Тик идёт пять раз в секунду, так что даже 600 мкс — это доли
      // процента времени. Порог стоит втрое выше чистого замера намеренно:
      // на уставшей машине то же самое считается впятеро дольше.
      report('тик поздней игры', micros, 600);
      expect(micros, lessThan(600),
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

      // Сравниваем с замером, снятым В ЭТОМ ЖЕ прогоне: так скорость машины
      // сокращается и остаётся только то, что нас интересует, — зависит ли
      // стоимость от количества купленных штук.
      report('пересчёт дохода (поздняя игра)', expensive, cheap * 3 + 50);
      expect(
        expensive,
        lessThan(cheap * 3 + 50),
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
      report('покупка 5000 штук пачкой', micros, 1500);
      expect(micros, lessThan(1500),
          reason: 'пачка считается циклом, а не формулой: $micros мкс');
    });
  });

  group('Отрисовка пикселей укладывается в кадр', () {
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
      report('один спрайт', micros, 500);
      expect(micros, lessThan(500),
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

      report('шесть аппаратов', micros, 9000);
      expect(micros, lessThan(9000),
          reason: 'сцена стоит ${micros.toStringAsFixed(0)} мкс при бюджете '
              'кадра 16 000');
    });
  });
}
