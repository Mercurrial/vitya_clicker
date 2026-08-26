/// Контент игры как ДАННЫЕ.
///
/// Объёмы — в миллилитрах, цены — в рублях. Разделение важно: самогон это
/// товар, рубли это деньги, и покупается всё именно за деньги.
///
/// Ни одно число отсюда не зашито в виджеты — баланс правится здесь, без
/// касания кода интерфейса и движка.
///
/// Между тирами примерно ×12 по цене и ×6–7 по выходу; рост цены внутри тира
/// (1.10) ниже классического 1.15 — это удлиняет участок разгона и даёт
/// ощущение «ускоряется», а не «вязнет».
library;

import '../models/generator.dart';
import '../models/upgrade.dart';

/// Рост цены за каждую купленную штуку.
const double kCostGrowth = 1.10;

/// Плоская отдача за нажатие в самом начале, мл.
///
/// Работает только пока аппаратов нет: дальше нажатие считается как доля
/// секунды производства и растёт само (см. `GameState.tapYield`).
const double kBaseTapMl = 5.0;

/// Лестница Вити: от банки на кухне до коллайдера на орбите.
///
/// `baseProduction` — миллилитры в секунду, `baseCost` — рубли.
const List<Generator> kGenerators = [
  Generator(
    id: 'banka',
    name: 'Трёхлитровая банка',
    baseCost: 15,
    costGrowthFactor: kCostGrowth,
    baseProduction: 1,
  ),
  Generator(
    id: 'bidon',
    name: 'Бидон эмалированный',
    baseCost: 60,
    costGrowthFactor: kCostGrowth,
    baseProduction: 8,
  ),
  Generator(
    id: 'flyaga',
    name: 'Фляга армейская',
    baseCost: 700,
    costGrowthFactor: kCostGrowth,
    baseProduction: 50,
  ),
  Generator(
    id: 'dedov',
    name: 'Аппарат «Дедов»',
    baseCost: 9000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 300,
  ),
  Generator(
    id: 'zmeevik',
    name: 'Медный змеевик',
    baseCost: 110000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 1800,
  ),
  Generator(
    id: 'tseh',
    name: 'Гаражный цех',
    baseCost: 1300000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 11000,
  ),
  Generator(
    id: 'podval',
    name: 'Подвал у Петровича',
    baseCost: 16000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 65000,
  ),
  Generator(
    id: 'tsisterna',
    name: 'Цистерна «МОЛОКО»',
    baseCost: 200000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 400000,
  ),
  Generator(
    id: 'druzhba',
    name: 'Трубопровод «Дружба-2»',
    baseCost: 2500000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 2400000,
  ),
  Generator(
    id: 'zavod',
    name: 'Завод «Кристалл-Витя»',
    baseCost: 30000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 15000000,
  ),
  Generator(
    id: 'tanker',
    name: 'Танкер «Первач»',
    baseCost: 400000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 90000000,
  ),
  Generator(
    id: 'orbita',
    name: 'Орбитальная «Мир-2»',
    baseCost: 5000000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 550000000,
  ),
  Generator(
    id: 'collider',
    name: 'Самогонный коллайдер',
    baseCost: 60000000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 3300000000,
  ),
];

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
    description: 'Бак ×2',
    cost: 200,
    target: UpgradeTarget.tankCapacity,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tank_bidon',
    name: 'Бидон под слив',
    description: 'Бак ×3',
    cost: 9000,
    target: UpgradeTarget.tankCapacity,
    multiplier: 3,
  ),
  Upgrade(
    id: 'tank_tsisterna',
    name: 'Списанная цистерна',
    description: 'Бак ×4',
    cost: 900000,
    target: UpgradeTarget.tankCapacity,
    multiplier: 4,
  ),
  Upgrade(
    id: 'tank_rezervuar',
    name: 'Подземный резервуар',
    description: 'Бак ×5',
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
