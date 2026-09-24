import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/buyers.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/core/sfx.dart';
import 'package:idle_game/providers/feedback_provider.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/theme/art_style.dart';

/// Звук и вибрация.
///
/// Проверяется не «как звучит» — это дело ушей, — а **когда звучит**. Ровно тут
/// и живут ошибки: звук на несостоявшемся действии, звук при выключенном
/// звуке, звук шестьдесят раз в секунду.
class _Recorder implements SoundOutput {
  final List<Sfx> played = [];
  var disposed = false;

  @override
  void play(Sfx sfx) => played.add(sfx);

  @override
  void dispose() => disposed = true;
}

void main() {
  // Вибрация ходит через платформенный канал. Без биндинга он недоступен, и
  // тест проверял бы аварийную ветку вместо настоящей.
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime.utc(2026, 1, 1);

  ({ProviderContainer container, _Recorder sound}) open({
    Map<String, String> settings = const {},
    double money = 0,
    double ml = 0,
  }) {
    final sound = _Recorder();
    var state = newGame(content: kGenerators, upgrades: kUpgrades, now: t0);
    state = state.copyWith(
      resources: state.resources.copyWith(money: money, ml: ml),
    );

    final container = ProviderContainer(
      overrides: [
        initialStateProvider.overrideWithValue(state),
        timeProvider.overrideWithValue(() => t0),
        soundOutputProvider.overrideWithValue(sound),
        settingsStoreProvider
            .overrideWithValue(MemorySettingsStore({...settings})),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, sound: sound);
  }

  group('Звук приходит вместе с действием', () {
    test('касание гаража подкидывает дров', () {
      final t = open();
      t.container.read(gameProvider.notifier).registerTouch();
      expect(t.sound.played, [Sfx.stoke]);
    });

    test('покупка звучит', () {
      final t = open(money: 1000);
      t.container.read(gameProvider.notifier).buyGenerator('banka');
      expect(t.sound.played, [Sfx.buy]);
    });

    test('продажа звучит', () {
      final t = open(ml: 5000);
      t.container.read(gameProvider.notifier).sellTo(kBuyers.first);
      expect(t.sound.played, [Sfx.sell]);
    });
  });

  group('Звука нет там, где ничего не произошло', () {
    test('покупка без денег молчит', () {
      // Щелчок в ответ на нажатие по недоступной кнопке — это обещание,
      // которого игра не выполнила.
      final t = open(money: 0);
      t.container.read(gameProvider.notifier).buyGenerator('bidon');
      expect(t.sound.played, isEmpty);
    });

    test('продажа пустого бака молчит', () {
      final t = open(ml: 0);
      t.container.read(gameProvider.notifier).sellTo(kBuyers.first);
      expect(t.sound.played, isEmpty);
    });

    test('улучшение не по карману молчит', () {
      final t = open(money: 0);
      t.container.read(gameProvider.notifier).buyUpgrade(kUpgrades.first.id);
      expect(t.sound.played, isEmpty);
    });
  });

  group('Выключатель выключает', () {
    test('при выключенном звуке не играет ничего', () {
      final t = open(
        settings: {SettingsKeys.sound: 'off'},
        money: 1000,
        ml: 5000,
      );
      final game = t.container.read(gameProvider.notifier);

      game.registerTouch();
      game.buyGenerator('banka');
      game.sellTo(kBuyers.first);

      expect(t.sound.played, isEmpty,
          reason: 'звук выключен, а игра всё равно звучит');
    });

    test('переключение действует сразу, без перезапуска', () {
      final t = open(settings: {SettingsKeys.sound: 'off'});
      final game = t.container.read(gameProvider.notifier);

      game.registerTouch();
      expect(t.sound.played, isEmpty);

      t.container.read(soundEnabledProvider.notifier).set(true);
      game.registerTouch();
      expect(t.sound.played, [Sfx.stoke]);
    });

    test('выключенный звук не мешает вибрации, и наоборот', () {
      // Настройки независимы: человек может хотеть тишину, но отдачу.
      final t = open(settings: {SettingsKeys.sound: 'off'});
      expect(t.container.read(soundEnabledProvider), isFalse);
      expect(t.container.read(hapticsEnabledProvider), isTrue);
    });

    test('выбор запоминается', () {
      final store = MemorySettingsStore();
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      container.read(soundEnabledProvider.notifier).set(false);
      expect(store.read(SettingsKeys.sound), 'off');

      container.read(hapticsEnabledProvider.notifier).toggle();
      expect(store.read(SettingsKeys.haptics), 'off');
    });
  });

  group('Умолчания', () {
    test('нетронутая игра звучит', () {
      // Игрок, который ничего не настраивал, должен получить игру целиком.
      final t = open();
      expect(t.container.read(soundEnabledProvider), isTrue);
      expect(t.container.read(hapticsEnabledProvider), isTrue);
    });

    test('мусор в настройках не ломает игру', () {
      final t = open(settings: {SettingsKeys.sound: 'ага'});
      expect(t.container.read(soundEnabledProvider), isTrue,
          reason: 'непонятное значение должно означать «включено», а не сбой');
    });

    test('у каждого звука есть файл', () {
      for (final sfx in Sfx.values) {
        expect(sfx.asset, 'sfx/${sfx.name}.wav');
      }
    });
  });
}
