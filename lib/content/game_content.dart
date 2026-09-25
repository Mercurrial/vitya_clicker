/// Контент игры как ДАННЫЕ.
///
/// Объёмы — в миллилитрах, цены — в рублях. Разделение важно: самогон это
/// товар, рубли это деньги, и покупается всё именно за деньги.
///
/// Ни одно число отсюда не зашито в виджеты — баланс правится здесь, без
/// касания кода интерфейса и движка.
///
/// Цены и выходы лестницы и цены улучшений считаются из `Balance`. Скорость
/// удорожания внутри тира — общая для всех и лежит в `Balance.costGrowth`:
/// это главный тормоз экономики, и место ему одно.
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

/// Аппараты, с которыми начинается ЛЮБОЙ заход: новая игра, похмелье, сброс.
///
/// Витя начинает не с пустого гаража, а с одной трёхлитровой банкой. Это не
/// подарок, а необходимость: касание не даёт самогон, и без стартового
/// производства игрок заперт навсегда — заработать первые пятнадцать рублей
/// нечем. Симулятор упёрся в это сразу: ноль ступеней за четыре часа.
///
/// Функция отдельная, а не строчка внутри `newGame`, потому что забыть о ней
/// оказалось очень легко. Похмелье и «начать заново» собирали состояние сами,
/// мимо `newGame`, и выдавали пустой гараж. Игра запиралась насмерть ровно в
/// тот момент, когда игрок делал то, к чему его вела вся механика, — и
/// единственным выходом был сброс, который приводил туда же. Теперь стартовый
/// набор один на все пути, и разойтись им негде.
List<Generator> startingGenerators(List<Generator> content) => [
      for (final g in content)
        g.id == kGeneratorNames.first.id ? g.copyWith(ownedCount: 1) : g,
    ];

/// Улучшения, разложенные по четырём осям.
///
/// Раньше почти все делали одно и то же — множили выход, — и выбор сводился к
/// «купи что подешевле». Теперь оси разные и конкурируют между собой:
///   • объём   — аппараты производят больше
///   • цена    — качество поднимает рубли за литр
///   • ёмкость — бак вмещает больше, реже стоит простой
///   • руки    — окно жара шире, держать легче
///
/// Объём и цена строятся по формуле вдоль всей лестницы ([kTierUpgrades]),
/// руки, бак и связки — руками ниже. Описания сухие, как патчноут: смешно от
/// формулировки, а не оттого, что шутку объяснили.
///
/// ## Id — навсегда
///
/// Купленное лежит в сейве списком id, поэтому после выпуска id не
/// переименовываются: переименованное улучшение у игрока молча станет
/// некупленным. Названия и цены править можно, id — нет.
///
/// Схема одна на все: `<ось>_<привязка>`.
///   • привязка к ступени — id аппарата, те же вечные id, что в сейве:
///     `gen_banka_1`…`gen_banka_3` (×2 этой ступени, три уровня),
///     `all_banka` (все аппараты), `price_banka` (цена за литр);
///   • без ступени — порядковый номер внутри оси: `heat_1`…`heat_3`,
///     `tank_1`…`tank_4`, `syn_1`, `syn_2`.
/// Новое улучшение получает следующий свободный номер или новую ступень,
/// старые номера не переиспользуются.
List<Upgrade> get kUpgrades {
  final b = Balance.current;
  if (identical(_upgradesFor, b)) return _upgrades!;
  _upgrades = List.unmodifiable([
    ..._heatUpgrades,
    ..._tankUpgrades,
    for (var i = 0; i < kTierUpgrades.length; i++) ..._tierUpgrades(i, b),
    ..._synergyUpgrades,
  ]);
  _upgradesFor = b;
  return _upgrades!;
}

/// Как у лестницы: пересобирается только при смене баланса.
List<Upgrade>? _upgrades;
Balance? _upgradesFor;

