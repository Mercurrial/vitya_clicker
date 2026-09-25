import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/buyers.dart';
import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/sorts.dart';
import 'package:idle_game/models/achievement.dart';
import 'package:idle_game/models/generator.dart';
import 'package:idle_game/models/upgrade.dart';

import 'support/economy_fingerprint.dart';

/// Отпечаток видит каждое число экономики, и новое число нельзя забыть.
///
/// Сверка отпечатка в `release_contract_test` до выпуска пропускается: числа
/// ещё правят. Но если отпечаток собран не из всех чисел, сверка после
/// выпуска промолчит ровно о той правке, ради которой написана, — первая
/// версия так промолчала бы о сортах, гостях, целях и жаре. Поэтому полнота
/// отпечатка проверяется здесь и всегда, а не с первым эталоном.
///
/// Как: каждое число по одному меняется, и отпечаток обязан измениться. А
/// чтобы новое число не прошло мимо списка правок, исходники классов и
/// файлов экономики сверяются со списками ниже: каждое поле и каждая
/// константа — либо в отпечатке, либо в исключениях с причиной.
void main() {
  late final base = currentEconomy();
  late final was = economyFingerprint(base);

  void expectSeen(String what, Economy changed) {
    expect(economyFingerprint(changed), isNot(was),
        reason: '$what не попадает в отпечаток: после выпуска его правка '
            'прошла бы мимо версии баланса, журнала и компенсации');
  }

  group('Отпечаток видит каждое число', () {
    test('каждое поле Balance', () {
      for (final edit in _balanceEdits.entries) {
        final changed = withBalance(edit.value(Balance.current), currentEconomy);
        expectSeen('Balance.${edit.key}', changed);
      }
    });

    test('аппараты и улучшения', () {
      final gens = base.generators;
      for (var i = 0; i < gens.length; i++) {
        for (final edit in _generatorEdits.entries) {
          expectSeen('kGenerators.${gens[i].id}.${edit.key}',
              base.copyWith(generators: _replaced(gens, i, edit.value(gens[i]))));
        }
      }
      final ups = base.upgrades;
      for (var i = 0; i < ups.length; i++) {
        for (final edit in _upgradeEdits.entries) {
          expectSeen('kUpgrades.${ups[i].id}.${edit.key}',
              base.copyWith(upgrades: _replaced(ups, i, edit.value(ups[i]))));
        }
      }
    });

    test('сорта, покупатель и гости', () {
      final sorts = base.sorts;
      for (var i = 0; i < sorts.length; i++) {
        for (final edit in _sortEdits.entries) {
          expectSeen('kSorts[$i].${edit.key}',
              base.copyWith(sorts: _replaced(sorts, i, edit.value(sorts[i]))));
        }
      }
      final buyers = base.buyers;
      for (var i = 0; i < buyers.length; i++) {
        for (final edit in _buyerEdits.entries) {
          expectSeen('kBuyers.${buyers[i].id}.${edit.key}',
              base.copyWith(buyers: _replaced(buyers, i, edit.value(buyers[i]))));
        }
      }
      final guests = base.guests;
      for (var i = 0; i < guests.length; i++) {
        for (final edit in _guestEdits.entries) {
          expectSeen('kGarageEvents.${guests[i].id}.${edit.key}',
              base.copyWith(guests: _replaced(guests, i, edit.value(guests[i]))));
        }
      }
    });

    test('цели и ряды', () {
      final rows = base.goalRows;
      for (var r = 0; r < rows.length; r++) {
        for (final edit in _rowEdits.entries) {
          expectSeen('kAchievementRows[$r].${edit.key}',
              base.copyWith(goalRows: _replaced(rows, r, edit.value(rows[r]))));
        }
        final items = rows[r].items;
        for (var a = 0; a < items.length; a++) {
          for (final edit in _goalEdits.entries) {
            final row = AchievementRow(
              title: rows[r].title,
              items: _replaced(items, a, edit.value(items[a])),
            );
            expectSeen('${items[a].id}.${edit.key}',
                base.copyWith(goalRows: _replaced(rows, r, row)));
          }
        }
      }
    });

    test('отдельные числа и формулы', () {
      for (final key in base.constants.keys) {
        expectSeen(key, base.copyWith(constants: _bumped(base.constants, key)));
      }
      for (final key in base.formulas.keys) {
        expectSeen(key, base.copyWith(formulas: _bumped(base.formulas, key)));
      }
    });
  });

  group('Отпечаток читается', () {
    test('повторяется от прогона к прогону', () {
      // Кэш лестницы и улучшений пересобирается под подменённый баланс —
      // после подмены отпечаток обязан вернуться к прежнему.
      final before = was;
      withBalance(_balanceEdits['costGrowth']!(Balance.current), currentEconomy);
      expect(economyFingerprint(currentEconomy()), before);
    });

    test('ключи не повторяются', () {
      // Две строки с одним ключом сравнивались бы как одна: правка во
      // второй прошла бы незамеченной.
      final keys = [
        for (final line in was.split('\n')) line.substring(0, line.indexOf(' = ')),
      ];
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('расхождение называет поехавшее число', () {
      final i = base.sorts.length - 1;
      final changed = economyFingerprint(base.copyWith(
        sorts: _replaced(base.sorts, i, _sortEdits['multiplier']!(base.sorts[i])),
      ));

      expect(fingerprintChanges(was, was), isEmpty);
      final changes = fingerprintChanges(was, changed);
      expect(changes, hasLength(1));
      expect(changes.single, contains('kSorts[$i]'));
    });
  });

  group('Новое число нельзя забыть', () {
    test('каждое поле классов экономики разобрано', () {
      final classes = _classBodies();
      final problems = <String>[
        for (final name in _covered.keys)
          if (!classes.containsKey(name)) 'класса $name больше нет — убери его из списков',
      ];

      for (final MapEntry(key: name, value: body) in classes.entries) {
        if (_notEconomyClasses.containsKey(name)) continue;
        final covered = _covered[name];
        if (covered == null) {
          problems.add('класс $name: его поля не разобраны');
          continue;
        }
        final skipped = _notInFingerprint[name] ?? const {};
        final fields = _fieldsOf(body);
        for (final f in fields) {
          if (!covered.contains(f) && !skipped.containsKey(f)) {
            problems.add('$name.$f');
          }
        }
        for (final f in {...covered, ...skipped.keys}) {
          if (!fields.contains(f)) problems.add('$name.$f нет в коде — убери из списков');
        }
      }

      expect(problems, isEmpty,
          reason: 'новое поле класса экономики. Влияет на доход, цены или '
              'скорость — выведи его в economyFingerprint '
              '(test/support/economy_fingerprint.dart) и добавь правку сюда; '
              'не влияет — в исключения с причиной. Новый класс контента — '
              'так же, целиком.');
    });

    test('каждая константа файлов экономики разобрана', () {
      final found = <String>{
        for (final dir in _economyDirs)
          for (final file in _dartFiles(dir))
            ..._declarations(file.readAsStringSync()),
        for (final path in _economyClassFiles)
          ..._declarations(File(path).readAsStringSync(), staticOnly: true),
      };

      bool inConstants(String name) => base.constants.keys
          .any((k) => RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(k));

      final unknown = [
        for (final name in found)
          if (!inConstants(name) &&
              !_coveredElsewhere.containsKey(name) &&
              !_notEconomy.containsKey(name))
            name,
      ];
      expect(unknown, isEmpty,
          reason: 'новая константа в файлах экономики. Влияет на доход, цены '
              'или скорость — добавь её в Economy.constants или таблицы '
              '(test/support/economy_fingerprint.dart); не влияет — в '
              '_notEconomy с причиной');

      final stale = [
        for (final name in [..._coveredElsewhere.keys, ..._notEconomy.keys])
          if (!found.contains(name)) name,
      ];
      expect(stale, isEmpty,
          reason: 'этих объявлений больше нет в коде — убери их из списков');
    });
  });
}

// --- Правки: по одной на каждое число, которое видит отпечаток -------------

/// Правка, которую видно в десяти значащих цифрах отпечатка.
double _up(double v) => v == 0 ? 1 : v * 1.01;

Map<String, num> _bumped(Map<String, num> values, String key) => {
      ...values,
      key: switch (values[key]!) { final int v => v + 1, final v => _up(v.toDouble()) },
    };

List<T> _replaced<T>(List<T> list, int i, T item) => [...list]..[i] = item;

/// По правке на каждое поле [Balance]. Тест сверяет этот список с полями
/// класса: новое поле без правки здесь не пройдёт.
final Map<String, Balance Function(Balance)> _balanceEdits = {
  'costGrowth': (b) => b.copyWith(costGrowth: _up(b.costGrowth)),
  'firstWisdomMl': (b) => b.copyWith(firstWisdomMl: _up(b.firstWisdomMl)),
  'firstWisdomBonus': (b) => b.copyWith(firstWisdomBonus: _up(b.firstWisdomBonus)),
  'bonusPerWisdom': (b) => b.copyWith(bonusPerWisdom: _up(b.bonusPerWisdom)),
  'basePricePerMl': (b) => b.copyWith(basePricePerMl: _up(b.basePricePerMl)),
  'baseTankMl': (b) => b.copyWith(baseTankMl: _up(b.baseTankMl)),
  'baseBufferSeconds': (b) => b.copyWith(baseBufferSeconds: _up(b.baseBufferSeconds)),
  'maxBufferSeconds': (b) => b.copyWith(maxBufferSeconds: _up(b.maxBufferSeconds)),
  'milestones': (b) => b.copyWith(milestones: [...b.milestones, b.milestones.last + 1]),
  'firstGeneratorCost': (b) => b.copyWith(firstGeneratorCost: _up(b.firstGeneratorCost)),
  'tierCostRatio': (b) => b.copyWith(tierCostRatio: _up(b.tierCostRatio)),
  'firstGeneratorOutput': (b) =>
      b.copyWith(firstGeneratorOutput: _up(b.firstGeneratorOutput)),
  'tierOutputRatio': (b) => b.copyWith(tierOutputRatio: _up(b.tierOutputRatio)),
  'tierUpgradeCosts': (b) => b.copyWith(
      tierUpgradeCosts: [_up(b.tierUpgradeCosts.first), ...b.tierUpgradeCosts.skip(1)]),
  'tierUpgradeMultiplier': (b) =>
      b.copyWith(tierUpgradeMultiplier: _up(b.tierUpgradeMultiplier)),
  'globalUpgradeCost': (b) => b.copyWith(globalUpgradeCost: _up(b.globalUpgradeCost)),
  'globalUpgradeMultiplier': (b) =>
      b.copyWith(globalUpgradeMultiplier: _up(b.globalUpgradeMultiplier)),
  'qualityUpgradeCost': (b) => b.copyWith(qualityUpgradeCost: _up(b.qualityUpgradeCost)),
  'qualityUpgradeMultiplier': (b) =>
      b.copyWith(qualityUpgradeMultiplier: _up(b.qualityUpgradeMultiplier)),
  'fluxMinutesPerHour': (b) => b.copyWith(fluxMinutesPerHour: _up(b.fluxMinutesPerHour)),
  'fluxMaxMinutesPerHour': (b) =>
      b.copyWith(fluxMaxMinutesPerHour: _up(b.fluxMaxMinutesPerHour)),
  'fluxBankHours': (b) => b.copyWith(fluxBankHours: _up(b.fluxBankHours)),
  'fluxMaxBankHours': (b) => b.copyWith(fluxMaxBankHours: _up(b.fluxMaxBankHours)),
  'fluxRateCostBase': (b) => b.copyWith(fluxRateCostBase: _up(b.fluxRateCostBase)),
  'fluxRateCostStep': (b) => b.copyWith(fluxRateCostStep: _up(b.fluxRateCostStep)),
  'fluxBankCostBase': (b) => b.copyWith(fluxBankCostBase: _up(b.fluxBankCostBase)),
  'fluxBankCostStep': (b) => b.copyWith(fluxBankCostStep: _up(b.fluxBankCostStep)),
  'fluxMaxSpeed': (b) => b.copyWith(fluxMaxSpeed: _up(b.fluxMaxSpeed)),
};

final Map<String, Generator Function(Generator)> _generatorEdits = {
  'id': (g) => g.copyWith(id: '${g.id}_'),
  'baseCost': (g) => g.copyWith(baseCost: _up(g.baseCost)),
  'baseProduction': (g) => g.copyWith(baseProduction: _up(g.baseProduction)),
};

final Map<String, Upgrade Function(Upgrade)> _upgradeEdits = {
  'id': (u) => _upgrade(u, id: '${u.id}_'),
  'cost': (u) => _upgrade(u, cost: _up(u.cost)),
  'target': (u) => _upgrade(u,
      target: UpgradeTarget.values[(u.target.index + 1) % UpgradeTarget.values.length]),
  'targetGeneratorId': (u) => _upgrade(u,
      targetGeneratorId: () => u.targetGeneratorId == null ? 'banka' : null),
  'multiplier': (u) => _upgrade(u, multiplier: _up(u.multiplier)),
};

Upgrade _upgrade(
  Upgrade u, {
  String? id,
  double? cost,
  UpgradeTarget? target,
  String? Function()? targetGeneratorId,
  double? multiplier,
}) =>
    Upgrade(
      id: id ?? u.id,
      name: u.name,
      description: u.description,
      cost: cost ?? u.cost,
      target: target ?? u.target,
      targetGeneratorId:
          targetGeneratorId != null ? targetGeneratorId() : u.targetGeneratorId,
      multiplier: multiplier ?? u.multiplier,
      purchased: u.purchased,
    );

final Map<String, Sort Function(Sort)> _sortEdits = {
  'multiplier': (s) =>
      Sort(name: s.name, multiplier: _up(s.multiplier), from: s.from, to: s.to),
};

final Map<String, Buyer Function(Buyer)> _buyerEdits = {
  'id': (b) => _buyer(b, id: '${b.id}_'),
  'multiplier': (b) => _buyer(b, multiplier: _up(b.multiplier)),
  'minSortIndex': (b) => _buyer(b, minSortIndex: b.minSortIndex + 1),
  'minMl': (b) => _buyer(b, minMl: _up(b.minMl)),
  'maxMl': (b) => _buyer(b, maxMl: () => b.maxMl == null ? 1000 : null),
  'consumesSort': (b) => _buyer(b, consumesSort: !b.consumesSort),
};

Buyer _buyer(
  Buyer b, {
  String? id,
  double? multiplier,
  int? minSortIndex,
  double? minMl,
  double? Function()? maxMl,
  bool? consumesSort,
}) =>
    Buyer(
      id: id ?? b.id,
      name: b.name,
      multiplier: multiplier ?? b.multiplier,
      minSortIndex: minSortIndex ?? b.minSortIndex,
      minMl: minMl ?? b.minMl,
      maxMl: maxMl != null ? maxMl() : b.maxMl,
      consumesSort: consumesSort ?? b.consumesSort,
      note: b.note,
      lockedNote: b.lockedNote,
    );

final Map<String, GarageEvent Function(GarageEvent)> _guestEdits = {
  'id': (e) => _guest(e, id: '${e.id}_'),
  'multiplier': (e) => _guest(e, multiplier: _up(e.multiplier)),
  'minSortIndex': (e) => _guest(e, minSortIndex: e.minSortIndex + 1),
};

GarageEvent _guest(GarageEvent e, {String? id, double? multiplier, int? minSortIndex}) =>
    GarageEvent(
      id: id ?? e.id,
      title: e.title,
      note: e.note,
      lockedNote: e.lockedNote,
      multiplier: multiplier ?? e.multiplier,
      minSortIndex: minSortIndex ?? e.minSortIndex,
    );

final Map<String, Achievement Function(Achievement)> _goalEdits = {
  'id': (a) => _goal(a, id: '${a.id}_'),
  'perk': (a) => _goal(a,
      perk: AchievementPerk.values[(a.perk.index + 1) % AchievementPerk.values.length]),
};

Achievement _goal(Achievement a, {String? id, AchievementPerk? perk}) => Achievement(
      id: id ?? a.id,
      name: a.name,
      hint: a.hint,
      check: a.check,
      perk: perk ?? a.perk,
    );

final Map<String, AchievementRow Function(AchievementRow)> _rowEdits = {
  // Цель, ушедшая из ряда, меняет и ×1.05, и то, когда ряд закрывается.
  'items': (r) => AchievementRow(title: r.title, items: r.items.sublist(1)),
};

// --- Что разобрано, а что сознательно нет ----------------------------------

/// Классы экономики и поля, которые видит отпечаток, — по списку правок.
final Map<String, Set<String>> _covered = {
  'Balance': _balanceEdits.keys.toSet(),
  'Generator': _generatorEdits.keys.toSet(),
  'Upgrade': _upgradeEdits.keys.toSet(),
  'Sort': _sortEdits.keys.toSet(),
  'Buyer': _buyerEdits.keys.toSet(),
  'GarageEvent': _guestEdits.keys.toSet(),
  'Achievement': _goalEdits.keys.toSet(),
  'AchievementRow': _rowEdits.keys.toSet(),
};

/// Поля классов экономики, которых нет в отпечатке, — и почему.
const Map<String, Map<String, String>> _notInFingerprint = {
  'Generator': {
    'name': 'текст',
    'ownedCount': 'сколько куплено — факт сейва, в таблице всегда 0',
  },
  'Upgrade': {
    'name': 'текст',
    'description': 'текст',
    'purchased': 'куплено ли — факт сейва, в таблице всегда нет',
  },
  'Sort': {'name': 'текст', 'from': 'цвет шкалы', 'to': 'цвет шкалы'},
  'Buyer': {'name': 'текст', 'note': 'текст', 'lockedNote': 'текст'},
  'GarageEvent': {'title': 'текст', 'note': 'текст', 'lockedNote': 'текст'},
  'Achievement': {
    'name': 'текст',
    'hint': 'текст',
    // Пробел в покрытии, а не решение «не экономика»: пороги целей влияют
    // на скорость, но записаны кодом. Покрыть их можно, только вынеся в
    // данные.
    'check': 'условие цели — код: пороги отпечаток не видит',
  },
  'AchievementRow': {'title': 'текст'},
};

/// Классы контента, которые не экономика.
const Map<String, String> _notEconomyClasses = {
  'BalanceRelease': 'запись журнала для игрока; компенсацию стережёт '
      'balance_update_test',
  'ActiveEvent': 'гость в моменте — вычисляется из расписания',
  'Measure': 'меры статистики («нагнано N рюмок»), на доход не влияют',
  'TutorialFacts': 'обучение',
  'VityaVoice': 'реплики Вити',
};

/// Файлы классов экономики: весь контент и модели, из которых он собран.
const List<String> _classFiles = [
  'lib/models/generator.dart',
  'lib/models/upgrade.dart',
  'lib/models/achievement.dart',
];

/// Каталоги экономики — целиком, чтобы новый файл попал в проверку сам.
const List<String> _economyDirs = ['lib/content', 'lib/engine', 'lib/models'];

/// Отсюда — только статические константы: остальное в этих файлах —
/// интерфейс и провайдеры, а числа экономики живут в классах.
const List<String> _economyClassFiles = [
  'lib/ui/game/heat_controller.dart',
  'lib/providers/game_provider.dart',
];

/// Объявления, которые попадают в отпечаток не под своим именем.
const Map<String, String> _coveredElsewhere = {
  'kBalance': 'Balance.*',
  'kGeneratorNames': 'kGenerators',
  'kTierUpgrades': 'kUpgrades',
  '_heatUpgrades': 'kUpgrades',
  '_tankUpgrades': 'kUpgrades',
  '_synergyUpgrades': 'kUpgrades',
  'kSorts': 'kSorts',
  'kBuyers': 'kBuyers',
  'kGarageEvents': 'kGarageEvents',
  'kAchievementRows': 'kAchievementRows',
  'kAllAchievements': 'kAchievementRows — те же цели плоским списком',
  '_slowPeriodSeconds': 'Market.wave в контрольных точках',
  '_fastPeriodSeconds': 'Market.wave в контрольных точках',
  '_menteeId': 'Production.mlPerSecond(пробный гараж, связки)',
  '_mentorId': 'Production.mlPerSecond(пробный гараж, связки)',
};

/// Объявления в файлах экономики, которые не экономика, — и почему.
const Map<String, String> _notEconomy = {
  'kBalanceVersion': 'версия баланса: её и поднимают, когда поехал отпечаток',
  'kBalanceLog': 'журнал для игрока — тексты',
  'kContentIsFlutterFree': 'флаг развязки контента с Flutter',
  'kScheduleHashMaxFactor': 'служебная, для теста переносимости хеша; само '
      'расписание — «eventAt за неделю»',
  'kShot': 'мера статистики, на доход не влияет',
  'kJar': 'мера статистики, на доход не влияет',
  'kMeasures': 'меры статистики, на доход не влияют',
  'kVityaLines': 'реплики Вити',
  '_tickInterval': 'шаг тика: производство и сорт считаются в секундах, '
      'итог от шага не зависит',
  '_autosaveInterval': 'как часто писать сейв',
};

// --- Чтение исходников -----------------------------------------------------

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Тела классов контента и моделей, из которых он собран: имя → текст.
Map<String, String> _classBodies() {
  final bodies = <String, String>{};
  for (final file in [..._dartFiles('lib/content'), ..._classFiles.map(File.new)]) {
    final source = file.readAsStringSync();
    for (final m in RegExp(r'^class (\w+)\b[^{]*\{([\s\S]*?)^\}', multiLine: true)
        .allMatches(source)) {
      bodies[m.group(1)!] = m.group(2)!;
    }
  }
  return bodies;
}

/// Поля класса — и те, что задаются в конструкторе, и со значением прямо в
/// классе: `final double bonus = 1.2;` — такое же число экономики.
///
/// Поле от локальной переменной метода отличает отступ: у членов класса он
/// ровно два пробела (dart format), у тела метода — больше.
Set<String> _fieldsOf(String body) => {
      for (final m in RegExp(
              r'^ {2}(?:late[ \t]+)?final[ \t]+(?:[^=;\n]+?[ \t]+)?([A-Za-z_]\w*)[ \t]*[;=]',
              multiLine: true)
          .allMatches(body))
        m.group(1)!,
    };

/// Имена констант и таблиц: верхнего уровня и статические.
Set<String> _declarations(String source, {bool staticOnly = false}) => {
      for (final m in RegExp(
              '^${staticOnly ? r'[ \t]+static[ \t]+' : r'(?:[ \t]+static[ \t]+)?'}'
              r'(?:const|final)[ \t]+(?:[^=;\n]+?[ \t]+)?([A-Za-z_]\w*)[ \t]*=',
              multiLine: true)
          .allMatches(source))
        m.group(1)!,
    };
