import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

final artStyleProvider = StateProvider<ArtStyle>((ref) => ArtStyle.pixel);
