/// Контент игры как ДАННЫЕ.
///
/// Объёмы — в миллилитрах, цены — в рублях. Разделение важно: самогон это
/// товар, рубли это деньги, и покупается всё именно за деньги.
///
/// Ни одно число отсюда не зашито в виджеты — баланс правится здесь, без
/// касания кода интерфейса и движка.
///
/// Между тирами примерно ×12 по цене и ×6–7 по выходу. Скорость удорожания
/// внутри тира — общая для всех и лежит в `Balance.costGrowth`: это главный
/// тормоз экономики, и место ему одно.
library;

import 'dart:math' as math;

import 'balance.dart';
import '../models/generator.dart';
import '../models/upgrade.dart';

/// Сколько всего ступеней в лестнице.
int get kGeneratorCount => kGeneratorNames.length;

/// Имена лестницы. Числа к ним считаются из баланса — см. [kGenerators].
const List<({String id, String name})> kGeneratorNames = [
  (id: 'banka', name: 'Трёхлитровая банка'),
  (id: 'bidon', name: 'Бидон эмалированный'),
  (id: 'flyaga', name: 'Фляга армейская'),
  (id: 'dedov', name: 'Аппарат «Дедов»'),
  (id: 'zmeevik', name: 'Медный змеевик'),
  (id: 'tseh', name: 'Гаражный цех'),
  (id: 'podval', name: 'Подвал у Петровича'),
  (id: 'tsisterna', name: 'Цистерна «МОЛОКО»'),
  (id: 'druzhba', name: 'Трубопровод «Дружба-2»'),
  (id: 'zavod', name: 'Завод «Кристалл-Витя»'),
  (id: 'tanker', name: 'Танкер «Первач»'),
  (id: 'orbita', name: 'Орбитальная «Мир-2»'),
  (id: 'collider', name: 'Самогонный коллайдер'),
];

/// Лестница Вити: от банки на кухне до коллайдера на орбите.
///
/// Цены и выходы НЕ записаны руками, а строятся геометрической прогрессией из
/// [Balance]. Так было и раньше — просто вручную: тринадцать цен подряд шли с
/// одинаковым отношением ×12.3, тринадцать выходов — с ×6.05. Держать это
/// руками значило править двадцать шесть чисел ради одной правки баланса, а
/// симулятор не мог перебрать варианты вовсе.
///
/// Отношение «дороже / продуктивнее» (12.3 против 6.05) — и есть тормоз игры:
/// каждая следующая ступень вдвое невыгоднее предыдущей, поэтому её надо
/// заслужить, а не просто дождаться.
List<Generator> get kGenerators {
  final b = Balance.current;
  if (identical(_ladderFor, b)) return _ladder!;
  _ladder = [
    for (var i = 0; i < kGeneratorNames.length; i++)
      Generator(
        id: kGeneratorNames[i].id,
        name: kGeneratorNames[i].name,
        baseCost: b.firstGeneratorCost * math.pow(b.tierCostRatio, i),
        baseProduction: b.firstGeneratorOutput * math.pow(b.tierOutputRatio, i),
      ),
  ];
  _ladderFor = b;
  return _ladder!;
}

/// Лестница пересобирается только при смене баланса: в игре это ноль раз,
/// в симуляторе — на каждый вариант. Без памятки каждый вызов создавал бы
/// тринадцать объектов, а зовут его на каждом кадре.
List<Generator>? _ladder;
Balance? _ladderFor;

