/// Снять эталонный сейв текущей версии.
///
/// Запускать ОДИН РАЗ при выпуске версии:
///   dart run tools/make_fixture.dart 1.0.0
///
/// Полученный файл больше не правится никогда: это снимок того, что реально
/// лежит у игроков. Каждая следующая версия обязана его открыть и не
/// потерять ни одного факта — см. test/release_contract_test.dart.
///
/// Первый эталон включает строгие правила: с ним версии баланса и сейва
/// снова поднимаются при каждой правке, а отпечаток чисел сверяется. Вместе
/// с ним выпуск записывает действующий отпечаток в release_contract_test.
///
/// ## Почему партия, а не набор полей
///
/// Эталон проверяет ровно то, что в нём лежит. Первая версия этого файла
/// собирала середину партии и правила поля руками: потока, мудрости,
/// компенсации, портала и статистики в ней не было, а `hangovers = 1` стоял
/// при нуле нагнанного к похмелью — такого сейва в игре не бывает. Сломай
/// следующая версия чтение потока или портала, договор с выпуском промолчал
/// бы, а дополнить эталон после выпуска уже нельзя.
///
/// Поэтому сейв собирается партией: движок делает то же, что делает игрок, —
/// покупки, продажи Петровичу и гостю, похмелья, поток за отсутствие,
/// коллайдер. Что каждый ключ сейва лежит со значением не по умолчанию,
/// проверяет test/release_fixture_test.dart — на этой же сборке, всегда,
/// а не только в день выпуска. Сборка живёт здесь, а тест её импортирует:
/// эталон — то, что пишет этот инструмент, и проверять надо именно его, а
/// не копию, которая разойдётся с ним на первой же правке.
library;

import 'dart:io';

import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';

void main(List<String> args) {
  // Без версии раньше писался save_dev.json — а любой .json в test/fixtures
  // объявляет игру выпущенной и включает строгие правила.
  if (args.length != 1) {
    stderr.writeln('как: dart run tools/make_fixture.dart <версия>, '
        'например 1.0.0');
    exit(64);
  }

  final file = File('test/fixtures/save_${args.single}.json');
  if (file.existsSync()) {
    stderr.writeln('${file.path} уже есть. Эталон выпуска не переснимается: '
        'он — снимок того, что лежит у игроков.');
    exit(1);
  }

  file
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(fixtureSave());
  stdout.writeln('записан ${file.path}');
  stdout.writeln('ЭТОТ ФАЙЛ БОЛЬШЕ НЕ ПРАВИТСЯ.');
}

/// Эталон ровно в том виде, в каком ляжет в файл: с версией сейва, как
/// его пишет игра.
String fixtureSave() => const SaveCodec().encode(fixtureJson());

/// Сейв партии — без версии, как его отдаёт сериализатор.
///
/// `lastSeen` — момент последнего тика: игра пишет сейв на ходу, и позже
/// последнего посчитанного производства она себя видеть не могла.
Map<String, dynamic> fixtureJson() {
  final s = fixtureState();
  return const GameSerializer().toJson(
    s,
    lastSeenMillis: s.lastUpdateTime.millisecondsSinceEpoch,
  );
}