/// Названия улучшений ступени — руками, по одной строке на аппарат.
///
/// Порядок строк — порядок [kGeneratorNames]; тест сверяет id, чтобы строка
/// не уехала на соседний аппарат.
typedef TierUpgradeNames = ({
  String generatorId,
  String short,
  List<String> boost,
  String all,
  String price,
});

const List<TierUpgradeNames> kTierUpgrades = [
  (
    generatorId: 'banka',
    short: 'Банка',
    boost: ['Дрожжи бабы Нюры', 'Банка на батарее', 'Марля в три слоя'],
    all: 'Рецепт прадеда',
    price: 'Двойная перегонка',
  ),
  (
    generatorId: 'bidon',
    short: 'Бидон',
    boost: ['Сахар с оптовой базы', 'Крышка на прищепке', 'Эмаль без сколов'],
    all: 'Ночная смена',
    price: 'Угольный фильтр из противогаза',
  ),
  (
    generatorId: 'flyaga',
    short: 'Фляга',
    boost: ['Медный бак', 'Фляга в валенке', 'Ремень от портупеи'],
    all: 'Тетрадка с пропорциями',
    price: 'Отсекать хвосты',
  ),
  (
    generatorId: 'dedov',
    short: '«Дедов»',
    boost: ['Термометр (наконец-то)', 'Сухопарник по чертежу деда', 'Дед одобрил'],
    all: 'Гараж утеплён',
    price: 'Настойка на кедровых орешках',
  ),
  (
    generatorId: 'zmeevik',
    short: 'Змеевик',
    boost: ['Проточное охлаждение', 'Змеевик длиннее на метр', 'Пайка серебром'],
    all: 'Второй удлинитель',
    price: 'Этикетка с принтера',
  ),
  (
    generatorId: 'tseh',
    short: 'Цех',
    boost: ['Сменный мастер', 'План на смену', 'Доска почёта'],
    all: 'Трёхфазное подключение',
    price: 'Бутылки из-под «Боржоми»',
  ),
  (
    generatorId: 'podval',
    short: 'Подвал',
    boost: ['Петрович провёл свет', 'Сырость ушла', 'Второй выход через погреб'],
    all: 'Работаем без выходных',
    price: 'Выдержка в дубовой бочке',
  ),
  (
    generatorId: 'tsisterna',
    short: 'Цистерна',
    boost: ['Промыли с хлоркой', 'Молоко больше не пахнет', 'Прицеп к «Кировцу»'],
    all: 'Своя логистика',
    price: 'Справка с печатью',
  ),
  (
    generatorId: 'druzhba',
    short: '«Дружба-2»',
    boost: ['Насосная станция', 'Врезка без шва', 'Давление в норме'],
    all: 'Поставки в соседний район',
    price: 'Розлив по ГОСТу',
  ),
  (
    generatorId: 'zavod',
    short: 'Завод',
    boost: ['Конвейер', 'ОТК из одного Вити', 'Третья смена'],
    all: 'Госзаказ',
    price: 'Бренд «Витя»',
  ),
  (
    generatorId: 'tanker',
    short: 'Танкер',
    boost: ['Капитан не пьёт', 'Второй трюм', 'Попутное течение'],
    all: 'Свой флот',
    price: 'Беспошлинная зона',
  ),
  (
    generatorId: 'orbita',
    short: '«Мир-2»',
    boost: ['Невесомость помогает', 'Солнечные панели', 'Стыковка с «Прогрессом»'],
    all: 'Спутниковый контроль',
    price: 'Космическая наценка',
  ),
  (
    generatorId: 'collider',
    short: 'Коллайдер',
    boost: ['Сверхпроводимость', 'Бозон брожения', 'Адронная закваска'],
    all: 'Теория всего',
    price: 'Нобелевка по химии',
  ),
];

