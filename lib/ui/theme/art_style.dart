import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Ширина портрета в крупных пикселях (0 — без пикселизации).
  double get portraitPixels => switch (this) {
        ArtStyle.pixel => 52,
        ArtStyle.poster => 0,
      };

  /// Сколько тонов оставить: пиксель любит жёсткую палитру.
  double get portraitLevels => switch (this) {
        ArtStyle.pixel => 5,
        ArtStyle.poster => 4,
      };

  /// Радиус скруглений интерфейса.
  double get radius => switch (this) {
        ArtStyle.pixel => 0,
        ArtStyle.poster => 20,
      };

  ArtStyle get next => this == ArtStyle.pixel ? ArtStyle.poster : ArtStyle.pixel;
}

final artStyleProvider = StateProvider<ArtStyle>((ref) => ArtStyle.pixel);