/// Партия, из которой снимается эталон.
///
/// Три захода: первый — до мудрости, второй — до коллайдера, третий идёт,
/// когда игра записывает сейв. Столько нужно, чтобы каждый факт отличался и
/// от нуля, и от соседа, с которым его легко перепутать: снимок портала —
/// от нынешней мудрости (после коллайдера было похмелье), наивысшая
/// ступень — от старшего купленного аппарата, начало захода — от первого
/// запуска.
///
/// Время — постоянное, а не часы машины: эталон один и тот же при каждом
/// запуске, и тест проверяет ровно то, что запишет выпуск.
GameState fixtureState() {
  final p = _Party(DateTime.utc(2026, 10, 3, 19));

  // Первый заход. Вечер знакомства: касания, зажим, первые покупки на
  // выручку от стартовой банки.
  p.touch(46);
  p.play(const Duration(minutes: 31, seconds: 12), holding: true, inWindow: true);
  p.sell();
  p.buyEarned('banka');
  p.upgradeEarned('heat_1');
  p.play(const Duration(minutes: 4, seconds: 31), holding: true);
  p.play(const Duration(minutes: 2, seconds: 5), inWindow: true);
  p.sell();

  // Дальше — сразу к мудрости: путь до неё — два с половиной часа игры,
  // и проходить его здесь незачем (см. [_Party.stake]).
  p.stake(3e18);
  p.buy('bidon', 25);
  p.buy('flyaga', 20);
  p.buy('dedov', 15);
  p.buy('zmeevik', 12);
  p.buy('tseh', 10);
  p.buy('podval', 8);
  p.buy('tsisterna', 6);
  p.buy('druzhba', 5);
  p.buy('zavod', 4);
  p.buy('tanker', 3);
  p.buy('orbita');
  for (final id in ['tank_1', 'tank_2', 'tank_3', 'tank_4', 'heat_2',
      'gen_banka_1', 'all_banka', 'price_banka']) {
    p.upgrade(id);
  }
  p.grind((s) => s.prestige.canPrestige);

  // Гость берёт только хороший сорт и уносит его — перед ним сорт
  // доводится до верха.
  p.sort(4.3);
  p.sellToGuest();
  p.achievements();
  // Что налилось после гостя, пропадёт с похмельем: нагнанное за всё время
  // и проданное расходятся, как у игрока.
  p.play(const Duration(minutes: 1, seconds: 48));
  p.hangover();

  // Ночь: игра закрыта, копится поток. Утром — вторая копилка.
  p.away(const Duration(hours: 9, minutes: 40));
  p.fluxBank();

  // Вышла правка баланса с извинением: запуск начисляет компенсацию
  // (bootstrap.dart). В журнале 1.0.0 компенсаций нет, но ключ пишется с
  // первого выпуска — и его чтение проверяется уже этим эталоном.
  p.compensate(2);

  // Второй заход: коллайдер. Снимок портала ляжет с похмельем, мудростью,
  // компенсацией и временем в игре — со всем, что к нему уже было.
  p.touch(19);
  p.play(const Duration(minutes: 12, seconds: 40), holding: true, inWindow: true);
  p.stake(2.5e23);
  p.buy('orbita', 3);
  p.buy(kPortalStillId);
  p.play(const Duration(minutes: 3), speed: 3);
  p.grind((s) => s.prestige.canPrestige);
  p.play(const Duration(seconds: 50));
  p.achievements();
  p.hangover();

  p.away(const Duration(hours: 22, minutes: 15));
  p.fluxRate();

  // Третий заход — на нём игра и записывает сейв. От банки и на свои:
  // ступень ниже наивысшей, бак не пуст, сорт в работе, поток потрачен
  // не весь.
  p.touch(73);
  p.play(const Duration(minutes: 6, seconds: 3), holding: true, inWindow: true,
      speed: 2);
  p.sell();
  p.buyEarned('bidon');
  p.buyEarned('bidon', 2);
  p.buyEarned('banka', 4);
  p.upgradeEarned('tank_1');
  p.sort(1.37);
  p.play(const Duration(minutes: 9, seconds: 17), holding: true);
  p.achievements();
  return p.s;
}

/// Игрок, которого изображает сборка эталона: каждое действие — вызов
/// движка, тот же, что делает игра.
class _Party {
  _Party(DateTime start)
      : t = start,
        s = newGame(content: kGenerators, upgrades: kUpgrades, now: start);

  static const _engine = GameEngine();

  GameState s;

  /// Часы партии. Идут только вперёд: игра не бывает в двух моментах сразу.
  DateTime t;

  /// Игра на экране [d]: гараж гонит, время в игре идёт.
  ///
  /// [speed] — ускорение потоком. Время в игре — настоящее, как и в игре:
  /// ускорение прибавляет производство, а не минуты на экране.
  void play(
    Duration d, {
    bool holding = false,
    bool inWindow = false,
    double speed = 1,
  }) {
    t = t.add(d);
    s = _engine.processTick(s, t, speed: speed);
    s = _engine.recordPlay(s, d.inMilliseconds / 1000,
        holding: holding, inWindow: inWindow);
  }

  void touch(int times) {
    for (var i = 0; i < times; i++) {
      s = _engine.registerTouch(s, t);
    }
  }

  void sort(double delta) => s = _engine.advanceSort(s, delta);

  void sell() => _did('Петрович не взял бак', () => _engine.sell(s, t));

  /// Сдать бак гостю — дождавшись его, как ждёт игрок: гости приходят по
  /// часам (events.dart).
  void sellToGuest() {
    while (eventAt(t) == null) {
      play(const Duration(minutes: 1));
    }
    final guest = eventAt(t)!.event.asBuyer;
    final before = s.stats.guestSales;
    s = _engine.sellTo(s, guest, t);
    _expect(s.stats.guestSales == before + 1,
        'гость «${guest.name}» не взял бак — сорт ниже, чем он берёт?');
  }

