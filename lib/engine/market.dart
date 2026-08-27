import 'dart:math' as math;

import '../models/upgrade.dart';
import '../models/upgrades_state.dart';

/// Рынок самогона: по какой цене Витя сдаёт товар.
///
/// Цена — **чистая функция времени и улучшений**. Это не украшение, а
/// требование: оффлайн-доход и обычная игра считаются одной формулой, и если
/// бы цена зависела от случайности или от внутреннего состояния, они бы
/// разошлись, а игрок ловил бы разные суммы за одно и то же.
class Market {
  const Market._();

  /// Базовая цена: 100 ₽ за литр, то есть 0.1 ₽ за миллилитр.
  static const double basePricePerMl = 0.1;

  /// Насколько сильно рынок ходит вверх-вниз.
  static const double swing = 0.35;

  /// Полный оборот медленной волны — около десяти минут.
  static const double _slowPeriodSeconds = 615;

  /// Быстрая рябь поверх неё — около полутора минут.
  static const double _fastPeriodSeconds = 97;

  /// Множитель рынка в момент [now]: гуляет в пределах 1 ± [swing].
  ///
  /// Две волны с некратными периодами: движение не выглядит механическим,
  /// но остаётся предсказуемым и одинаковым на любом устройстве.
  static double wave(DateTime now) {
    final t = now.toUtc().millisecondsSinceEpoch / 1000.0;
    final slow = math.sin(2 * math.pi * t / _slowPeriodSeconds);
    final fast = math.sin(2 * math.pi * t / _fastPeriodSeconds + 1.7);
    return 1.0 + swing * (slow * 0.72 + fast * 0.28);
  }

  /// Надбавка за качество: чистота и крепость поднимают цену за литр.
  ///
  /// Раньше все улучшения делали одно и то же — умножали выход. Теперь у них
  /// разные оси, и «Двойная перегонка» отвечает именно за цену.
  static double qualityMultiplier(UpgradesState ups) => ups.items
      .where((u) => u.purchased && u.target == UpgradeTarget.quality)
      .fold(1.0, (product, u) => product * u.multiplier);

  /// Итоговая цена за миллилитр прямо сейчас.
  static double pricePerMl(DateTime now, UpgradesState ups) =>
      basePricePerMl * qualityMultiplier(ups) * wave(now);

  /// Сколько дадут за литр — то, что видит игрок.
  static double pricePerLitre(DateTime now, UpgradesState ups) =>
      pricePerMl(now, ups) * 1000;

  /// Насколько рынок отклонился от обычного: 1.0 — норма, 1.3 — выгодно.
  static double relative(DateTime now) => wave(now);

  /// Стоит ли подсветить кнопку продажи: рынок заметно выше среднего.
  static bool isGoodMoment(DateTime now) => wave(now) >= 1.0 + swing * 0.45;
}
