import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Во что превратился гараж.
///
/// Плейтест поймал главную претензию к сцене: «комната не отражает масштаб».
/// Аппараты росли от банки до коллайдера, а стена за ними всё это время
/// оставалась той же. Стадия — это ответ: помещение перестраивается вместе с
/// делом, и по одному взгляду на стену понятно, как далеко Витя зашёл.
enum GarageStage {
  /// Кирпич, календарь, канистра в углу, одна лампочка на проводе.
  garage,

  /// Крашеная панель по низу стены, трубы под потолком, щиток, плакат по ТБ.
  shop,

  /// Стальные панели, окно в ночь, приборы, жёлто-чёрная разметка.
  plant,
}

/// Стадия по самому старшему купленному аппарату.
///
/// Считаем именно по старшему, а не по количеству: помещение перестраивают,
/// когда появляется техника, которая в прежнее уже не влезает.
GarageStage stageForTier(int highestTier) {
  if (highestTier >= 9) return GarageStage.plant;
  if (highestTier >= 5) return GarageStage.shop;
  return GarageStage.garage;
}

/// Название стадии — для объявления о переезде.
String stageName(GarageStage stage) => switch (stage) {
      GarageStage.garage => 'ГАРАЖ',
      GarageStage.shop => 'ЦЕХ',
      GarageStage.plant => 'ПРОИЗВОДСТВО',
    };

/// Высота полосы пола. Задана в пикселях, а не в долях высоты: нижний ряд
/// аппаратов должен стоять ровно на полу, а сцена меняет размер вместе с
/// экраном — от долей ряд бы «всплывал» на больших телефонах.
const double kFloorHeight = 26;

/// Размер пикселя обстановки. Кирпич, календарь и трубы рисуются той же
/// «зернистостью», что и аппараты на полках — иначе гладкая векторная стена
/// за пиксельными спрайтами выглядела бы фоном из другой игры.
const double _u = 2;

/// Неподвижный слой: стена, пол, обстановка.
///
/// Вынесен отдельно от света намеренно. Сцена перерисовывается каждый кадр
/// ради качающейся лампы, и гонять по кирпичам 60 раз в секунду незачем —
/// здесь `shouldRepaint` срабатывает только при смене стадии.
class RoomBackground extends StatelessWidget {
  final GarageStage stage;

  const RoomBackground({super.key, required this.stage});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _RoomPainter(stage), size: Size.infinite);
}

class _RoomPainter extends CustomPainter {
  final GarageStage stage;

  _RoomPainter(this.stage);

  final Paint _p = Paint()..isAntiAlias = false;

