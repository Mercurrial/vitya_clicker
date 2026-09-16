import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../pixel/pixel_portrait.dart';

/// Два визуальных языка, между которыми выбираем.
///
/// Различие не косметическое: пиксель делает мир цельным (портрет живёт в том
/// же языке, что аппараты на полках), плакат сохраняет фотографичность Вити.
/// Переключатель нужен, чтобы решать глазами, а не в переписке.
enum ArtStyle {
  /// Пиксельный мир: портрет квантуется в спрайт, углы рубленые.
  pixel,

  /// Плакатный: постеризованная фотография, мягкие скругления.
  poster;

  String get label => switch (this) {
        ArtStyle.pixel => 'ПИКСЕЛЬ',
        ArtStyle.poster => 'ПЛАКАТ',
      };

  /// Как переводить фотографию Вити.
  PixelPortraitStyle get portrait => switch (this) {
        ArtStyle.pixel => PixelPortraitStyle.pixel,
        ArtStyle.poster => PixelPortraitStyle.poster,
      };

  /// Радиус скруглений интерфейса.
  double get radius => switch (this) {
        ArtStyle.pixel => 0,
        ArtStyle.poster => 20,
      };

  ArtStyle get next => this == ArtStyle.pixel ? ArtStyle.poster : ArtStyle.pixel;

  /// Как стиль лежит в настройках. Пишем имя, а не индекс: порядок в enum
  /// однажды поменяется, и сохранённая «1» молча превратится в другой стиль.
  static ArtStyle fromName(String? name) => ArtStyle.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ArtStyle.pixel,
      );
}

/// Хранилище настроек. Подменяется в `main` через override; без него игра
/// работает, но выбор стиля не переживёт перезапуск (так и в тестах).
final settingsStoreProvider =
    Provider<SettingsStore>((ref) => MemorySettingsStore());

/// Выбранный стиль. Переключатель раньше жил в `StateProvider` и забывался при
/// каждом запуске — плейтест поймал это первым же заходом.
class ArtStyleNotifier extends Notifier<ArtStyle> {
  @override
  ArtStyle build() => ArtStyle.fromName(
        ref.read(settingsStoreProvider).read(SettingsKeys.artStyle),
      );

  void set(ArtStyle style) {
    state = style;
    ref.read(settingsStoreProvider).write(SettingsKeys.artStyle, style.name);
  }

  void toggle() => set(state.next);
}

final artStyleProvider =
    NotifierProvider<ArtStyleNotifier, ArtStyle>(ArtStyleNotifier.new);
