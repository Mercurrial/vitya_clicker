/// Достижения — сетка рядов, а не список галочек.
///
/// Устройство скопировано с того, что работает в больших инкрементальных
/// играх: каждое достижение даёт небольшой множитель, а **заполненный ряд —
/// отдельный, крупный**. Из-за этого ряд хочется добить, и достижения
/// становятся системой прогресса, а не украшением.
///
/// Часть выдаётся сама по ходу игры — они работают встроенным гидом, показывая
/// ближайшую осмысленную цель. Часть требует осознанного действия. Два
/// достижения **открывают функции**: автопродажу и массовую покупку.
library;

import '../models/achievement.dart';
import '../models/game_state.dart';

/// Множитель за одно достижение.
const double kAchievementMultiplier = 1.05;

/// Множитель за полностью закрытый ряд.
const double kRowMultiplier = 1.35;

int _ownedOf(GameState s, String id) {
  for (final g in s.generators.items) {
    if (g.id == id) return g.ownedCount;
  }
  return 0;
}

int _maxOwned(GameState s) {
  var best = 0;
  for (final g in s.generators.items) {
    if (g.ownedCount > best) best = g.ownedCount;
  }
  return best;
}

int _distinctOwned(GameState s, {int atLeast = 1}) =>
    s.generators.items.where((g) => g.ownedCount >= atLeast).length;

bool _boughtWithTarget(GameState s, bool Function(String id) match) =>
    s.upgrades.items.any((u) => u.purchased && match(u.id));

final List<AchievementRow> kAchievementRows = [
  AchievementRow(
    title: 'Гараж',
    items: [
      Achievement(
        id: 'a_first_tap',
        name: 'Первая капля',
        hint: 'Подкинуть дров под аппарат',
        check: (s) => s.clicker.totalTaps >= 1,
      ),
      Achievement(
        id: 'a_first_still',
        name: 'Начало дела',
        hint: 'Купить трёхлитровую банку',
        check: (s) => _ownedOf(s, 'banka') >= 1,
      ),
      Achievement(
        id: 'a_first_sale',
        name: 'Первый рубль',
        hint: 'Продать самогон',
        check: (s) => s.resources.money >= 1,
      ),
      Achievement(
        id: 'a_litre',
        name: 'Целый литр',
        hint: 'Накопить литр в баке',
        check: (s) => s.resources.ml >= 1000,
      ),
    ],
  ),
  AchievementRow(
    title: 'Хозяйство',
    items: [
      Achievement(
        id: 'a_ten',
        name: 'Десяток',
        hint: 'Собрать 10 штук одного аппарата',
        check: (s) => _maxOwned(s) >= 10,
      ),
      Achievement(
        id: 'a_assortment',
        name: 'Ассортимент',
        hint: 'Завести три разных аппарата',
        check: (s) => _distinctOwned(s) >= 3,
      ),
      Achievement(
        id: 'a_full_tank',
        name: 'Под завязку',
        hint: 'Наполнить бак целиком',
        check: (s) => s.isTankFull,
      ),
      Achievement(
        id: 'a_thousand',
        name: 'Первая тысяча',
        hint: 'Накопить 1 000 ₽',
        check: (s) => s.resources.money >= 1000,
        // Ряд про хозяйство и заканчивается хозяйственным удобством:
        // дальше бак сдаётся сам.
        perk: AchievementPerk.autoSell,
      ),
    ],
  ),
  AchievementRow(
    title: 'Ремесло',
    items: [
      Achievement(
        id: 'a_quality',
        name: 'Не бодяжим',
        hint: 'Купить улучшение качества',
        check: (s) => _boughtWithTarget(s, (id) => id.startsWith('q_')),
      ),
      Achievement(
        id: 'a_tank_up',
        name: 'Тара нашлась',
        hint: 'Расширить бак',
        check: (s) => _boughtWithTarget(s, (id) => id.startsWith('tank_')),
      ),
      Achievement(
        id: 'a_hands',
        name: 'Рука набита',
        hint: 'Подкинуть дров 500 раз',
        check: (s) => s.clicker.totalTaps >= 500,
      ),
      Achievement(
        id: 'a_dedov',
        name: 'Дедово наследство',
        hint: 'Запустить аппарат «Дедов»',
        check: (s) => _ownedOf(s, 'dedov') >= 1,
        // Хозяйство разрослось — пора закупаться пачками.
        perk: AchievementPerk.bulkBuy,
      ),
    ],
  ),
  AchievementRow(
    title: 'Дело пошло',
    items: [
      Achievement(
        id: 'a_hundred',
        name: 'Сотня',
        hint: 'Собрать 100 штук одного аппарата',
        check: (s) => _maxOwned(s) >= 100,
      ),
      Achievement(
        id: 'a_million',
        name: 'Миллион',
        hint: 'Накопить 1 000 000 ₽',
        check: (s) => s.resources.money >= 1e6,
      ),
      Achievement(
        id: 'a_brigade',
        name: 'Бригада',
        hint: 'Довести пять аппаратов до 25 штук',
        check: (s) => _distinctOwned(s, atLeast: 25) >= 5,
      ),
      Achievement(
        id: 'a_synergy',
        name: 'Семейный подряд',
        hint: 'Купить обе синергии',
        check: (s) => _boughtWithTarget(s, (id) => id == 'syn_nastavnik') &&
            _boughtWithTarget(s, (id) => id == 'syn_podryad'),
      ),
    ],
  ),
  AchievementRow(
    title: 'Похмелье',
    items: [
      Achievement(
        id: 'a_first_hangover',
        name: 'Утро добрым не бывает',
        hint: 'Лечь проспаться в первый раз',
        check: (s) => s.prestige.hangovers >= 1,
      ),
      Achievement(
        id: 'a_wise',
        name: 'Мудрость приходит',
        hint: 'Набрать 10 мудрости',
        check: (s) => s.prestige.wisdom >= 10,
      ),
      Achievement(
        id: 'a_again',
        name: 'И снова здравствуйте',
        hint: 'Пережить три похмелья',
        check: (s) => s.prestige.hangovers >= 3,
      ),
      Achievement(
        id: 'a_legacy',
        name: 'Тонна за плечами',
        hint: 'Нагнать тонну за всё время',
        check: (s) => s.prestige.totalEverEarned >= 1e9,
      ),
    ],
  ),
];

/// Плоский список — для поиска по id при загрузке сейва.
final List<Achievement> kAllAchievements = [
  for (final row in kAchievementRows) ...row.items,
];