  /// Прямоугольник в клетках пиксельной сетки.
  void _px(Canvas c, double x, double y, double w, double h, Color color) {
    _p.color = color;
    c.drawRect(
      Rect.fromLTWH(
        (x / _u).floorToDouble() * _u,
        (y / _u).floorToDouble() * _u,
        (w / _u).ceilToDouble() * _u,
        (h / _u).ceilToDouble() * _u,
      ),
      _p,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final floorY = ((size.height - kFloorHeight) / _u).floorToDouble() * _u;
    _paintWall(canvas, size, floorY);
    switch (stage) {
      case GarageStage.garage:
        _paintGarageProps(canvas, size, floorY);
      case GarageStage.shop:
        _paintShopProps(canvas, size, floorY);
      case GarageStage.plant:
        _paintPlantProps(canvas, size, floorY);
    }
    _paintFloor(canvas, size, floorY);
    _paintVignette(canvas, size);
  }

  // --- Стена -------------------------------------------------------------

  void _paintWall(Canvas canvas, Size size, double floorY) {
    switch (stage) {
      case GarageStage.garage:
        _paintBricks(canvas, size.width, floorY, const [
          Color(0xFF3B2A1F),
          Color(0xFF412E22),
          Color(0xFF36271D),
          Color(0xFF45301F),
          Color(0xFF3E2B21),
        ], const Color(0xFF231911));
      case GarageStage.shop:
        // Кирпич побелен сверху, по низу — крашеная панель, как во всех
        // мастерских. Панель мгновенно читается как «помещение обжитое».
        _paintBricks(canvas, size.width, floorY, const [
          Color(0xFF4A4238),
          Color(0xFF4F463B),
          Color(0xFF453D34),
          Color(0xFF524839),
        ], const Color(0xFF2E2923));
        final top = floorY - 58;
        _px(canvas, 0, top, size.width, floorY - top, const Color(0xFF2F3B2C));
        _px(canvas, 0, top, size.width, _u, const Color(0xFF465842));
        _px(canvas, 0, top + _u, size.width, _u, const Color(0xFF1E261C));
        // Облупившаяся краска.
        final chip = math.Random(3);
        for (var i = 0; i < 9; i++) {
          _px(
            canvas,
            chip.nextDouble() * size.width,
            top + 6 + chip.nextDouble() * 40,
            _u * (1 + chip.nextInt(3)),
            _u,
            const Color(0xFF3C4A38),
          );
        }
      case GarageStage.plant:
        _paintPanels(canvas, size.width, floorY);
    }
  }

  void _paintBricks(
    Canvas canvas,
    double width,
    double floorY,
    List<Color> tones,
    Color mortar,
  ) {
    _px(canvas, 0, 0, width, floorY, mortar);

    const bw = 24.0, bh = 10.0;
    final rnd = math.Random(5);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width, floorY));
    for (var y = 0.0, row = 0; y < floorY; y += bh, row++) {
      final offset = row.isEven ? 0.0 : -bw / 2;
      for (var x = offset; x < width; x += bw) {
        final tone = tones[rnd.nextInt(tones.length)];
        // Кирпич без шва: шов — это просвет подложки между ними.
        _px(canvas, x, y, bw - _u, bh - _u, tone);
        // Верхняя грань ловит свет лампы, нижняя уходит в тень — и кладка
        // становится рельефной, а не нарисованной.
        _px(canvas, x, y, bw - _u, _u, Color.lerp(tone, const Color(0xFFFFE0B0), 0.10)!);
        _px(canvas, x, y + bh - 2 * _u, bw - _u, _u, Color.lerp(tone, const Color(0xFF000000), 0.18)!);
        // Скол на каждом десятом.
        if (rnd.nextInt(10) == 0) {
          _px(canvas, x + _u * (1 + rnd.nextInt(8)), y + _u, _u * 2, _u, mortar);
        }
      }
    }
    canvas.restore();

