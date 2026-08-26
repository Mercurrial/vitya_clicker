/// Контент игры как ДАННЫЕ.
///
/// Все объёмы — в МИЛЛИЛИТРАХ. Единица мелкая намеренно: Витя начинает с
/// капель («50 мл»), а не сразу с литров, и переход на литры сам по себе
/// ощущается достижением.
///
/// Ни одно число отсюда не зашито в виджеты — баланс правится здесь, без
/// касания кода интерфейса и движка.
///
/// Между тирами примерно ×12 по цене и ×6–7 по доходу; рост цены внутри тира
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
const List<Generator> kGenerators = [
  Generator(
    id: 'banka',
    name: 'Трёхлитровая банка',
    baseCost: 50,
    costGrowthFactor: kCostGrowth,
    baseProduction: 1,
  ),
  Generator(
    id: 'bidon',
    name: 'Бидон эмалированный',
    baseCost: 600,
    costGrowthFactor: kCostGrowth,
    baseProduction: 8,
  ),
  Generator(
    id: 'flyaga',
    name: 'Фляга армейская',
    baseCost: 7000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 50,
  ),
  Generator(
    id: 'dedov',
    name: 'Аппарат «Дедов»',
    baseCost: 90000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 300,
  ),
  Generator(
    id: 'zmeevik',
    name: 'Медный змеевик',
    baseCost: 1100000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 1800,
  ),
  Generator(
    id: 'tseh',
    name: 'Гаражный цех',
    baseCost: 13000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 11000,
  ),
  Generator(
    id: 'podval',
    name: 'Подвал у Петровича',
    baseCost: 160000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 65000,
  ),
  Generator(
    id: 'tsisterna',
    name: 'Цистерна «МОЛОКО»',
    baseCost: 2000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 400000,
  ),
  Generator(
    id: 'druzhba',
    name: 'Трубопровод «Дружба-2»',
    baseCost: 25000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 2400000,
  ),
  Generator(
    id: 'zavod',
    name: 'Завод «Кристалл-Витя»',
    baseCost: 300000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 15000000,
  ),
  Generator(
    id: 'tanker',
    name: 'Танкер «Первач»',
    baseCost: 4000000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 90000000,
  ),
  Generator(
    id: 'orbita',
    name: 'Орбитальная «Мир-2»',
    baseCost: 50000000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 550000000,
  ),
  Generator(
    id: 'collider',
    name: 'Самогонный коллайдер',
    baseCost: 600000000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 3300000000,
  ),
];

/// Апгрейды. Порядок в списке = порядок показа.
///
/// Описания — «как патчноут», без прилагательных и восклицаний: смешно от
/// сухости формулировки, а не от того, что шутку объяснили.
const List<Upgrade> kUpgrades = [
  // --- Ручная работа ---
  Upgrade(
    id: 'tap_ruka',
    name: 'Крепкая рука',
    description: 'Ручная отдача ×2',
    cost: 400,
    target: UpgradeTarget.tapPower,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tap_mozol',
    name: 'Трудовая мозоль',
    description: 'Ручная отдача ×2',
    cost: 12000,
    target: UpgradeTarget.tapPower,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tap_hvatka',
    name: 'Дедовская хватка',
    description: 'Ручная отдача ×3',
    cost: 300000,
    target: UpgradeTarget.tapPower,
    multiplier: 3,
  ),

  // --- Персональные ---
  Upgrade(
    id: 'drozhzhi',
    name: 'Дрожжи бабы Нюры',
    description: 'Банка ×2',
    cost: 800,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'banka',
    multiplier: 2,
  ),
  Upgrade(
    id: 'sahar',
    name: 'Сахар с оптовой базы',
    description: 'Бидон ×2',
    cost: 6000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'bidon',
    multiplier: 2,
  ),
  Upgrade(
    id: 'peregonka',
    name: 'Двойная перегонка',
    description: 'Фляга ×2',
    cost: 70000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'flyaga',
    multiplier: 2,
  ),
  Upgrade(
    id: 'termometr',
    name: 'Термометр (наконец-то)',
    description: 'Аппарат «Дедов» ×2',
    cost: 900000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'dedov',
    multiplier: 2,
  ),
  Upgrade(
    id: 'filtr',
    name: 'Угольный фильтр из противогаза',
    description: 'Медный змеевик ×2',
    cost: 11000000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'zmeevik',
    multiplier: 2,
  ),
  Upgrade(
    id: 'hvosty',
    name: 'Отсекать хвосты',
    description: 'Гаражный цех ×2',
    cost: 130000000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'tseh',
    multiplier: 2,
  ),

  // --- Глобальные ---
  Upgrade(
    id: 'recept',
    name: 'Рецепт прадеда',
    description: 'Все аппараты +50%',
    cost: 400000,
    target: UpgradeTarget.allGenerators,
    multiplier: 1.5,
  ),
  Upgrade(
    id: 'nochnaya',
    name: 'Ночная смена',
    description: 'Все аппараты ×2',
    cost: 50000000,
    target: UpgradeTarget.allGenerators,
    multiplier: 2,
  ),

  // --- Синергии: связки, а не плоские множители ---
  Upgrade(
    id: 'nastavnik',
    name: 'Наставник Петрович',
    description: 'Аппарат «Дедов» +1% за каждую банку',
    cost: 700000,
    target: UpgradeTarget.synergyCoupling,
    multiplier: 1,
  ),
  Upgrade(
    id: 'podryad',
    name: 'Семейный подряд',
    description: 'Каждый аппарат от 25 штук: +10% ко всем',
    cost: 3000000,
    target: UpgradeTarget.synergyResonance,
    multiplier: 1,
  ),
];