/// Улучшения, разложенные по четырём осям.
///
/// Раньше почти все делали одно и то же — множили выход, — и выбор сводился к
/// «купи что подешевле». Теперь оси разные и конкурируют между собой:
///   • объём   — аппараты производят больше
///   • цена    — качество поднимает рубли за литр
///   • ёмкость — бак вмещает больше, реже стоит простой
///   • руки    — отдача за нажатие
///
/// Описания сухие, как патчноут: смешно от формулировки, а не оттого, что
/// шутку объяснили.
const List<Upgrade> kUpgrades = [
  // --- Руки ---
  Upgrade(
    id: 'tap_ruka',
    name: 'Крепкая рука',
    description: 'Ручная отдача ×2',
    cost: 40,
    target: UpgradeTarget.tapPower,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tap_mozol',
    name: 'Трудовая мозоль',
    description: 'Ручная отдача ×2',
    cost: 1200,
    target: UpgradeTarget.tapPower,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tap_hvatka',
    name: 'Дедовская хватка',
    description: 'Ручная отдача ×3',
    cost: 30000,
    target: UpgradeTarget.tapPower,
    multiplier: 3,
  ),

  // --- Ёмкость бака ---
  Upgrade(
    id: 'tank_kanistra',
    name: 'Вторая канистра',
    description: 'Запас бака ×2',
    cost: 200,
    target: UpgradeTarget.tankCapacity,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tank_bidon',
    name: 'Бидон под слив',
    description: 'Запас бака ×3',
    cost: 9000,
    target: UpgradeTarget.tankCapacity,
    multiplier: 3,
  ),
  Upgrade(
    id: 'tank_tsisterna',
    name: 'Списанная цистерна',
    description: 'Запас бака ×4',
    cost: 900000,
    target: UpgradeTarget.tankCapacity,
    multiplier: 4,
  ),
  Upgrade(
    id: 'tank_rezervuar',
    name: 'Подземный резервуар',
    description: 'Запас бака ×5',
    cost: 60000000,
    target: UpgradeTarget.tankCapacity,
    multiplier: 5,
  ),

  // --- Качество: поднимает цену за литр ---
  Upgrade(
    id: 'q_peregonka',
    name: 'Двойная перегонка',
    description: 'Цена за литр ×1.4',
    cost: 3000,
    target: UpgradeTarget.quality,
    multiplier: 1.4,
  ),
  Upgrade(
    id: 'q_filtr',
    name: 'Угольный фильтр из противогаза',
    description: 'Цена за литр ×1.5',
    cost: 45000,
    target: UpgradeTarget.quality,
    multiplier: 1.5,
  ),
  Upgrade(
    id: 'q_hvosty',
    name: 'Отсекать хвосты',
    description: 'Цена за литр ×1.6',
    cost: 700000,
    target: UpgradeTarget.quality,
    multiplier: 1.6,
  ),
  Upgrade(
    id: 'q_kedr',
    name: 'Настойка на кедровых орешках',
    description: 'Цена за литр ×1.8',
    cost: 20000000,
    target: UpgradeTarget.quality,
    multiplier: 1.8,
  ),

  // --- Отдельные аппараты ---
  Upgrade(
    id: 'g_drozhzhi',
    name: 'Дрожжи бабы Нюры',
    description: 'Банка ×2',
    cost: 80,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'banka',
    multiplier: 2,
  ),
  Upgrade(
    id: 'g_sahar',
    name: 'Сахар с оптовой базы',
    description: 'Бидон ×2',
    cost: 600,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'bidon',
    multiplier: 2,
  ),
  Upgrade(
    id: 'g_bak',
    name: 'Медный бак',
    description: 'Фляга ×2',
    cost: 7000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'flyaga',
    multiplier: 2,
  ),
  Upgrade(
    id: 'g_termometr',
    name: 'Термометр (наконец-то)',
    description: 'Аппарат «Дедов» ×2',
    cost: 90000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'dedov',
    multiplier: 2,
  ),
  Upgrade(
    id: 'g_ohlazhdenie',
    name: 'Проточное охлаждение',
    description: 'Медный змеевик ×2',
    cost: 1100000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'zmeevik',
    multiplier: 2,
  ),
  Upgrade(
    id: 'g_smena',
    name: 'Сменный мастер',
    description: 'Гаражный цех ×2',
    cost: 13000000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'tseh',
    multiplier: 2,
  ),

  // --- Все аппараты сразу ---
  Upgrade(
    id: 'all_recept',
    name: 'Рецепт прадеда',
    description: 'Все аппараты +50%',
    cost: 40000,
    target: UpgradeTarget.allGenerators,
    multiplier: 1.5,
  ),
  Upgrade(
    id: 'all_nochnaya',
    name: 'Ночная смена',
    description: 'Все аппараты ×2',
    cost: 5000000,
    target: UpgradeTarget.allGenerators,
    multiplier: 2,
  ),

  // --- Синергии: связки, а не плоские множители ---
  Upgrade(
    id: 'syn_nastavnik',
    name: 'Наставник Петрович',
    description: 'Аппарат «Дедов» +1% за каждую банку',
    cost: 70000,
    target: UpgradeTarget.synergyCoupling,
    multiplier: 1,
  ),
  Upgrade(
    id: 'syn_podryad',
    name: 'Семейный подряд',
    description: 'Каждый аппарат от 25 штук: +10% ко всем',
    cost: 300000,
    target: UpgradeTarget.synergyResonance,
    multiplier: 1,
  ),
];