    // Сырость: пятна всегда на одних и тех же местах — генератор с постоянным
    // зерном, поэтому стена не «дышит» между кадрами.
    final damp = math.Random(11);
    final stain = Paint()..color = const Color(0x16000000);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(damp.nextDouble() * width, damp.nextDouble() * floorY * 0.8),
        18 + damp.nextDouble() * 26,
        stain,
      );
    }
  }

  void _paintPanels(Canvas canvas, double width, double floorY) {
    _px(canvas, 0, 0, width, floorY, const Color(0xFF232830));
    const ph = 40.0;
    for (var y = 0.0; y < floorY; y += ph) {
      // Лист чуть светлее сверху: свет падает из-под потолка.
      _px(canvas, 0, y, width, _u, const Color(0xFF30363F));
      _px(canvas, 0, y + ph - _u, width, _u, const Color(0xFF15181D));
      for (var x = 10.0; x < width; x += 36) {
        _px(canvas, x, y + 4, _u, _u, const Color(0xFF48505B));
        _px(canvas, x, y + ph - 8, _u, _u, const Color(0xFF48505B));
      }
    }
    for (final jx in [width * 0.31, width * 0.69]) {
      _px(canvas, jx, 0, _u, floorY, const Color(0xFF15181D));
      _px(canvas, jx + _u, 0, _u, floorY, const Color(0xFF30363F));
    }
  }

  // --- Пол -----------------------------------------------------------------

  void _paintFloor(Canvas canvas, Size size, double floorY) {
    final base = switch (stage) {
      GarageStage.garage => const Color(0xFF1A140F),
      GarageStage.shop => const Color(0xFF1C1A16),
      GarageStage.plant => const Color(0xFF15181C),
    };
    _px(canvas, 0, floorY, size.width, size.height - floorY, base);

    // Плинтус-тень в углу и светлая кромка: без них пол читался продолжением
    // стены, и аппараты висели в воздухе.
    _px(canvas, 0, floorY, size.width, _u, const Color(0xFF0C0907));
    _px(canvas, 0, floorY + _u, size.width, _u, const Color(0x33FFD089));

    switch (stage) {
      case GarageStage.garage:
        // Бетон: крошка и масляное пятно, которое никто не оттёр.
        final grit = math.Random(17);
        for (var i = 0; i < 40; i++) {
          _px(
            canvas,
            grit.nextDouble() * size.width,
            floorY + 6 + grit.nextDouble() * (size.height - floorY - 6),
            _u,
            _u,
            const Color(0xFF231B14),
          );
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * 0.3, floorY + 15),
            width: 46,
            height: 8,
          ),
          Paint()..color = const Color(0x40000000),
        );
      case GarageStage.shop:
        // Метлахская плитка.
        for (var x = 0.0; x < size.width; x += 16) {
          _px(canvas, x, floorY + 4, _u / 2, size.height, const Color(0xFF26231E));
        }
        _px(canvas, 0, floorY + 14, size.width, _u / 2, const Color(0xFF26231E));
      case GarageStage.plant:
        // Жёлто-чёрная разметка вдоль стены и решётка.
        for (var x = 0.0; x < size.width; x += 12) {
          _px(canvas, x, floorY + 4, 6, 4, const Color(0xFFB8922E));
          _px(canvas, x + 6, floorY + 4, 6, 4, const Color(0xFF1A1A1A));
        }
        for (var x = 4.0; x < size.width; x += 10) {
          _px(canvas, x, floorY + 10, _u / 2, size.height, const Color(0xFF20252B));
        }
    }

    // Затемнение вглубь — последним, поверх фактуры.
    final rect = Rect.fromLTRB(0, floorY + 4, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x66000000)],
        ).createShader(rect),
    );
  }

  /// Углы темнее середины: свет от одной лампочки до них не добивает.
  void _paintVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.3),
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x8C000000)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
  }

  // --- Обстановка по стадиям ---------------------------------------------

  void _paintGarageProps(Canvas canvas, Size size, double floorY) {
    // Отрывной календарь на гвозде — время тут идёт, но медленно.
    _calendar(canvas, 12, 12);

    // Провод от выключателя, провисший между гвоздями: проводку в гараже
    // делал сам хозяин.
    final switchX = (size.width * 0.3 / _u).floorToDouble() * _u;
    canvas.drawPath(
      Path()
        ..moveTo(switchX + 4, 20)
        ..quadraticBezierTo(switchX + 4 - 14, 34, switchX + 4 - 30, 26)
        ..quadraticBezierTo(switchX + 4 - 42, 20, 44, 34),
      Paint()
        ..color = const Color(0xFF120D09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _px(canvas, switchX, 12, 10, 12, const Color(0xFFB8AE9C));
    _px(canvas, switchX, 22, 10, _u, const Color(0xFF8E8578));
    _px(canvas, switchX + 4, 14, _u, 6, const Color(0xFF5E5750));

    // Канистра в правом углу и ящик в левом.
    _jerrycan(canvas, size.width - 30, floorY - 22);
    _crate(canvas, 6, floorY - 18, 30, 18);
  }

  void _paintShopProps(Canvas canvas, Size size, double floorY) {
    // Трубы под потолком с хомутами.
    for (final y in [4.0, 12.0]) {
      _px(canvas, 0, y, size.width, 6, const Color(0xFF4E453C));
      _px(canvas, 0, y, size.width, _u, const Color(0xFF6E655A));
      _px(canvas, 0, y + 4, size.width, _u, const Color(0xFF2E2822));
    }
    for (var x = 24.0; x < size.width; x += 64) {
      _px(canvas, x, 2, 4, 18, const Color(0xFF2E2822));
    }

    // Плакат по технике безопасности.
    _px(canvas, 12, 28, 30, 38, const Color(0xFFD9CFB8));
    _px(canvas, 12, 28, 30, 8, const Color(0xFFA8402A));
    for (var y = 40.0; y < 62; y += 4) {
      _px(canvas, 16, y, 22, _u, const Color(0xFF8E8578));
    }

    // Электрощиток.
    _px(canvas, size.width - 34, floorY - 100, 24, 30, const Color(0xFF3E4A3A));
    _px(canvas, size.width - 34, floorY - 100, 24, _u, const Color(0xFF55664F));
    _px(canvas, size.width - 26, floorY - 88, 8, 8, const Color(0xFFE8C020));
    _px(canvas, size.width - 24, floorY - 86, 4, 4, const Color(0xFF1A1A1A));

    _crate(canvas, 6, floorY - 22, 36, 22);
    _jerrycan(canvas, size.width - 30, floorY - 22);
  }

  void _paintPlantProps(Canvas canvas, Size size, double floorY) {
    // Окно в ночь. Единственное место, где в сцене есть холодный цвет —
    // поэтому оно и работает: снаружи холодно, внутри тепло.
    const win = Rect.fromLTWH(14, 14, 62, 40);
    _px(canvas, win.left - 4, win.top - 4, win.width + 8, win.height + 8, const Color(0xFF3A3F47));
    _px(canvas, win.left, win.top, win.width, win.height, const Color(0xFF0B1220));
    final stars = math.Random(23);
    for (var i = 0; i < 14; i++) {
      _px(
        canvas,
        win.left + stars.nextDouble() * win.width,
        win.top + stars.nextDouble() * win.height,
        _u,
        _u,
        Color.fromARGB(0x50 + stars.nextInt(0x90), 0xFF, 0xFF, 0xFF),
      );
    }
    // Луна.
    _px(canvas, win.right - 16, win.top + 6, 8, 8, const Color(0xFFE8E0C8));
    _px(canvas, win.right - 12, win.top + 6, 4, 4, const Color(0xFF0B1220));
    _px(canvas, win.center.dx - 1, win.top, _u, win.height, const Color(0xFF3A3F47));
    _px(canvas, win.left, win.center.dy - 1, win.width, _u, const Color(0xFF3A3F47));

    // Манометры.
    for (var i = 0; i < 3; i++) {
      final c = Offset(size.width - 26.0 - i * 24, floorY - 96);
      canvas.drawCircle(c, 9, Paint()..color = const Color(0xFF6E6459));
      canvas.drawCircle(c, 7, Paint()..color = const Color(0xFFEDE5D2));
      final angle = -2.3 + i * 0.8;
      canvas.drawLine(
        c,
        c + Offset(math.cos(angle), math.sin(angle)) * 6,
        Paint()
          ..color = const Color(0xFFA8402A)
          ..strokeWidth = 1.6,
      );
    }
    // Труба вдоль стены к приборам.
    _px(canvas, size.width - 80, floorY - 86, 70, 6, const Color(0xFF5E5750));
    _px(canvas, size.width - 80, floorY - 86, 70, _u, const Color(0xFF8E8578));
  }

  // --- Предметы ----------------------------------------------------------

  void _calendar(Canvas canvas, double x, double y) {
    _px(canvas, x + 12, y - 4, _u, 4, const Color(0xFF6E6459)); // гвоздь
    _px(canvas, x, y, 26, 30, const Color(0xFFD9CFB8));
    _px(canvas, x, y, 26, 8, const Color(0xFFA8402A));
    _px(canvas, x + 6, y + 2, 14, 4, const Color(0xFFEDE5D2));
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        _px(canvas, x + 3 + c * 4.4, y + 12 + r * 4.4, _u, _u,
            r == 2 && c == 3 ? const Color(0xFFA8402A) : const Color(0xFF8E8578));
      }
    }
    // Тень от листа.
    _px(canvas, x + 26, y + 2, _u, 30, const Color(0x40000000));
  }

  void _jerrycan(Canvas canvas, double x, double y) {
    _px(canvas, x, y + 4, 22, 18, const Color(0xFFA8402A));
    _px(canvas, x, y + 4, 22, _u, const Color(0xFFC85A3E));
    _px(canvas, x + 20, y + 4, _u, 18, const Color(0xFF6E2A1C));
    _px(canvas, x + 4, y, 10, 4, const Color(0xFF6E2A1C)); // ручка
    _px(canvas, x + 16, y, 4, 4, const Color(0xFF5E5750)); // горловина
    _px(canvas, x + 4, y + 10, 14, _u, const Color(0xFF6E2A1C)); // выштамповка
  }

  void _crate(Canvas canvas, double x, double y, double w, double h) {
    _px(canvas, x, y, w, h, const Color(0xFF5A3D25));
    _px(canvas, x, y, w, _u, const Color(0xFF7A5634));
    for (var yy = y + h / 3; yy < y + h - 1; yy += h / 3) {
      _px(canvas, x, yy, w, _u, const Color(0xFF3A2616));
    }
    _px(canvas, x, y, _u, h, const Color(0xFF3A2616));
    _px(canvas, x + w - _u, y, _u, h, const Color(0xFF3A2616));
  }

  @override
  bool shouldRepaint(_RoomPainter old) => old.stage != stage;
}

