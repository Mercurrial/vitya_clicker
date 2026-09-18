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

  group('События случаются, но не постоянно', () {
    test('за сутки их несколько, а не ноль и не сорок', () {
      final perDay = windows(7).length / 7;
      expect(perDay, greaterThanOrEqualTo(4),
          reason: 'события, которое не наступает, не существует');
      expect(perDay, lessThanOrEqualTo(24),
          reason: 'если гость в гараже всегда, он уже не гость, а Петрович');
    });

    test('большую часть времени в гараже тихо', () {
      var busy = 0;
      const minutes = 3 * 24 * 60;
      for (var m = 0; m < minutes; m++) {
        if (eventAt(start.add(Duration(minutes: m))) != null) busy++;
      }
      final share = busy / minutes;
      expect(share, lessThan(0.5),
          reason: 'событие должно быть событием, а не фоном: занято '
              '${(share * 100).round()}% времени');
      expect(share, greaterThan(0.05));
    });

    test('все события когда-нибудь выпадают', () {
      // Иначе самое редкое видит только тот, кто играет месяцами.
      final seen = windows(30).map((w) => w.id).toSet();
      expect(seen.length, kGarageEvents.length,
          reason: 'не выпали: '
              '${kGarageEvents.map((e) => e.id).toSet().difference(seen)}');
    });
  });

  group('Расписание одинаково у всех', () {
    test('ответ зависит только от момента времени', () {
      for (var m = 0; m < 500; m++) {
        final now = start.add(Duration(minutes: m));
        expect(eventAt(now)?.event.id, eventAt(now)?.event.id);
      }
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
