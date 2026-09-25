import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/sort_state.dart';

/// Случайные события.
///
/// Расписание — чистая функция времени (почему именно так, написано в шапке
/// `lib/content/events.dart`). Поэтому проверяется оно не «примерно», а точно:
/// прогоняем несколько суток и смотрим на статистику. Такой тест поймает и
/// «событий не бывает вовсе», и «событие висит всегда» — а это ровно те две
/// поломки, которые игрок заметит последними.
void main() {
  final start = DateTime.utc(2026, 3, 1);

  /// Все окна за [days] суток: когда началось, что за событие.
  List<({DateTime at, String id})> windows(int days) {
    final found = <({DateTime at, String id})>[];
    String? last;
    for (var m = 0; m < days * 24 * 60; m++) {
      final now = start.add(Duration(minutes: m));
      final active = eventAt(now);
      final id = active?.event.id;
      // Начало окна — переход из «ничего» в «кто-то пришёл».
      if (id != null && id != last) found.add((at: now, id: id));
      last = id;
    }
    return found;
  }

  // Решение владельца (docs/DECISIONS.md, «Гости»): гость приходит ровно
  // раз в десять минут и стоит пять. Раньше здесь проверялось «большую часть
  // времени в гараже тихо» — это было про старое расписание по жребию, где
  // гостя можно было ждать два часа.
  group('Гость приходит по часам', () {
    test('ровно раз в десять минут, в ровные минуты', () {
      final found = windows(1);
      expect(found.length, 24 * 60 ~/ kEventPeriod.inMinutes,
          reason: 'за сутки должно быть 144 гостя');
      for (final w in found) {
        expect(w.at.minute % 10, 0, reason: 'гость пришёл в ${w.at}');
      }
    });

    test('стоит пять минут, потом пять минут тихо', () {
      for (var m = 0; m < 24 * 60; m++) {
        final now = start.add(Duration(minutes: m));
        expect(eventAt(now) != null, now.minute % 10 < 5, reason: '$now');
      }
    });

    test('до следующего гостя не больше десяти минут', () {
      for (var s = 0; s < 3600; s += 7) {
        final now = start.add(Duration(seconds: s));
        final wait = untilNextEvent(now);
        expect(wait, greaterThan(Duration.zero));
        expect(wait, lessThanOrEqualTo(kEventPeriod));
        // Через это время гость действительно в гараже.
        expect(eventAt(now.add(wait)), isNotNull, reason: '$now + $wait');
      }
    });

    test('кто придёт — случайно, и все когда-нибудь выпадают', () {
      final ids = windows(1).map((w) => w.id).toList();
      expect(ids.toSet().length, kGarageEvents.length,
          reason: 'не выпали: '
              '${kGarageEvents.map((e) => e.id).toSet().difference(ids.toSet())}');
      // Не по кругу: иначе игрок выучит очередь.
      var cyclic = true;
      for (var i = kGarageEvents.length; i < ids.length; i++) {
        if (ids[i] != ids[i - kGarageEvents.length]) cyclic = false;
      }
      expect(cyclic, isFalse, reason: 'гости идут по кругу');
    });
  });

  group('Расписание одинаково у всех', () {
    test('ответ зависит только от момента времени', () {
      for (var m = 0; m < 500; m++) {
        final now = start.add(Duration(minutes: m));
        expect(eventAt(now)?.event.id, eventAt(now)?.event.id);
      }
    });

    test('хеш расписания одинаков в браузере и на телефоне', () {
      // В вебе int — это double с 53 точными битами. Считаем тот же хеш на
      // double: если хоть одно произведение вылезет за 2^53, младшие биты
      // потеряются и ответ разойдётся с настоящим. Так и было: веб-версия
      // жила по своему расписанию.
      const m = 1073741824.0; // 2^30
      int viaDoubles(int x) {
        var h = (x % 1073741824).toDouble();
        h = (h * 0x9E37 + 0x7F4A) % m;
        var i = h.toInt() ^ (h.toInt() >> 15);
        h = (i.toDouble() * 0x85EB) % m;
        i = h.toInt() ^ (h.toInt() >> 13);
        h = (i.toDouble() * 0xC2B3) % m;
        return h.toInt() ^ (h.toInt() >> 16);
      }

      final base = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 60000;
      for (var k = 0; k < 20000; k++) {
        final x = base + k * 7919;
        expect(scheduleHash(x), viaDoubles(x), reason: 'x = $x');
      }
      expect((1 << 30) * kScheduleHashMaxFactor + 0x7F4A, lessThan(1 << 53));
    });

    test('часовой пояс ничего не меняет', () {
      // Игрок может сидеть в любом поясе, а событие обязано быть общим.
      final utc = DateTime.utc(2026, 3, 1, 12, 30);
      final local = utc.toLocal();
      expect(eventAt(local)?.event.id, eventAt(utc)?.event.id);
    });

    test('остаток времени убывает и не выходит за длину окна', () {
      for (var m = 0; m < 24 * 60; m++) {
        final active = eventAt(start.add(Duration(minutes: m)));
        if (active == null) continue;
        expect(active.remaining, greaterThan(Duration.zero));
        expect(active.remaining, lessThanOrEqualTo(kEventWindow));
      }
    });
  });

  group('Гость — это обычный покупатель', () {
    const engine = GameEngine();
    final t0 = DateTime.utc(2026, 1, 1);

    test('движок продаёт ему тем же способом, что и Петровичу', () {
      // Смысл превращения события в Buyer: ни движок, ни сейв, ни автопродажа
      // про события не знают вовсе.
      final event = kGarageEvents.firstWhere((e) => e.minSortIndex == 1);
      var state = newGame(content: kGenerators, upgrades: kUpgrades, now: t0);
      state = state.copyWith(
        resources: state.resources.copyWith(ml: 5000),
        sort: const SortState(index: 4),
      );

      final before = state.resources.money;
      final after = engine.sellTo(state, event.asBuyer, t0);

      expect(after.resources.money, greaterThan(before));
      expect(after.resources.ml, 0, reason: 'гость забирает всё, что есть');
    });

    test('слабый сорт гостю не сдашь', () {
      final picky = kGarageEvents.firstWhere((e) => e.minSortIndex >= 3);
      var state = newGame(content: kGenerators, upgrades: kUpgrades, now: t0);
      state = state.copyWith(
        resources: state.resources.copyWith(ml: 5000),
        sort: const SortState(index: 0),
      );

      expect(engine.canSellTo(state, picky.asBuyer), isFalse);
      expect(engine.sellTo(state, picky.asBuyer, t0), state,
          reason: 'отказ должен быть отказом, а не тихой продажей');
    });

    test('гость платит больше Петровича', () {
      for (final e in kGarageEvents) {
        expect(e.multiplier, greaterThan(1.0),
            reason: 'гость, который платит как обычно, — не событие');
      }
    });

    test('гость уносит сорт с собой', () {
      // Иначе выгодно копить сорт вечно и сдавать только по событиям, а
      // Петрович превращается в кнопку «потерять деньги».
      for (final e in kGarageEvents) {
        expect(e.asBuyer.consumesSort, isTrue);
      }
    });
  });
}