/// Пять улучшений одной ступени: три «×2 этой ступени», «все аппараты» и
/// «цена за литр». Цены — в базовых ценах самой ступени, поэтому вдоль
/// лестницы множители не кончаются.
List<Upgrade> _tierUpgrades(int tier, Balance b) {
  final t = kTierUpgrades[tier];
  final base = b.firstGeneratorCost * math.pow(b.tierCostRatio, tier);
  return [
    for (var level = 0; level < t.boost.length; level++)
      Upgrade(
        id: 'gen_${t.generatorId}_${level + 1}',
        name: t.boost[level],
        description: '${t.short} ×${_x(b.tierUpgradeMultiplier)}',
        cost: base * b.tierUpgradeCosts[level],
        target: UpgradeTarget.generatorOutput,
        targetGeneratorId: t.generatorId,
        multiplier: b.tierUpgradeMultiplier,
      ),
    Upgrade(
      id: 'all_${t.generatorId}',
      name: t.all,
      description: 'Все аппараты ×${_x(b.globalUpgradeMultiplier)}',
      cost: base * b.globalUpgradeCost,
      target: UpgradeTarget.allGenerators,
      multiplier: b.globalUpgradeMultiplier,
    ),
    Upgrade(
      id: 'price_${t.generatorId}',
      name: t.price,
      description: 'Цена за литр ×${_x(b.qualityUpgradeMultiplier)}',
      cost: base * b.qualityUpgradeCost,
      target: UpgradeTarget.quality,
      multiplier: b.qualityUpgradeMultiplier,
    ),
  ];
}

/// 2.0 → «2», 1.3 → «1.3».
String _x(double m) =>
    m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toString();

// --- Жар: держать окно легче ---
//
// Раньше эти три улучшения множили силу нажатия. Нажатие больше не даёт
// самогон, так что множить стало нечего — но ось осталась нужной: она
// улучшает то единственное, ради чего игрок касается экрана.
const List<Upgrade> _heatUpgrades = [
  Upgrade(
    id: 'heat_1',
    name: 'Крепкая рука',
    description: 'Окно жара шире на четверть',
    cost: 40,
    target: UpgradeTarget.heatControl,
    multiplier: 1.25,
  ),
  Upgrade(
    id: 'heat_2',
    name: 'Трудовая мозоль',
    description: 'Окно жара шире ещё на четверть',
    cost: 1200,
    target: UpgradeTarget.heatControl,
    multiplier: 1.25,
  ),
  Upgrade(
    id: 'heat_3',
    name: 'Дедовская хватка',
    description: 'Окно жара шире ещё на треть',
    cost: 30000,
    target: UpgradeTarget.heatControl,
    multiplier: 1.3,
  ),
];

// --- Ёмкость бака ---
const List<Upgrade> _tankUpgrades = [
  Upgrade(
    id: 'tank_1',
    name: 'Вторая канистра',
    description: 'Запас бака ×2',
    cost: 200,
    target: UpgradeTarget.tankCapacity,
    multiplier: 2,
  ),
  Upgrade(
    id: 'tank_2',
    name: 'Бидон под слив',
    description: 'Запас бака ×3',
    cost: 9000,
    target: UpgradeTarget.tankCapacity,
    multiplier: 3,
  ),
  Upgrade(
    id: 'tank_3',
    name: 'Списанная цистерна',
    description: 'Запас бака ×4',
    cost: 900000,
    target: UpgradeTarget.tankCapacity,
    multiplier: 4,
  ),
  Upgrade(
    id: 'tank_4',
    name: 'Подземный резервуар',
    description: 'Запас бака ×5',
    cost: 60000000,
    target: UpgradeTarget.tankCapacity,
    multiplier: 5,
  ),
];

// --- Синергии: связки, а не плоские множители ---
const List<Upgrade> _synergyUpgrades = [
  Upgrade(
    id: 'syn_1',
    name: 'Наставник Петрович',
    description: 'Аппарат «Дедов» +1% за каждую банку',
    cost: 70000,
    target: UpgradeTarget.synergyCoupling,
    multiplier: 1,
  ),
  Upgrade(
    id: 'syn_2',
    name: 'Семейный подряд',
    description: 'Каждый аппарат от 25 штук: +10% ко всем',
    cost: 300000,
    target: UpgradeTarget.synergyResonance,
    multiplier: 1,
  ),
];
