import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/ui/pixel/pixel_portrait.dart';

/// Регрессия на конкретную поломку: раньше портрет рисовался фрагментным
/// шейдером, координаты уезжали из-за трансформаций над виджетом, и вместо
/// лица получалась ровная заливка. Тесты смотрят на сами пиксели результата,
/// а не на то, «собралось ли».
///
/// Всё оборачивается в [WidgetTester.runAsync]: декодирование картинок
/// завершается колбэком движка, а обычная зона тестов крутит фейковое время и
/// такой Future никогда не дождётся.
void main() {
  const asset = 'assets/images/vitya/vitya_doc.jpg';

  Future<Set<int>> colorsOf(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final colors = <int>{};
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i + 3] == 0) continue;
      colors.add((bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]);
    }
    return colors;
  }

  testWidgets('портрет уменьшается до заданной сетки', (tester) async {
    await tester.runAsync(() async {
      final image = await PixelPortraitCache.get(asset, PixelPortraitStyle.pixel);
      expect(image.width, PixelPortraitStyle.pixel.resolution);
      expect(image.height, greaterThan(0));
    });
  });

  testWidgets('портрет НЕ превращается в однотонную заливку', (tester) async {
    await tester.runAsync(() async {
      final image = await PixelPortraitCache.get(asset, PixelPortraitStyle.pixel);
      final colors = await colorsOf(image);

      // Именно это ломалось: одна краска на весь кадр.
      expect(
        colors.length,
        greaterThan(2),
        reason: 'лицо должно состоять из нескольких тонов, а не из заливки',
      );
    });
  });

  testWidgets('используются только ступени тёплой палитры', (tester) async {
    await tester.runAsync(() async {
      final image = await PixelPortraitCache.get(asset, PixelPortraitStyle.pixel);
      final colors = await colorsOf(image);

      // Квантование обязано подтягивать каждый пиксель к лестнице тонов —
      // иначе это просто уменьшенная фотография.
      for (final c in colors) {
        expect(
          kSkinRamp.contains(0xFF000000 | c),
          isTrue,
          reason: 'цвет #${c.toRadixString(16)} вне палитры',
        );
      }
    });
  });

  testWidgets('число тонов ограничено настройкой levels', (tester) async {
    await tester.runAsync(() async {
      const style = PixelPortraitStyle(resolution: 48, levels: 3);
      final image = await PixelPortraitCache.get(asset, style);
      final colors = await colorsOf(image);
      expect(colors.length, lessThanOrEqualTo(3));
    });
  });

  testWidgets('плакатный режим детальнее пиксельного', (tester) async {
    await tester.runAsync(() async {
      final pixel = await PixelPortraitCache.get(asset, PixelPortraitStyle.pixel);
      final poster = await PixelPortraitCache.get(asset, PixelPortraitStyle.poster);
      expect(poster.width, greaterThan(pixel.width));
    });
  });

  testWidgets('повторный запрос отдаёт тот же объект из кэша', (tester) async {
    await tester.runAsync(() async {
      final a = await PixelPortraitCache.get(asset, PixelPortraitStyle.pixel);
      final b = await PixelPortraitCache.get(asset, PixelPortraitStyle.pixel);
      expect(identical(a, b), isTrue);
    });
  });
}
