import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/ui/theme/art_style.dart';

ProviderContainer _containerWith(SettingsStore store) {
  final container = ProviderContainer(
    overrides: [settingsStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Выбор стиля', () {
    test('по умолчанию пиксель', () {
      final container = _containerWith(MemorySettingsStore());
      expect(container.read(artStyleProvider), ArtStyle.pixel);
    });

    test('переключение записывается в настройки', () async {
      final store = MemorySettingsStore();
      final container = _containerWith(store);

      container.read(artStyleProvider.notifier).toggle();

      expect(container.read(artStyleProvider), ArtStyle.poster);
      expect(store.read(SettingsKeys.artStyle), ArtStyle.poster.name);
    });

    test('переживает перезапуск', () {
      final store = MemorySettingsStore();
      _containerWith(store).read(artStyleProvider.notifier).set(ArtStyle.poster);

      // Второй контейнер — это и есть «игру закрыли и открыли заново».
      expect(_containerWith(store).read(artStyleProvider), ArtStyle.poster);
    });

    test('мусор в настройках не роняет игру', () {
      final store = MemorySettingsStore({SettingsKeys.artStyle: 'барокко'});
      expect(_containerWith(store).read(artStyleProvider), ArtStyle.pixel);
    });

    test('храним имя, а не порядковый номер', () {
      // Порядок в enum когда-нибудь поменяют, и сохранённая «1» станет чужим
      // стилем. Этот тест держит формат.
      final store = MemorySettingsStore();
      _containerWith(store).read(artStyleProvider.notifier).set(ArtStyle.poster);
      expect(store.read(SettingsKeys.artStyle), 'poster');
    });
  });
}
