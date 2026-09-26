/// Вехи мудрости — «магазин мудрости» без траты.
///
/// Мудрость не тратится: каждая N-я сама открывает постоянный бонус
/// (docs/DECISIONS.md, «Экономика и мудрость»). У всех один путь, зато нет
/// ни долга, ни новых ключей в сейве. Магазин с тратой пришлось бы чинить
/// при каждой правке баланса: правка может опустить заработанную мудрость
/// ниже потраченной, и тогда нужен либо долг, либо подарок разницы.
///
/// ## Почему вехи не хранятся
///
/// Взятые вехи — вывод, а не факт: они считаются из мудрости, а мудрость —
/// из `claimedMl` и `bonusWisdom` по текущему балансу. Поправили порог или
/// список — у всех пересчиталось само, как и мудрость. Хранить их значило бы
/// снова завести в сейве число от старой формулы, которое потом пришлось бы
/// переводить миграцией.
///
/// ## Почему эффекты — перечислимые типы
///
/// Вехи — данные с пометкой мира ([World]). Следующий мир (docs/PLAN-1.0.md,
/// раздел 7) заведёт свой список на тех же типах, и движок уже умеет их
/// применять. Произвольный код в вехе пришлось бы переписывать под каждый
/// мир.
///
/// Эффекты — только то, что в игре уже есть: релиз новых механик не
/// добавляет.
///
/// Числа вех — в `kBalance`, рядом с остальными числами экономики: правка
/// вехи — правка баланса, и отпечаток в `test/release_contract_test.dart`
/// её видит.
library;

import '../models/upgrade.dart' show UpgradeTarget;

/// Мир, по которому идёт дорожка вех.
///
/// Пока мир один. Переход в новый мир сбросит гараж вместе с мудростью, а
/// значит, и с вехами; у нового мира будет своя дорожка.
enum World { garage }

/// Что даёт веха.
sealed class MilestoneEffect {
  const MilestoneEffect();
}

/// Одна ступень лестницы гонит в [factor] раз больше.
final class StillBoost extends MilestoneEffect {
  final String generatorId;
  final double factor;
  const StillBoost(this.generatorId, this.factor);

  @override
  String toString() => 'still:$generatorId×$factor';
}

/// Всё производство ×[factor] — сверх множителя самой мудрости.
final class AllBoost extends MilestoneEffect {
  final double factor;
  const AllBoost(this.factor);

  @override
  String toString() => 'all×$factor';
}

/// Заход после похмелья начинается с [money] рублей в кассе.
///
/// Первые минуты каждого захода — одни и те же покупки по кругу. Деньги, а
/// не готовые аппараты: что на них взять, игрок решает сам.
final class RunStart extends MilestoneEffect {
  final double money;
  const RunStart(this.money);

  @override
  String toString() => 'start:$money';
}

/// Купленные улучшения с целью [target] переживают похмелье.
final class KeepUpgrades extends MilestoneEffect {
  final UpgradeTarget target;
  const KeepUpgrades(this.target);

  @override
  String toString() => 'keep:${target.name}';
}

/// Сорт растёт в [factor] раз быстрее, пока жар в окне.
///
/// Награда тому, кто держит жар: сорт поднимает цену за литр, а растёт
/// только под пальцем.
final class SortSpeed extends MilestoneEffect {
  final double factor;
  const SortSpeed(this.factor);

  @override
  String toString() => 'sort×$factor';
}

/// Гости платят в [factor] раз больше.
final class GuestPay extends MilestoneEffect {
  final double factor;
  const GuestPay(this.factor);

  @override
  String toString() => 'guests×$factor';
}

/// Веха: на какой мудрости какого мира что открывается.
class WisdomMilestone {
  final World world;
  final int wisdom;
  final MilestoneEffect effect;

  const WisdomMilestone(this.world, this.wisdom, this.effect);

  @override
  String toString() => '${world.name}@$wisdom:$effect';
}

/// Всё, что дают взятые вехи, сложенное вместе.
///
/// Одинаковые эффекты перемножаются: две вехи «банка ×2» — это банка ×4.
class MilestoneBonuses {
  /// Множители ступеней по id аппарата. Нет в таблице — ×1.
  final Map<String, double> stills;

  /// Множитель всего производства.
  final double all;

  /// С чем начинается заход после похмелья, ₽. Не складывается, а берётся
  /// наибольшее: вехи старта — ступеньки, а не надбавки.
  final double startMoney;

  /// Какие улучшения переживают похмелье.
  final Set<UpgradeTarget> kept;

  final double sortSpeed;
  final double guestPay;

  const MilestoneBonuses({
    this.stills = const {},
    this.all = 1.0,
    this.startMoney = 0.0,
    this.kept = const {},
    this.sortSpeed = 1.0,
    this.guestPay = 1.0,
  });

  static const none = MilestoneBonuses();

  factory MilestoneBonuses.of(Iterable<WisdomMilestone> taken) {
    final stills = <String, double>{};
    var all = 1.0, start = 0.0, sort = 1.0, guests = 1.0;
    final kept = <UpgradeTarget>{};
    for (final m in taken) {
      switch (m.effect) {
        case StillBoost(:final generatorId, :final factor):
          stills[generatorId] = (stills[generatorId] ?? 1.0) * factor;
        case AllBoost(:final factor):
          all *= factor;
        case RunStart(:final money):
          if (money > start) start = money;
        case KeepUpgrades(:final target):
          kept.add(target);
        case SortSpeed(:final factor):
          sort *= factor;
        case GuestPay(:final factor):
          guests *= factor;
      }
    }
    return MilestoneBonuses(
      stills: Map.unmodifiable(stills),
      all: all,
      startMoney: start,
      kept: Set.unmodifiable(kept),
      sortSpeed: sort,
      guestPay: guests,
    );
  }

  /// Множитель одной ступени.
  double still(String generatorId) => stills[generatorId] ?? 1.0;
}