/// Лампочка на проводе и её свет.
///
/// Свет здесь — не украшение, а способ сделать сцену живой: пока лампа
/// покачивается, вся комната чуть дышит вместе с ней. Амплитуда растёт с
/// жаром — под аппаратами гудит огонь, воздух ходит.
class SwingingLamp extends StatelessWidget {
  final double time;
  final double heat;

  /// Точка подвеса в долях ширины. Не по центру: там висит портрет, а лампа
  /// перед ним смотрелась бы нимбом.
  final double pivotX;

  const SwingingLamp({
    super.key,
    required this.time,
    required this.heat,
    this.pivotX = 0.8,
  });

  /// Смещение лампы от точки подвеса. Вынесено, чтобы свет и сама лампочка
  /// считали одно и то же число, а не разъехались.
  static double swing(double time, double heat) {
    final amplitude = 4 + 6 * heat.clamp(0.0, 1.0);
    // Два периода вместо одного: маятник перестаёт выглядеть механическим.
    return amplitude * math.sin(time * 0.72) + amplitude * 0.3 * math.sin(time * 1.9);
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _LampPainter(time: time, heat: heat, pivotX: pivotX),
        size: Size.infinite,
      );
}

class _LampPainter extends CustomPainter {
  final double time;
  final double heat;
  final double pivotX;

