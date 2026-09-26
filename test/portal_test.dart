import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/wisdom_milestones.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/core/sfx.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/generator.dart';
import 'package:idle_game/models/portal_state.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/models/stats_state.dart';
import 'package:idle_game/providers/feedback_provider.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/providers/settings_provider.dart';
import 'package:idle_game/ui/widgets/vitya_toast.dart';

/// Портал: снимок и наивысшая ступень.
///
/// Оба — факты, которые задним числом не восстановить: после похмелья
/// коллайдера в гараже уже нет, и без снимка второй слой не узнал бы, кто до
/// портала дошёл и с чем. Поэтому здесь проверяется не только запись, но и
/// всё, что могло бы снимок потерять или переписать: похмелье, перезапуск,
/// перенос кодом, повторная покупка, мусор в сейве.
void main() {
  // Вибрация ходит через платформенный канал; без биндинга плашка портала
  // проверялась бы на аварийной ветке отдачи.
  TestWidgetsFlutterBinding.ensureInitialized();

  const engine = GameEngine();
  const ser = GameSerializer();
  final t0 = DateTime.utc(2026, 3, 1, 12);
  final t1 = t0.add(const Duration(hours: 26, milliseconds: 417));
  final t2 = t1.add(const Duration(days: 3));

  const portal = World.garage;
  final firstMl = PrestigeState.firstWisdomMl;

  /// Новая игра с деньгами на что угодно, включая пачку коллайдеров.
  GameState rich() {
    final s = newGame(content: kGenerators, upgrades: kUpgrades, now: t0);
    return s.copyWith(resources: s.resources.copyWith(money: 1e40));
  }

  /// Середина долгой игры: мудрость, компенсация, похмелья, часы на экране.
  /// Числа разные, чтобы перепутанное поле снимка было видно.
  GameState played() => rich().copyWith(
        prestige: PrestigeState(
          claimedMl: firstMl * 1023,
          bonusWisdom: 2,
          totalEverEarned: firstMl * 16383,
          hangovers: 11,
        ),
        stats: StatsState.startedAt(t0)
            .addPlay(93600.5, holding: false, inWindow: false),
      );

  GameState withMoney(GameState s) =>
      s.copyWith(resources: s.resources.copyWith(money: 1e40));

  int owned(GameState s, String id) =>
      s.generators.items.firstWhere((g) => g.id == id).ownedCount;

  GameState load(Map<String, dynamic> json, {List<Generator>? content}) =>
      ser.fromJson(json, content: content ?? kGenerators, upgrades: kUpgrades, now: t2);

  /// Перезапуск тем же путём, что у игры: сейв в хранилище и обратно.
  Future<GameState> restart(GameState s) async {
    final saves = SaveService(storage: MemorySaveStorage());
    await saves.save(ser.toJson(s, lastSeenMillis: t1.millisecondsSinceEpoch));
    final loaded = await saves.load();
    expect(loaded.wasCorrupt, isFalse);
    return load(loaded.data!);
  }

  group('Снимок пишется один раз', () {
    test('портал — коллайдер', () {
      // Решение владельца (docs/DECISIONS.md, «Будущее»). Встанет за
      // коллайдером новая ступень — портал уедет на неё, и это надо видеть.
      expect(kPortalStillId, 'collider');
    });

    test('первая покупка коллайдера записывает, с чем Витя дошёл', () {
      final before = played();
      final after = engine.buyGenerator(before, kPortalStillId, t1);

      final shot = after.portal[portal];
      expect(shot, isNotNull, reason: 'коллайдер куплен, а снимка нет');
      expect(shot!.at, t1);
      expect(shot.lifetime, before.prestige.totalEverEarned);
      expect(shot.claimedMl, before.prestige.claimedMl);
      expect(shot.bonusWisdom, before.prestige.bonusWisdom);
      expect(shot.hangovers, before.prestige.hangovers);
      expect(shot.playSeconds, before.stats.playSeconds);
    });

    test('пачкой — тоже', () {
      // «МАКС» и «×10» идут другой функцией движка; снимок только от
      // штучной покупки у части игроков не появился бы вовсе.
      final after = engine.buyGeneratorBulk(played(), kPortalStillId, 10, t1);
      expect(owned(after, kPortalStillId), 10);
      expect(after.portal[portal]?.at, t1);
    });

    test('другие ступени портал не открывают', () {
      var s = played();
      for (final g in kGenerators) {
        if (g.id == kPortalStillId) continue;
        s = engine.buyGenerator(s, g.id, t1);
        s = engine.buyGeneratorBulk(s, g.id, 5, t1);
      }
      expect(s.portal.isEmpty, isTrue);
    });

    test('покупка не по карману снимок не пишет', () {
      final poor = played().copyWith(
        resources: played().resources.copyWith(money: 0),
      );
      expect(engine.buyGenerator(poor, kPortalStillId, t1).portal.isEmpty, isTrue);
      expect(engine.buyGeneratorBulk(poor, kPortalStillId, 10, t1).portal.isEmpty,
          isTrue);
    });

    test('повторная покупка его не переписывает', () {
      final first = engine.buyGenerator(played(), kPortalStillId, t1);
      final shot = first.portal[portal];

      // Игра шла дальше: нагнано больше, похмелий больше.
      final later = first.copyWith(
        prestige: first.prestige.copyWith(
          totalEverEarned: first.prestige.totalEverEarned * 8,
          hangovers: 14,
        ),
      );
      expect(engine.buyGenerator(later, kPortalStillId, t2).portal[portal], shot);
      expect(engine.buyGeneratorBulk(later, kPortalStillId, 5, t2).portal[portal],
          shot);
    });

    test('покупка коллайдера не двигает метку тика', () {
      // Покупки метку не трогают (см. processTick): иначе производство с
      // прошлого тика пропадало бы. Запись снимка этого не возвращает.
      final s = played();
      expect(engine.buyGenerator(s, kPortalStillId, t1).lastUpdateTime,
          s.lastUpdateTime);
      expect(engine.buyGeneratorBulk(s, kPortalStillId, 10, t1).lastUpdateTime,
          s.lastUpdateTime);
    });
  });

  group('Снимок переживает', () {
    test('похмелье — и второй коллайдер после него', () {
      var s = engine.buyGenerator(played(), kPortalStillId, t1);
      final shot = s.portal[portal];

      expect(s.prestige.canPrestige, isTrue);
      s = engine.prestige(s, kGenerators, kUpgrades, t2);
      expect(owned(s, kPortalStillId), 0, reason: 'похмелье не случилось');
      expect(s.portal[portal], shot);

      s = engine.buyGenerator(withMoney(s), kPortalStillId, t2);
      expect(s.portal[portal], shot);
    });

    test('перезапуск', () async {
      final s = engine.buyGenerator(played(), kPortalStillId, t1);
      final back = await restart(s);
      expect(back.portal, s.portal);
      expect(back.maxTier, kPortalStillId);
    });

    test('момент читается ровно тем, что записан', () async {
      // Часы телефона дают местный пояс и микросекунды, а сейв хранит UTC в
      // миллисекундах. Снимок, прочитанный обратно, обязан совпасть.
      final local = DateTime(2026, 3, 2, 14, 30, 5, 123, 456);
      final s = engine.buyGenerator(played(), kPortalStillId, local);
      final back = await restart(s);
      expect(back.portal[portal]!.at.isUtc, isTrue);
      expect(back.portal[portal]!.at.millisecondsSinceEpoch,
          local.millisecondsSinceEpoch);
      expect(back.portal, s.portal);
    });

    test('загрузка его не выдумывает: коллайдер есть, снимка нет', () {
      // Сейв записан до снимка портала. Досчитывать его из нынешнего
      // состояния нельзя: это были бы числа не того момента.
      final s = engine.buyGenerator(played(), kPortalStillId, t1);
      final json = ser.toJson(s, lastSeenMillis: 1)..remove('portal');
      final back = load(json);
      expect(owned(back, kPortalStillId), 1);
      expect(back.portal.isEmpty, isTrue);
    });
  });

  group('Наивысшая ступень', () {
    test('в новой игре — банка', () {
      expect(rich().maxTier, 'banka');
    });

    test('растёт с покупками и не убывает', () {
      var s = engine.buyGenerator(rich(), 'dedov', t1);
      expect(s.maxTier, 'dedov');
      s = engine.buyGeneratorBulk(s, 'bidon', 10, t1);
      expect(s.maxTier, 'dedov', reason: 'младшая ступень опустила наивысшую');

      // Аппараты ушли — пройденная ступень осталась.
      s = s.copyWith(generators: generatorsFrom(startingGenerators(kGenerators)));
      expect(s.maxTier, 'dedov');
    });

    test('переживает похмелье', () {
      var s = engine.buyGenerator(played(), 'tanker', t1);
      s = engine.prestige(s, kGenerators, kUpgrades, t2);
      expect(owned(s, 'tanker'), 0, reason: 'похмелье не случилось');
      expect(s.maxTier, 'tanker');
    });

    test('при загрузке — не меньше купленного', () {
      final json = ser.toJson(engine.buyGenerator(rich(), 'tseh', t1), lastSeenMillis: 1);

      expect(load({...json, 'maxTier': 'bidon'}).maxTier, 'tseh',
          reason: 'в сейве ступень ниже купленной — верить аппаратам');
      expect(load({...json, 'maxTier': 'tanker'}).maxTier, 'tanker',
          reason: 'пройденную ступень загрузка не отнимает');
    });

    test('лежит id, а не номер: вставленная ступень её не сдвигает', () {
      final json = ser.toJson(engine.buyGenerator(rich(), 'dedov', t1), lastSeenMillis: 1);
      expect(json['maxTier'], 'dedov');

      const inserted = Generator(id: 'novyi', name: 'Новый', baseCost: 1, baseProduction: 1);
      final ladder = [...kGenerators]..insert(1, inserted);
      expect(load(json, content: ladder).maxTier, 'dedov');
    });
  });

  group('Сейв', () {
    test('снимок в сейве — ровно эти поля, в этих единицах', () {
      // Этот вид будет читать второй слой, и с эталоном выпуска он станет
      // вечным. Новое поле — осознанно и сюда же; производное (мудрость,
      // множители, вехи) — никогда: его посчитают по формулам своего времени.
      final s = engine.buyGenerator(played(), kPortalStillId, t1);
      final json = jsonDecode(const SaveCodec().encode(ser.toJson(s, lastSeenMillis: 1)));

      expect(json['portal'], {
        'garage': {
          'at': t1.millisecondsSinceEpoch,
          'lifetime': firstMl * 16383,
          'claimedMl': firstMl * 1023,
          'bonusWisdom': 2,
          'hangovers': 11,
          'playSec': 93600.5,
        },
      });
      expect(json['maxTier'], kPortalStillId);
    });

    test('сейв в формате выпуска читается', () {
      // Строка, а не toJson: так снимок лежит у игроков, и переименованный
      // в коде ключ должен ронять этот тест, а не молча терять портал.
      const raw = '{"version":1,"stills":{"banka":3,"collider":2},'
          '"lifetime":3.5e24,"claimedMl":2.1e24,"hangovers":13,'
          '"maxTier":"collider",'
          '"portal":{"garage":{"at":1790000000123,"lifetime":2.9e24,'
          '"claimedMl":1.7e24,"bonusWisdom":1,"hangovers":12,"playSec":94321.4}}}';
      final loaded = const SaveCodec().decode(raw);
      expect(loaded.wasCorrupt, isFalse);

      final s = load(loaded.data!);
      expect(s.maxTier, 'collider');
      expect(
        s.portal[portal],
        PortalSnapshot(
          at: DateTime.fromMillisecondsSinceEpoch(1790000000123, isUtc: true),
          lifetime: 2.9e24,
          claimedMl: 1.7e24,
          bonusWisdom: 1,
          hangovers: 12,
          playSeconds: 94321.4,
        ),
      );
    });

    test('сейв без новых ключей читается: портала нет, ступень — по аппаратам', () {
      final s = engine.buyGenerator(played(), 'zmeevik', t1);
      final json = ser.toJson(s, lastSeenMillis: 1)
        ..remove('portal')
        ..remove('maxTier');
      final back = load(json);
      expect(back.portal.isEmpty, isTrue);
      expect(back.maxTier, 'zmeevik');
      expect(back.prestige, s.prestige);
    });

    test('мусор в новых ключах не делает сейв нечитаемым', () {
      // Упади разбор — читаемый сейв ушёл бы в отложенные копии, и игрок
      // остался бы без гаража из-за одного ключа (bootstrap.dart).
      final json = ser.toJson(engine.buyGenerator(rich(), 'dedov', t1), lastSeenMillis: 1);

      GameState? read(String key, Object? junk) {
        final loaded = const SaveCodec().decode(const SaveCodec().encode({...json, key: junk}));
        expect(loaded.wasCorrupt, isFalse, reason: '$key: $junk');
        GameState? s;
        expect(() => s = load(loaded.data!), returnsNormally, reason: '$key: $junk');
        expect(owned(s!, 'dedov'), 1, reason: 'из-за «$key: $junk» пропал гараж');
        return s;
      }

      for (final junk in <Object?>[
        null,
        'портал',
        42,
        true,
        const [],
        const {'garage': 'снимок'},
        const {'garage': []},
        const {'garage': {}},
        const {'garage': {'at': 'вчера'}},
        const {'garage': {'at': -5}},
        const {'garage': {'at': 1e300}},
        {'mars': {'at': t1.millisecondsSinceEpoch}},
      ]) {
        expect(read('portal', junk)!.portal.isEmpty, isTrue, reason: '$junk');
      }

      for (final junk in <Object?>[null, 7, true, const [], const {}, '', 'нет_такой']) {
        expect(read('maxTier', junk)!.maxTier, 'dedov', reason: '$junk');
      }
    });

    test('битые числа снимка читаются нулями, а сам снимок остаётся', () {
      // Момент на месте — портал открыт; потерять из-за одного числа сам
      // факт, что игрок до него дошёл, хуже, чем прочитать число нулём.
      final s = load({
        'portal': {
          'garage': {
            'at': t1.millisecondsSinceEpoch,
            'lifetime': 'много',
            'claimedMl': -1,
            'bonusWisdom': 2.7,
            'hangovers': null,
          },
        },
      });
      expect(
        s.portal[portal],
        PortalSnapshot(
          at: t1,
          lifetime: 0,
          claimedMl: 0,
          bonusWisdom: 2,
          hangovers: 0,
          playSeconds: 0,
        ),
      );
    });
  });

  group('В игре', () {
    ({
      ProviderContainer c,
      GameNotifier game,
      MemorySaveStorage storage,
      List<ToastMessage> toasts,
      List<Sfx> sounds,
    }) open(GameState state, {DateTime? now}) {
      final storage = MemorySaveStorage();
      final sound = _Recorder();
      final c = ProviderContainer(
        overrides: [
          initialStateProvider.overrideWithValue(state),
          timeProvider.overrideWithValue(() => now ?? t1),
          saveServiceProvider.overrideWithValue(SaveService(storage: storage)),
          soundOutputProvider.overrideWithValue(sound),
          settingsStoreProvider.overrideWithValue(MemorySettingsStore({})),
        ],
      );
      addTearDown(c.dispose);
      final toasts = <ToastMessage>[];
      c.listen(toastProvider, (_, next) {
        if (next != null) toasts.add(next);
      });
      return (
        c: c,
        game: c.read(gameProvider.notifier),
        storage: storage,
        toasts: toasts,
        sounds: sound.played,
      );
    }

    test('плашка — один раз за всю игру', () {
      final t = open(played());

      t.game.buyGenerator('banka');
      expect(t.toasts, isEmpty, reason: 'обычная покупка плашки не даёт');

      t.game.buyGenerator(kPortalStillId);
      expect(t.toasts, hasLength(1), reason: 'портал открыт, а игрок не узнал');
      expect(t.c.read(gameProvider).portal.isOpen(portal), isTrue);

      t.game.buyGenerator(kPortalStillId);
      t.game.buyGenerator(kPortalStillId, count: 10);
      expect(t.toasts, hasLength(1), reason: 'второй коллайдер — не открытие');

      // После похмелья коллайдера нет, и первый в новом заходе — тоже не
      // открытие: портал уже открыт.
      t.game.sleepItOff();
      final slept = t.toasts.length;
      t.game.state = withMoney(t.game.state);
      t.game.buyGenerator(kPortalStillId);
      expect(t.toasts, hasLength(slept));
    });

    test('пачкой — та же одна плашка и один звук', () {
      final t = open(played());
      t.game.buyGenerator(kPortalStillId, count: 10);
      expect(t.toasts, hasLength(1));
      expect(t.sounds, hasLength(1), reason: 'одна покупка — один звук');
    });

    test('снимок ложится в сейв сразу, не дожидаясь автосейва', () async {
      final t = open(played());
      t.game.buyGenerator(kPortalStillId);
      await pumpEventQueue();

      final saved = await t.storage.read();
      expect(saved, isNotNull, reason: 'портал открыт, а сейв не записан');
      final json = const SaveCodec().decode(saved).data!;
      expect(load(json).portal, t.c.read(gameProvider).portal);
    });

    test('переживает перенос кодом, и перенос его не переписывает', () async {
      final from = open(played(), now: t1);
      from.game.buyGenerator(kPortalStillId);
      final shot = from.c.read(gameProvider).portal[portal];
      final code = from.game.exportCode();

      final to = open(rich(), now: t2);
      expect(await to.game.importCode(code), isNull);
      expect(to.c.read(gameProvider).portal[portal], shot);
      expect(to.c.read(gameProvider).maxTier, kPortalStillId);

      to.game.state = withMoney(to.game.state);
      to.game.buyGenerator(kPortalStillId);
      expect(to.c.read(gameProvider).portal[portal], shot);
      expect(to.toasts, isEmpty, reason: 'портал открыт на другом устройстве');
    });

    test('код с коллайдером, но без снимка, снимок не выдумывает', () async {
      final bought = engine.buyGenerator(played(), kPortalStillId, t1);
      final json = ser.toJson(bought, lastSeenMillis: 1)..remove('portal');
      final code = encodeSaveCode(const SaveCodec().encode(json));

      final to = open(rich(), now: t2);
      expect(await to.game.importCode(code), isNull);
      expect(owned(to.c.read(gameProvider), kPortalStillId), 1);
      expect(to.c.read(gameProvider).portal.isEmpty, isTrue);
      expect(to.toasts, isEmpty);
    });
  });
}

class _Recorder implements SoundOutput {
  final List<Sfx> played = [];

  @override
  void play(Sfx sfx) => played.add(sfx);

  @override
  void dispose() {}
}
