import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/providers/feedback_provider.dart';
import 'package:idle_game/providers/settings_provider.dart';

ProviderContainer _containerWith(SettingsStore store) {
  final container = ProviderContainer(
    overrides: [settingsStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Настройки: звук и вибрация.
///
/// Проверяется не «как звучит», а то, что галочка ведёт себя как галочка:
/// включена по умолчанию, запоминается, переживает перезапуск и не роняет
/// игру, если в хранилище мусор.
void main() {
  group('Звук и вибрация', () {
    test('по умолчанию включены', () {
      final container = _containerWith(MemorySettingsStore());
      expect(container.read(soundEnabledProvider), isTrue);
      expect(container.read(hapticsEnabledProvider), isTrue);
    });

    test('выключение записывается в настройки', () {
      final store = MemorySettingsStore();
      _containerWith(store).read(soundEnabledProvider.notifier).set(false);
      expect(store.read(SettingsKeys.sound), 'off');
    });

    test('переживает перезапуск', () {
      final store = MemorySettingsStore();
      _containerWith(store).read(hapticsEnabledProvider.notifier).set(false);

      // Второй контейнер — это и есть «игру закрыли и открыли заново».
      expect(_containerWith(store).read(hapticsEnabledProvider), isFalse);
      expect(_containerWith(store).read(soundEnabledProvider), isTrue,
          reason: 'выключили вибрацию — звук трогать было незачем');
    });

    test('мусор в настройках не роняет игру и не глушит звук', () {
      final store = MemorySettingsStore({SettingsKeys.sound: 'барокко'});
      expect(_containerWith(store).read(soundEnabledProvider), isTrue);
    });
  });
}