  _LampPainter({required this.time, required this.heat, required this.pivotX});

  /// Готовый градиент света, посчитанный один раз на размер и яркость.
  ///
  /// Раньше шейдер собирался заново каждый кадр — а это самая дорогая
  /// операция в отрисовке. Свет при этом не меняет форму: он только ездит
  /// вместе с лампой. Значит, можно построить его однажды и двигать холст,
  /// а не пересобирать градиент шестьдесят раз в секунду.
  static ui.Shader? _cachedLight;
  static Size? _cachedSize;
  static int? _cachedWarmth;

  static ui.Shader _light(Size size, double warmth) {
    // Яркость округляем: на глаз шага в сотую не видно, а кэш от этого
    // перестаёт промахиваться на каждом кадре.
    final key = (warmth * 100).round();
    if (_cachedLight != null && _cachedSize == size && _cachedWarmth == key) {
      return _cachedLight!;
    }
    final rect = Offset.zero & size;
    _cachedLight = RadialGradient(
      center: Alignment.center,
      radius: 1.1,
      colors: [
        const Color(0xFFFFD089).withOpacity(key / 100),
        const Color(0xFFFFD089).withOpacity(key / 100 * 0.22),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.3, 1.0],
    ).createShader(rect);
    _cachedSize = size;
    _cachedWarmth = key;
    return _cachedLight!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pivot = Offset(size.width * pivotX, 0);
    final dx = SwingingLamp.swing(time, heat);
    final bulb = Offset(pivot.dx + dx, 40);

    // Свет. Форма постоянна, меняется только положение — поэтому двигаем
    // холст, а не пересобираем градиент.
    final warmth = 0.22 + 0.14 * heat.clamp(0.0, 1.0);
    final shift = Offset(bulb.dx - size.width / 2, bulb.dy - size.height / 2);
    canvas.save();
    canvas.translate(shift.dx, shift.dy);
    canvas.drawRect(
      // Расширяем на величину сдвига, иначе у края появится несвёченная полоса.
      (Offset.zero & size).inflate(size.longestSide),
      Paint()
        ..shader = _light(size, warmth)
        ..blendMode = BlendMode.plus,
    );
    canvas.restore();

    // Провод.
    canvas.drawPath(
      Path()
        ..moveTo(pivot.dx, pivot.dy)
        ..quadraticBezierTo(pivot.dx + dx * 0.35, bulb.dy * 0.6, bulb.dx, bulb.dy - 9),
      Paint()
        ..color = const Color(0xFF17110C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Патрон.
    final pin = Paint()..isAntiAlias = false;
    pin.color = const Color(0xFF2E2822);
    canvas.drawRect(Rect.fromCenter(center: bulb.translate(0, -8), width: 8, height: 8), pin);
    pin.color = const Color(0xFF4E453C);
    canvas.drawRect(Rect.fromCenter(center: bulb.translate(-2, -9), width: 2, height: 6), pin);

    // Лампочка. Ореол мягче самой колбы — иначе получается солнце.
    canvas.drawCircle(
      bulb,
      14,
      Paint()..color = const Color(0xFFFFD089).withOpacity(0.10 + 0.12 * heat.clamp(0.0, 1.0)),
    );
    canvas.drawCircle(bulb, 5.5, Paint()..color = const Color(0xFFFFE9BC));
    canvas.drawCircle(bulb.translate(-1.5, -1.5), 1.8, Paint()..color = const Color(0xFFFFFFFF));

    _paintDust(canvas, size, bulb);
  }

  /// Пыль в луче. Её почти не видно — и именно поэтому комната перестаёт быть
  /// плоской картинкой.
  void _paintDust(Canvas canvas, Size size, Offset bulb) {
    final rnd = math.Random(41);
    final paint = Paint();
    for (var i = 0; i < 18; i++) {
      final baseX = rnd.nextDouble() * size.width;
      final speed = 6 + rnd.nextDouble() * 10;
      final phase = rnd.nextDouble() * 100;
      // Пылинка медленно оседает и сносится вбок, потом появляется сверху.
      final y = (phase + time * speed) % (size.height + 20) - 10;
      final x = baseX + math.sin(time * 0.5 + phase) * 6;

      final distance = (Offset(x, y) - bulb).distance;
      final lit = (1 - distance / (size.height * 0.9)).clamp(0.0, 1.0);
      if (lit <= 0.02) continue;
      paint.color = const Color(0xFFFFE9BC).withOpacity(0.28 * lit * lit);
      canvas.drawRect(Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 2, 2), paint);
    }
  }

  @override
  bool shouldRepaint(_LampPainter old) => old.time != time || old.heat != heat;
}
