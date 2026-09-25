import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/models/achievement.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/sim/balance_sim.dart';
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
    test('наливает не больше бака', () {
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 20));
      final lifetime = p.state.prestige.totalEverEarned;
      final room = p.state.tankCapacity - p.state.resources.ml;

      sim.away(p, night, Absence.closed);
      expect(
        p.state.prestige.totalEverEarned - lifetime,
        lessThanOrEqualTo(room + 1e-6),
        reason: 'закрытая игра гонит мимо бака — значит, сломан оффлайн',
      );
    });

    test('сутки дают не больше потолка оффлайна', () {
      final p = sim.start(PlayStyle.tryhard);
      sim.play(p, const Duration(minutes: 20));
      final eight = p.fork(), day = p.fork();
      sim.away(eight, night, Absence.closed);
      sim.away(day, const Duration(days: 1), Absence.closed);
      expect(day.state.prestige.totalEverEarned,
          eight.state.prestige.totalEverEarned);
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

    test('с автопродажей гонит всю ночь, а закрытая игра — один бак', () {
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
      final closed = overnightThreshold(sim, PlayStyle.tryhard, Absence.closed);
      final tab = overnightThreshold(sim, PlayStyle.tryhard, Absence.tabOpen);

      expect(alone.firstPrestige, isNotNull);
      expect(closed, lessThanOrEqualTo(alone.firstPrestige!));
      expect(tab, lessThanOrEqualTo(closed));

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
    final r = sim.run(PlayStyle.tryhard.onLegacyRule, horizon: const Duration(hours: 1));
    expect(r.firstPrestige, isNotNull);
    expect(r.hangovers.first, r.firstPrestige);
  });
}
