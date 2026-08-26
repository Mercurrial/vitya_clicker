import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Портрет Вити, приведённый к стилю игры.
///
/// Фотография в нарисованном мире читается как чужеродная вставка. Шейдер
/// сводит её к нескольким тонам гаражной палитры — получается печатный
/// портрет (шелкография / агитплакат), который живёт с гаражом в одном
/// визуальном языке. Витя при этом остаётся узнаваемым: меняется подача,
/// а не человек.
///
/// Если шейдер по какой-то причине не поднялся, показывается обычное фото —
/// игра не должна ломаться из-за украшения.
class PosterPortrait extends StatefulWidget {
  final String asset;

  /// Сколько тонов оставить. 3 — жёсткий плакат, 5 — мягче.
  final double levels;

  /// 0 — просто чёрно-белая постеризация, 1 — полностью медно-янтарная.
  final double warm;

  /// Ширина портрета в «крупных пикселях». 0 — без пикселизации,
  /// 48–64 — спрайтовый вид, который живёт в одном языке с гаражом.
  final double pixels;

  final BoxFit fit;

  const PosterPortrait({
    super.key,
    required this.asset,
    this.levels = 4,
    this.warm = 1,
    this.pixels = 0,
    this.fit = BoxFit.cover,
  });

  @override
  State<PosterPortrait> createState() => _PosterPortraitState();
}

class _PosterPortraitState extends State<PosterPortrait> {
  static ui.FragmentProgram? _program;
  static final Map<String, ui.Image> _images = {};

  ui.FragmentShader? _shader;
  ui.Image? _image;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(PosterPortrait old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) _prepare();
  }

  Future<void> _prepare() async {
    try {
      _program ??= await ui.FragmentProgram.fromAsset('shaders/poster.frag');

      var image = _images[widget.asset];
      if (image == null) {
        final data = await rootBundle.load(widget.asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        image = (await codec.getNextFrame()).image;
        _images[widget.asset] = image;
      }

      if (!mounted) return;
      setState(() {
        _image = image;
        _shader = _program!.fragmentShader();
      });
    } catch (_) {
      // Украшение не обязано работать везде — откатываемся на обычное фото.
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _shader == null || _image == null) {
      return Image.asset(widget.asset, fit: widget.fit);
    }
    return CustomPaint(
      painter: _PosterPainter(
        shader: _shader!,
        image: _image!,
        levels: widget.levels,
        warm: widget.warm,
        pixels: widget.pixels,
      ),
      size: Size.infinite,
    );
  }
}

class _PosterPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image image;
  final double levels;
  final double warm;
  final double pixels;

  _PosterPainter({
    required this.shader,
    required this.image,
    required this.levels,
    required this.warm,
    required this.pixels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Порядок uniform'ов должен совпадать с объявлением в poster.frag.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, levels)
      ..setFloat(3, warm)
      ..setFloat(4, pixels)
      ..setImageSampler(0, image);

    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = shader);
    // На пиксельном портрете растр только мешает — клетки уже крупные.
    if (pixels <= 1) _drawHalftone(canvas, size);
  }

  /// Редкая точечная сетка поверх — она добавляет ощущение печати и
  /// маскирует ступени постеризации на щеках.
  void _drawHalftone(Canvas canvas, Size size) {
    const step = 4.0;
    final dot = Paint()..color = const Color(0x14000000);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.6, dot);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PosterPainter old) =>
      old.image != image ||
      old.levels != levels ||
      old.warm != warm ||
      old.pixels != pixels;
}
