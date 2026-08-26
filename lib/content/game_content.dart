/// Контент игры как ДАННЫЕ.
///
/// Ни одно число отсюда не зашито в виджеты — баланс правится здесь, без
/// касания кода интерфейса и движка.
///
/// Соотношения цены/дохода между тирами взяты от проверенных временем
/// инкрементальных игр (~×10 цена, ~×8 доход за тир); множитель роста цены
/// внутри тира ниже классического (1.10 против 1.15) — это удлиняет участок
/// разгона и даёт то самое ощущение «ускоряется, а не вязнет».
library;

import '../models/generator.dart';
import '../models/upgrade.dart';

/// Рост цены за каждую купленную штуку.
const double kCostGrowth = 1.10;

/// Базовая сила тапа (литров за нажатие).
const double kBaseTapPower = 1.0;

/// Лестница Вити: от банки на кухне до коллайдера на орбите.
const List<Generator> kGenerators = [
  Generator(
    id: 'banka',
    name: 'Трёхлитровая банка',
    baseCost: 15,
    costGrowthFactor: kCostGrowth,
    baseProduction: 0.1,
  ),
  Generator(
    id: 'bidon',
    name: 'Бидон эмалированный',
    baseCost: 100,
    costGrowthFactor: kCostGrowth,
    baseProduction: 1,
  ),
  Generator(
    id: 'flyaga',
    name: 'Фляга армейская',
    baseCost: 1100,
    costGrowthFactor: kCostGrowth,
    baseProduction: 8,
  ),
  Generator(
    id: 'dedov',
    name: 'Аппарат «Дедов»',
    baseCost: 12000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 47,
  ),
  Generator(
    id: 'zmeevik',
    name: 'Медный змеевик',
    baseCost: 130000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 260,
  ),
  Generator(
    id: 'tseh',
    name: 'Гаражный цех',
    baseCost: 1400000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 1400,
  ),
  Generator(
    id: 'podval',
    name: 'Подвал у Петровича',
    baseCost: 20000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 7800,
  ),
  Generator(
    id: 'tsisterna',
    name: 'Цистерна «МОЛОКО»',
    baseCost: 330000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 44000,
  ),
  Generator(
    id: 'druzhba',
    name: 'Трубопровод «Дружба-2»',
    baseCost: 5100000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 260000,
  ),
  Generator(
    id: 'zavod',
    name: 'Завод «Кристалл-Витя»',
    baseCost: 75000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 1600000,
  ),
  Generator(
    id: 'tanker',
    name: 'Танкер «Первач»',
    baseCost: 1000000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 10000000,
  ),
  Generator(
    id: 'orbita',
    name: 'Орбитальная «Мир-2»',
    baseCost: 14000000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 65000000,
  ),
  Generator(
    id: 'collider',
    name: 'Самогонный коллайдер',
    baseCost: 170000000000000,
    costGrowthFactor: kCostGrowth,
    baseProduction: 430000000,
  ),
];

/// Апгрейды. Порядок в списке = порядок показа.
///
/// Описания — «как патчноут», без прилагательных и восклицаний: смешно от
/// сухости формулировки, а не от того, что шутку объяснили.
const List<Upgrade> kUpgrades = [
  // --- Сила тапа ---
  Upgrade(
    id: 'tap_ruka',
    name: 'Крепкая рука',
    description: 'За тап ×2',
    cost: 100,
    target: UpgradeTarget.tapPower,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tap_mozol',
    name: 'Трудовая мозоль',
    description: 'За тап ×2',
    cost: 2500,
    target: UpgradeTarget.tapPower,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tap_hvatka',
    name: 'Дедовская хватка',
    description: 'За тап ×3',
    cost: 60000,
    target: UpgradeTarget.tapPower,
    multiplier: 3,
  ),

  // --- Персональные ---
  Upgrade(
    id: 'drozhzhi',
    name: 'Дрожжи бабы Нюры',
    description: 'Банка ×2',
    cost: 200,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'banka',
    multiplier: 2,
  ),
  Upgrade(
    id: 'sahar',
    name: 'Сахар с оптовой базы',
    description: 'Бидон ×2',
    cost: 1000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'bidon',
    multiplier: 2,
  ),
  Upgrade(
    id: 'peregonka',
    name: 'Двойная перегонка',
    description: 'Фляга ×2',
    cost: 11000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'flyaga',
    multiplier: 2,
  ),
  Upgrade(
    id: 'termometr',
    name: 'Термометр (наконец-то)',
    description: 'Аппарат «Дедов» ×2',
    cost: 120000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'dedov',
    multiplier: 2,
  ),
  Upgrade(
    id: 'filtr',
    name: 'Угольный фильтр из противогаза',
    description: 'Медный змеевик ×2',
    cost: 1300000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'zmeevik',
    multiplier: 2,
  ),
  Upgrade(
    id: 'hvosty',
    name: 'Отсекать хвосты',
    description: 'Гаражный цех ×2',
    cost: 14000000,
    target: UpgradeTarget.generatorOutput,
    targetGeneratorId: 'tseh',
    multiplier: 2,
  ),

  // --- Глобальные ---
  Upgrade(
    id: 'recept',
    name: 'Рецепт прадеда',
    description: 'Все аппараты +50%',
    cost: 50000,
    target: UpgradeTarget.allGenerators,
    multiplier: 1.5,
  ),
  Upgrade(
    id: 'nochnaya',
    name: 'Ночная смена',
    description: 'Все аппараты ×2',
    cost: 6000000,
    target: UpgradeTarget.allGenerators,
    multiplier: 2,
  ),

  // --- Синергии: связки, а не плоские множители ---
  Upgrade(
    id: 'nastavnik',
    name: 'Наставник Петрович',
    description: 'Аппарат «Дедов» +1% за каждую банку',
    cost: 90000,
    target: UpgradeTarget.synergyCoupling,
    multiplier: 1,
  ),
  Upgrade(
    id: 'podryad',
    name: 'Семейный подряд',
    description: 'Каждый аппарат от 25 штук: +10% ко всем',
    cost: 400000,
    target: UpgradeTarget.synergyResonance,
    multiplier: 1,
  ),
];
