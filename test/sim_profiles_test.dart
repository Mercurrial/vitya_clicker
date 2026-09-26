import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/buyers.dart';
import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/sorts.dart';
import 'package:idle_game/models/achievement.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/models/sort_state.dart';
import 'package:idle_game/sim/balance_sim.dart';
import 'package:idle_game/sim/balance_targets.dart';
import 'package:idle_game/sim/sim_profiles.dart';

/// Симулятор с отсутствием: партия режется на куски игры и ухода.
///
/// Проверяются свойства, которые верны на любом балансе, а не числа: числа
/// задача 4 сдвинет, а эти тесты обязаны пережить переделку экономики.
void main() {
  const sim = BalanceSim();
  const minute = Duration(minutes: 1);
  const night = Duration(hours: 8);

  group('Партия с любого места', () {
    test('кусками — то же самое, что подряд', () {
      // На этом стоят все профили: если продолжение хоть чем-то отличается
      // от непрерывной игры, отсутствие мерялось бы вместе с этой разницей.
      final whole = sim.run(PlayStyle.tryhard, horizon: const Duration(minutes: 40));

      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 15));
      sim.play(p, const Duration(minutes: 25));
      final parts = p.result;

      expect(parts.finalState, whole.finalState);
      expect(parts.sales, whole.sales);
      expect(parts.firstBuy, whole.firstBuy);
      expect(parts.timeline.length, whole.timeline.length);
    });

    test('развилка не трогает исходную партию', () {
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 10));
      final before = p.state;
      final at = p.elapsed;

      final branch = p.fork();
      sim.away(branch, night, Absence.tabOpen);
      sim.play(branch, minute);

      expect(p.state, before);
      expect(p.elapsed, at);
      expect(branch.elapsed, at + night + minute);
    });

    test('отсутствие не считается временем в игре', () {
      final r = daily(sim, PlayStyle.casual, perDay: const Duration(minutes: 5), days: 3);
      expect(r.result.played, const Duration(minutes: 15));
      expect(r.wisdomByDay, hasLength(3));
    });
  });

  group('Закрытая игра', () {
    test('не гонит, а копит поток', () {
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 20));
      final before = p.state;

      sim.away(p, night, Absence.closed);
      expect(p.state.prestige.totalEverEarned, before.prestige.totalEverEarned,
          reason: 'закрытая игра гонит — вернулся бак на возврате');
      expect(p.state.resources, before.resources);
      expect(p.state.flux.seconds, greaterThan(before.flux.seconds));
    });

    test('сутки дают не больше копилки', () {
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 20));
      final eight = p.fork(), day = p.fork();
      sim.away(eight, night, Absence.closed);
      sim.away(day, const Duration(days: 1), Absence.closed);
      expect(day.state.flux.seconds, eight.state.flux.seconds);
      expect(day.state.flux.isBankFull, isTrue);
    });

    test('после возвращения метка времени не тянет за собой разрыв', () {
      // Иначе первый же тик после отсутствия посчитал бы его производством —
      // тот самый двойной счёт, только в симуляторе.
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 20));
      sim.away(p, night, Absence.closed);
      final lifetime = p.state.prestige.totalEverEarned;
      final rate = p.state.mlPerSecond * PlayStyle.tryhard.heat;

      sim.play(p, const Duration(seconds: 1));
      expect(p.state.prestige.totalEverEarned - lifetime,
          lessThanOrEqualTo(rate * 1.01 + 1e-6));
    });
  });

  group('Открытая вкладка', () {
    test('без автопродажи встаёт с полным баком', () {
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(seconds: 30));
      expect(p.state.achievements.hasPerk(AchievementPerk.autoSell), isFalse,
          reason: 'проверка про игрока, у которого автопродажи ещё нет');

      sim.away(p, night, Absence.tabOpen);
      expect(p.state.isTankFull, isTrue);
    });

    test('с автопродажей гонит всю ночь, а закрытая игра — нет', () {
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 15));
      expect(p.state.achievements.hasPerk(AchievementPerk.autoSell), isTrue);

      final tab = p.fork(), closed = p.fork();
      sim.away(tab, night, Absence.tabOpen);
      sim.away(closed, night, Absence.closed);
      expect(
        tab.state.prestige.totalEverEarned,
        greaterThan(closed.state.prestige.totalEverEarned),
      );
      expect(tab.sales, greaterThan(p.sales), reason: 'бак сдавался сам');
    });

    test('ночь вкладки делает за игрока больше, чем ночь закрытой игры', () {
      // Та самая дыра из плана: 17 минут и ночь вкладки — первая мудрость.
      // Здесь только порядок; сколько минут допустимо — цель задачи 4.
      final alone = sim.run(PlayStyle.tryhard.withPrestige(null),
          horizon: const Duration(hours: 4));
      final tab = overnightThreshold(sim, PlayStyle.tryhard, Absence.tabOpen);

      // Ночь закрытой игры мудрости не приносит вовсе: производства нет,
      // только поток.
      expect(alone.firstPrestige, isNotNull);
      expect(tab, lessThan(alone.firstPrestige!));

      final probe = leaveAfter(sim, PlayStyle.tryhard,
          playFor: tab, awayFor: night, how: Absence.tabOpen);
      expect(probe.finalState.prestige.potentialWisdom, greaterThan(0),
          reason: 'порог найден, а мудрости после ночи нет');
      if (tab > Duration.zero) {
        final short = leaveAfter(sim, PlayStyle.tryhard,
            playFor: tab - minute, awayFor: night, how: Absence.tabOpen);
        expect(short.finalState.prestige.potentialWisdom, 0,
            reason: 'минутой меньше — и мудрость всё ещё есть: порог не наименьший');
      }
    });

    test('сутки вкладки стоят больше игры, чем сутки закрытой', () {
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 10));
      final closed = activeEquivalent(sim, p, const Duration(days: 1), Absence.closed);
      final tab = activeEquivalent(sim, p, const Duration(days: 1), Absence.tabOpen);
      expect(closed, isNotNull);
      expect(tab, isNotNull);
      expect(tab!, greaterThan(closed!));
    });
  });

  group('Гости', () {
    // Партия на полчаса: есть производство, и игрок хочет что-то купить.
    // Часы партии начинаются в полночь, поэтому гость приходит на её
    // 0-й, 10-й, 20-й… минуте — так же, как в игре, в ровные минуты.
    late SimParty base;
    setUpAll(() {
      base = sim.start(PlayStyle.tryhard.withPrestige(null));
      sim.play(base, const Duration(minutes: 30));
    });

    /// Партия [style] на отметке [clock], с баком, налитым на [tank], без
    /// денег (значит, хочется продать) и сортом [sort].
    SimParty at(PlayStyle style, Duration clock, {double tank = 0.5, int sort = 4}) {
      final p = base.fork(style: style.withPrestige(null))..elapsed = clock;
      final s = p.state;
      p.state = s.copyWith(
        resources: s.resources.copyWith(ml: s.tankCapacity * tank, money: 0),
        sort: SortState(index: sort),
      );
      return p;
    }

    /// Начало ближайшего окна после получаса партии, в котором гость
    /// берёт не только высший сорт: иначе «недоросший» сорт не проверить.
    Duration lowGuestSlot() {
      for (var slot = 3;; slot++) {
        final start = kEventPeriod * slot;
        if (eventAt(base.origin.add(start))!.event.minSortIndex < kSorts.length - 1) return start;
      }
    }

    bool isGuest(Buyer? b) => b != null && !kBuyers.any((k) => k.id == b.id);

    test('«считает» сдаёт гостю, когда тот на месте', () {
      final p = at(PlayStyle.tryhard, const Duration(minutes: 31));
      expect(eventAt(p.now), isNotNull);
      expect(isGuest(sim.buyerNow(p)), isTrue);
    });

    test('«считает» ждёт гостя, если бак не переполнится до его прихода', () {
      // За 10 секунд до прихода бак на 10 % точно не нальётся.
      final p = at(PlayStyle.tryhard, const Duration(minutes: 39, seconds: 50), tank: 0.1);
      expect(eventAt(p.now), isNull);
      expect(sim.buyerNow(p), isNull);
    });

    test('«считает» не ждёт, если бак переполнится раньше', () {
      final p = at(PlayStyle.tryhard, const Duration(minutes: 35, seconds: 1), tank: 0.96);
      expect(eventAt(p.now), isNull);
      expect(sim.buyerNow(p), same(kBuyers.first));
    });

    test('«считает» даёт сорту дорасти, а уходящему гостю сдаёт как есть', () {
      // Сделка с гостем роняет сорт на ступень. Сдавать каждую секунду —
      // съехать до первача, поэтому между сделками он ждёт сорт.
      final slot = lowGuestSlot();
      final need = eventAt(base.origin.add(slot))!.event.minSortIndex;
      final early = at(PlayStyle.tryhard, slot + const Duration(minutes: 1), sort: need);
      expect(sim.buyerNow(early), isNull);

      final leaving = at(PlayStyle.tryhard, slot + kEventWindow - const Duration(seconds: 1), sort: need);
      expect(isGuest(sim.buyerNow(leaving)), isTrue);
    });

    test('«обычный» замечает гостя в доле продаж, равной вниманию', () {
      final p = at(PlayStyle.casual, const Duration(minutes: 31));
      var guests = 0;
      for (var i = 0; i < 10; i++) {
        if (isGuest(sim.buyerNow(p))) guests++;
      }
      expect(guests, (10 * PlayStyle.casual.attention).round());
    });

    test('«обычный» гостя не ждёт', () {
      final p = at(PlayStyle.casual, const Duration(minutes: 39, seconds: 50), tank: 0.1);
      expect(sim.buyerNow(p), same(kBuyers.first));
    });

    test('без гостей — только Петрович', () {
      final p = at(PlayStyle.tryhard.withoutGuests, const Duration(minutes: 31));
      expect(sim.buyerNow(p), same(kBuyers.first));
    });

    test('автопродажа сдаёт только Петровичу, как в игре', () {
      final p = base.fork();
      expect(p.state.achievements.hasPerk(AchievementPerk.autoSell), isTrue);
      final guestSales = p.state.stats.guestSales;
      sim.away(p, const Duration(hours: 1), Absence.tabOpen);
      expect(p.sales, greaterThan(base.sales), reason: 'автопродажа не сработала');
      expect(p.state.stats.guestSales, guestSales);
    });

    test('гости ускоряют того, кто их ждёт', () {
      const hour = Duration(hours: 1);
      final withGuests = sim.run(PlayStyle.tryhard.withPrestige(null), horizon: hour);
      final without = sim.run(PlayStyle.tryhard.withoutGuests.withPrestige(null), horizon: hour);
      expect(withGuests.finalState.stats.guestSales, greaterThan(0));
      expect(without.finalState.stats.guestSales, 0);
      expect(withGuests.finalState.prestige.totalEverEarned,
          greaterThan(without.finalState.prestige.totalEverEarned));
    });
  });

  group('Правило похмелья: прибавка окупает заход', () {
    const rule = PaybackRule();

    GameState withHistory(double lifetime, {double claimed = 0}) =>
        GameState.initial(
          initialGenerators: kGenerators,
          initialUpgrades: kUpgrades,
          prestige: PrestigeState(totalEverEarned: lifetime, claimedMl: claimed),
          lastUpdateTime: DateTime.utc(2026),
        );

    test('без мудрости к забору не ложится', () {
      final s = withHistory(PrestigeState.firstWisdomMl * 0.5);
      expect(rule.shouldPrestige(s, runSeconds: 3600, rate: 1), isFalse);
    });

    test('ложится, когда следующей мудрости не дождаться', () {
      final s = withHistory(PrestigeState.firstWisdomMl * 1.5);
      expect(rule.shouldPrestige(s, runSeconds: 3600, rate: 0), isTrue);
    });

    test('ждёт, когда следующая мудрость вот-вот', () {
      final s = withHistory(PrestigeState.firstWisdomMl * 2.9);
      final rate = PrestigeState.firstWisdomMl; // до 3.0 — десятая доля секунды
      expect(rule.shouldPrestige(s, runSeconds: 3600, rate: rate), isFalse);
    });

    test('длинная партия с похмельями: заходы складываются в партию', () {
      final m = marathon(sim, PlayStyle.tryhard, horizon: const Duration(hours: 3));
      final r = m.result;
      expect(r.prestiges, greaterThan(0), reason: 'за три часа ни разу не лёг');
      expect(m.runs, hasLength(r.prestiges));
      expect(m.runs.reduce((a, b) => a + b), r.hangovers.last);
      expect(m.runs.every((d) => d > Duration.zero), isTrue);
    });
  });

  test('старое правило не потерялось — для сверки', () {
    // Сверка с числами, снятыми до смены правила, идёт через него: если
    // «считает» на старом правиле ляжет не при первой возможности, сверять
    // станет не с чем.
    // Горизонт — из целей, а не число: первая мудрость переехала с 37-й
    // минуты на 2,5 часа, и прежний час отсюда её уже не видел.
    final p = sim.start(PlayStyle.tryhard.onLegacyRule);
    sim.play(p, BalanceTargets.firstWisdomMax, until: (p) => p.hangovers.isNotEmpty);
    final r = p.result;
    expect(r.firstPrestige, isNotNull);
    expect(r.hangovers.first, r.firstPrestige);
  });
}
