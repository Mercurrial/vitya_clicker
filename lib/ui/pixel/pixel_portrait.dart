import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Портрет Вити, переведённый в пиксель-арт.
///
/// Считается на CPU, а не шейдером. Фрагментный шейдер здесь уже подводил:
/// `FlutterFragCoord()` возвращает координату в пространстве холста, а над
/// портретом стоит `Transform.scale` (отдача при нажатии) и смещение от
/// раскладки — из-за этого UV уезжали за пределы текстуры и вместо лица
/// получалась ровная заливка. Пересчёт пикселей даёт предсказуемый результат
/// на любой платформе и полный контроль над палитрой.
///
/// Порядок работы: уменьшаем фотографию до нескольких десятков пикселей
/// (декодер честно усредняет, а не выбрасывает точки), затем каждый пиксель
/// подтягиваем к ближайшей ступени тёплой палитры.

/// Тёплая лестница тонов — от тени гаража до блика лампы.
///
/// Это НЕ медь и не латунь: кожа, окрашенная в металл, выглядит как памятник
/// в худшем смысле. Ступени подобраны так, чтобы лицо читалось живым при
/// тёплом свете лампочки, а тени уходили в цвет самого гаража.
const List<int> kSkinRamp = [
  0xFF171009, // глубокая тень
  0xFF32210F, // тень
  0xFF5A3A1E, // полутень
  0xFF8A5A2F, // кожа в тени
  0xFFB27B45, // кожа
  0xFFD6A063, // кожа на свету
  0xFFF0C88C, // блик
  0xFFFFF0CE, // засветка
];

/// Насколько «крупный» пиксель и сколько ступеней оставить.
class PixelPortraitStyle {
  /// Ширина результата в пикселях. 56 — отчётливый спрайт, 200 — почти фото.
  final int resolution;

  /// Сколько ступеней палитры использовать (2..8).
  final int levels;

  /// Подъём контраста перед квантованием: без него лицо «плывёт» в кашу.
  final double contrast;

  const PixelPortraitStyle({
    required this.resolution,
    required this.levels,
    this.contrast = 1.25,
  });

  static const pixel = PixelPortraitStyle(resolution: 56, levels: 6);
  static const poster = PixelPortraitStyle(resolution: 200, levels: 4, contrast: 1.45);

  @override
  bool operator ==(Object other) =>
      other is PixelPortraitStyle &&
      other.resolution == resolution &&
      other.levels == levels &&
      other.contrast == contrast;

  @override
  int get hashCode => Object.hash(resolution, levels, contrast);
}

/// Переводит картинку в пиксель-арт и кэширует результат.
class PixelPortraitCache {
  PixelPortraitCache._();

  static final Map<String, Future<ui.Image>> _cache = {};

  static Future<ui.Image> get(String asset, PixelPortraitStyle style) {
    final key = '$asset#${style.resolution}#${style.levels}#${style.contrast}';
    return _cache.putIfAbsent(key, () => _build(asset, style));
  }

  static Future<ui.Image> _build(String asset, PixelPortraitStyle style) async {
    final data = await rootBundle.load(asset);

    // targetWidth заставляет декодер усреднить исходник — это честное
    // уменьшение, а не выборка каждого N-го пикселя, поэтому лицо не рассыпается.
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: style.resolution,
    );
    final small = (await codec.getNextFrame()).image;

    final raw = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) return small;

    final pixels = raw.buffer.asUint8List();
    final steps = style.levels.clamp(2, kSkinRamp.length);

    for (var i = 0; i < pixels.length; i += 4) {
      final a = pixels[i + 3];
      if (a == 0) continue;

      // Яркость по восприятию: глаз сильнее реагирует на зелёный канал.
      var lum = (pixels[i] * 0.299 + pixels[i + 1] * 0.587 + pixels[i + 2] * 0.114) / 255.0;

      // Контраст вокруг средней точки — иначе после квантования лицо плоское.
      lum = ((lum - 0.5) * style.contrast + 0.5).clamp(0.0, 1.0);

      // Ближайшая ступень лестницы.
      final index = (lum * (steps - 1)).round().clamp(0, steps - 1);
      // Ступени берём из полной палитры равномерно, чтобы при малом levels
      // сохранялся весь диапазон от тени до блика.
      final rampIndex = steps == kSkinRamp.length
          ? index
          : (index * (kSkinRamp.length - 1) / (steps - 1)).round();
      final color = kSkinRamp[rampIndex];

      pixels[i] = (color >> 16) & 0xFF;
      pixels[i + 1] = (color >> 8) & 0xFF;
      pixels[i + 2] = color & 0xFF;
    }

    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      small.width,
      small.height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }
}

/// Показывает переведённый портрет, заполняя доступную область (как cover).
class PixelPortrait extends StatefulWidget {
  final String asset;
  final PixelPortraitStyle style;

  const PixelPortrait({
    super.key,
    required this.asset,
    this.style = PixelPortraitStyle.pixel,
  });

  @override
  State<PixelPortrait> createState() => _PixelPortraitState();
}

class _PixelPortraitState extends State<PixelPortrait> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PixelPortrait old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset || old.style != widget.style) _load();
  }

  Future<void> _load() async {
    try {
      final image = await PixelPortraitCache.get(widget.asset, widget.style);
      if (mounted) setState(() => _image = image);
    } catch (_) {
      // Портрет — украшение: если что-то пошло не так, остаётся пустая рама,
      // но игра продолжает работать.
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.expand();
    return CustomPaint(painter: _Painter(image), size: Size.infinite);
  }
}

class _Painter extends CustomPainter {
  final ui.Image image;
  const _Painter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // cover: заполняем область целиком, лишнее обрезаем по центру.
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = (size.width / iw) > (size.height / ih)
        ? size.width / iw
        : size.height / ih;
    final w = iw * scale;
    final h = ih * scale;
    final dst = Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw, ih),
      dst,
      // Без сглаживания — иначе пиксели размажет и весь смысл пропадёт.
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_Painter oldDelegate) => oldDelegate.image != image;
}