  int owned(String id) =>
      s.generators.items.firstWhere((g) => g.id == id).ownedCount;

  bool canBuy(String id, [int n = 1]) {
    final g = s.generators.items.firstWhere((g) => g.id == id);
    return s.resources.money >= _engine.bulkCost(g, n, t);
  }

  bool canUpgrade(String id) {
    final u = s.upgrades.items.firstWhere((u) => u.id == id);
    return s.resources.money >= _engine.upgradeCost(u, t);
  }

  /// Купить [n] штук: одну — штучной покупкой, больше — пачкой, как игрок
  /// жмёт ×1 или ×10. Снимок портала пишут обе.
  void buy(String id, [int n = 1]) {
    final before = owned(id);
    s = n == 1
        ? _engine.buyGenerator(s, id, t)
        : _engine.buyGeneratorBulk(s, id, n, t);
    _expect(owned(id) == before + n, 'не хватило денег на «$id» ×$n');
  }

  /// Купить на свои: гнать и сдавать, пока не хватит. Сколько денег даст
  /// похмелье на старте, зависит от вех — покупка на них держаться не должна.
  void buyEarned(String id, [int n = 1]) {
    grind((_) => canBuy(id, n));
    buy(id, n);
  }

  void upgradeEarned(String id) {
    grind((_) => canUpgrade(id));
    upgrade(id);
  }

  void upgrade(String id) {
    s = _engine.buyUpgrade(s, id, t);
    _expect(s.upgrades.items.any((u) => u.id == id && u.purchased),
        'улучшение «$id» не куплено — нет такого или не хватило денег');
  }

  /// Гнать и сдавать Петровичу, пока не выполнится [enough].
  ///
  /// Шаг — чуть больше, чем наливается бак: так каждый круг сдаёт полный
  /// бак, и кругов немного.
  void grind(bool Function(GameState) enough) {
    for (var i = 0; i < 200 && !enough(s); i++) {
      play(s.tankBuffer + const Duration(seconds: 1));
      sell();
    }
    _expect(enough(s), 'за 200 полных баков цель не достигнута');
  }

  void achievements() => s = _engine.checkAchievements(s).state;

  void hangover() {
    _expect(s.prestige.canPrestige, 'похмелье не даёт мудрости');
    s = _engine.prestige(s, kGenerators, kUpgrades, t);
  }

  /// Игра закрыта [d]: за это время копится поток, и только он.
  ///
  /// Метка тика переезжает на возврат — так же, как в `GameNotifier._tick`.
  /// Без этого первый тик после отсутствия посчитал бы производство за всю
  /// ночь, а ускорение списало бы на неё весь поток.
  void away(Duration d) {
    t = t.add(d);
    final credited = _engine.creditAfk(s, d);
    _expect(credited.gained > 0, 'отсутствие не дало потока');
    s = credited.state.copyWith(lastUpdateTime: t);
  }

  void fluxRate() =>
      _did('не хватило потока на «Крепкий сон»', () => _engine.buyFluxRate(s));

  void fluxBank() =>
      _did('не хватило потока на «Долгий сон»', () => _engine.buyFluxBank(s));

  /// Компенсация за правку баланса — тем же вызовом, что и при запуске.
  void compensate(int wisdom) =>
      s = s.copyWith(prestige: s.prestige.withCompensation(wisdom));

  /// Деньги, которые партия не заработала, а получила.
  ///
  /// Единственное место, где сборка подправляет состояние, а не играет:
  /// путь до коллайдера — сутки игры и дюжина похмелий, а эталону нужны
  /// факты, а не дорога к ним. Деньги — ресурс, из них не вычисляется ни
  /// один ключ сейва, поэтому подаренные деньги не делают сейв
  /// противоречивым. Нагнанное, похмелья и покупки по-прежнему идут только
  /// через движок.
  void stake(double money) =>
      s = s.copyWith(
          resources: s.resources.copyWith(money: s.resources.money + money));

  /// Выполнить действие и убедиться, что оно что-то сделало: движок на
  /// невозможное молча возвращает то же состояние.
  void _did(String failure, GameState Function() action) {
    final next = action();
    _expect(next != s, failure);
    s = next;
  }

  void _expect(bool ok, String failure) {
    if (ok) return;
    throw StateError('Сборка эталона разошлась с игрой: $failure. '
        'Правь партию в tools/make_fixture.dart под нынешний баланс.');
  }
}
