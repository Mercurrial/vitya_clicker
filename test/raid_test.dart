import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/raid.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/models/sort_state.dart';

/// ШУХЕР.
///
/// Механика единственная в игре, которая ОТБИРАЕТ. Значит, к ней и требования
/// строже всех: она обязана быть предсказуемой, редкой, заметной заранее и
/// безопасной для того, кто просто не играет.
void main() {
  final start = DateTime.utc(2026, 4, 1);
  const engine = GameEngine();

  group('Обход можно заметить и переждать', () {
    test('каждый обход начинается с предупреждения, и оно не короче обещанного',
        () {
      // Отобрать без предупреждения — это не напряжение, а произвол.
      // Поэтому смотрим на КАЖДЫЙ обход целиком: сколько секунд он
      // предупреждал и с какой фазы начался.
      final warnSeconds = <int, int>{};
      final firstPhase = <int, RaidPhase>{};

      for (var s = 0; s < 3 * 24 * 60 * 60; s++) {
        final raid = raidAt(start.add(Duration(seconds: s)));
        if (raid == null) continue;
        firstPhase.putIfAbsent(raid.id, () => raid.phase);
        if (raid.isWarning) {
          warnSeconds[raid.id] = (warnSeconds[raid.id] ?? 0) + 1;
        }
      }

      expect(firstPhase, isNotEmpty, reason: 'обходов не нашлось вовсе');
      for (final entry in firstPhase.entries) {
        expect(entry.value, RaidPhase.warning,
            reason: 'обход ${entry.key} начался сразу с обыска');
        expect(warnSeconds[entry.key], kRaidWarning.inSeconds,
            reason: 'обход ${entry.key} предупреждал не столько, сколько обещано');
      }
    });

    test('предупреждения хватает, чтобы среагировать', () {
      expect(kRaidWarning.inSeconds, greaterThanOrEqualTo(5),
          reason: 'меньше пяти секунд — это ловушка, а не предупреждение');
    });

    test('обход не длится вечно', () {
      for (var m = 0; m < 24 * 60; m++) {
        final raid = raidAt(start.add(Duration(minutes: m)));
        if (raid == null) continue;
        expect(raid.remaining, greaterThan(Duration.zero));
        expect(raid.remaining, lessThanOrEqualTo(kRaidWarning + kRaidSearch));
      }
    });
  });

  group('Обход — событие, а не фон', () {
    test('в гараже тихо почти всё время', () {
      var busy = 0;
      const seconds = 24 * 60 * 60;
      for (var s = 0; s < seconds; s += 5) {
        if (raidAt(start.add(Duration(seconds: s))) != null) busy += 5;
      }
      final share = busy / seconds;
      expect(share, lessThan(0.02),
          reason: 'участковый занимает ${(share * 100).toStringAsFixed(1)}% '
              'суток — это уже не обход, а прописка');
      expect(share, greaterThan(0.0),
          reason: 'механика, которая не наступает, не существует');
    });

    test('за сутки обходов единицы', () {
      var starts = 0;
      int? last;
      for (var s = 0; s < 24 * 60 * 60; s++) {
        final id = raidAt(start.add(Duration(seconds: s)))?.id;
        if (id != null && id != last) starts++;
        last = id;
      }
      expect(starts, inInclusiveRange(5, 30));
    });

    test('участковый не ходит в обнимку с покупателем', () {
      // Гость и обход в одну минуту читались бы как заговор, а не как
      // совпадение. Зёрна расписаний разведены намеренно.
      var together = 0;
      for (var m = 0; m < 7 * 24 * 60; m++) {
        final now = start.add(Duration(minutes: m));
        if (raidAt(now) != null && eventAt(now) != null) together++;
      }
      expect(together / (7 * 24 * 60), lessThan(0.01));
    });
  });

  group('Наказание обидное, но восполнимое', () {
    test('забирает часть бака и ступень сорта', () {
      var state = newGame(content: kGenerators, upgrades: kUpgrades, now: start);
      state = state.copyWith(
        resources: state.resources.copyWith(ml: 1000),
        sort: const SortState(index: 3),
      );

      final after = engine.seizeByPolice(state, start);

      expect(after.resources.ml,
          closeTo(1000 * (1 - Balance.current.raidSeizure), 1e-6));
      expect(after.sort.index, 2);
    });

    test('не забирает всё', () {
      // Потерять час работы из-за незамеченной плашки — повод удалить игру.
      expect(Balance.current.raidSeizure, lessThan(0.6));
      expect(Balance.current.raidSeizure, greaterThan(0.1));
    });

    test('не трогает ни деньги, ни аппараты, ни мудрость', () {
      var state = newGame(content: kGenerators, upgrades: kUpgrades, now: start);
      state = state.copyWith(
        resources: state.resources.copyWith(ml: 1000, money: 5000),
        prestige: const PrestigeState(
          totalEverEarned: 1e9,
          claimedMl: 1e9,
        ),
      );

      final after = engine.seizeByPolice(state, start);

      expect(after.resources.money, 5000, reason: 'деньги не конфискуют');
      expect(after.generators, state.generators, reason: 'аппараты остаются');
      expect(after.prestige, state.prestige,
          reason: 'нагнанное было нагнано: историю задним числом не отбирают');
    });

    test('у пустого гаража отбирать нечего', () {
      final state = newGame(content: kGenerators, upgrades: kUpgrades, now: start);
      expect(engine.seizeByPolice(state, start), state,
          reason: 'наказание пустого — это просто грубость');
    });
  });

  group('Расписание одинаково у всех', () {
    test('ответ зависит только от момента', () {
      for (var m = 0; m < 500; m++) {
        final now = start.add(Duration(minutes: m));
        expect(raidAt(now)?.id, raidAt(now)?.id);
      }
    });

    test('часовой пояс ничего не меняет', () {
      final utc = DateTime.utc(2026, 4, 1, 9, 17);
      expect(raidAt(utc.toLocal())?.id, raidAt(utc)?.id);
    });
  });
}
