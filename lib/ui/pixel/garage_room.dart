import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Во что превратился гараж.
///
/// Плейтест поймал главную претензию к сцене: «комната не отражает масштаб».
/// Аппараты росли от банки до коллайдера, а стена за ними всё это время
/// оставалась той же. Стадия — это ответ: помещение перестраивается вместе с
/// делом, и по одному взгляду на стену понятно, как далеко Витя зашёл.
enum GarageStage {
  /// Кирпич, сырость, одна лампочка на проводе.
  garage,

  /// Крашеная панель по низу стены, трубы под потолком, вытяжка.
  shop,

  /// Стальные панели, окно в ночь, приборы. Гаражом тут уже не пахнет.
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

/// Название стадии — показываем в углу сцены.
String stageName(GarageStage stage) => switch (stage) {
      GarageStage.garage => 'ГАРАЖ',
      GarageStage.shop => 'ЦЕХ',
      GarageStage.plant => 'ПРОИЗВОДСТВО',
    };

/// Высота полосы пола. Задана в пикселях, а не в долях высоты: нижний ряд
/// аппаратов должен стоять ровно на полу, а сцена меняет размер вместе с
/// экраном — от долей ряд бы «всплывал» на больших телефонах.
const double kFloorHeight = 22;

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

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = (size.height - kFloorHeight).floorToDouble();
    _paintWall(canvas, size, floorY);
    _paintFloor(canvas, size, floorY);
    switch (stage) {
      case GarageStage.garage:
        _paintGarageProps(canvas, size, floorY);
      case GarageStage.shop:
        _paintShopProps(canvas, size, floorY);
      case GarageStage.plant:
        _paintPlantProps(canvas, size, floorY);
    }
  }

  void _paintWall(Canvas canvas, Size size, double floorY) {
    final wall = Rect.fromLTWH(0, 0, size.width, floorY);
    canvas.drawRect(wall, Paint()..color = _wallBase);

    if (stage == GarageStage.plant) {
      _paintPanels(canvas, wall);
    } else {
      _paintBricks(canvas, wall);
    }

    // Крашеная панель по низу — так красили все мастерские, и это мгновенно
    // читается как «помещение обжитое», а не «стена».
    if (stage == GarageStage.shop) {
      final top = floorY - 40;
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, floorY),
        Paint()..color = const Color(0xE6222B20),
      );
      // Ободок по верху панели: краску всегда вели по линейке, и эта линия —
      // главное, по чему панель узнаётся.
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, top + 2),
        Paint()..color = const Color(0xFF35452F),
      );
    }

    // Сырость. Пятна всегда на одних и тех же местах: генератор с постоянным
    // зерном, поэтому стена не «дышит» между кадрами.
    final damp = math.Random(11);
    final stain = Paint()..color = const Color(0x0E000000);
    for (var i = 0; i < 7; i++) {
      final x = damp.nextDouble() * size.width;
      final y = damp.nextDouble() * floorY * 0.8;
      final r = 14 + damp.nextDouble() * 26;
      canvas.drawCircle(Offset(x, y), r, stain);
    }
  }

  void _paintBricks(Canvas canvas, Rect wall) {
    const bw = 26.0, bh = 13.0;
    final tint = math.Random(5);
    final brick = Paint();
    canvas.save();
    canvas.clipRect(wall);
    for (var y = 0.0, r = 0; y < wall.height; y += bh, r++) {
      final offset = r.isEven ? 0.0 : bw / 2;
      for (var x = -bw; x < wall.width; x += bw) {
        // Каждый кирпич чуть своего оттенка — ровная сетка выглядит как обои,
        // а не как кладка.
        final shade = 0x0A + (tint.nextDouble() * 0x12).round();
        brick.color = Color.fromARGB(shade, 0xFF, 0xFF, 0xFF);
        canvas.drawRect(
          Rect.fromLTWH(x + offset + 1, y + 1, bw - 2, bh - 2),
          brick,
        );
      }
    }
    canvas.restore();
  }

  void _paintPanels(Canvas canvas, Rect wall) {
    // Панели кладутся рядами. Вертикальных швов почти нет намеренно: равномерная
    // сетка из горизонталей и вертикалей читается как миллиметровка, а не как
    // обшивка — проверено на снимке.
    const ph = 38.0;
    final seam = Paint()
      ..color = const Color(0x26000000)
      ..strokeWidth = 2;
    final lip = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = 1;
    final rivet = Paint()..color = const Color(0x1EFFFFFF);

    for (var y = ph; y < wall.height; y += ph) {
      canvas.drawLine(Offset(0, y), Offset(wall.width, y), seam);
      // Верхняя кромка следующего листа ловит свет — по ней и читается объём.
      canvas.drawLine(Offset(0, y + 1.5), Offset(wall.width, y + 1.5), lip);
      for (var x = 12.0; x < wall.width; x += 34) {
        canvas.drawCircle(Offset(x, y - 5), 1.1, rivet);
      }
    }

    // Один вертикальный стык — чтобы стена не выглядела бесконечной лентой.
    final joint = wall.width * 0.38;
    canvas.drawLine(Offset(joint, 0), Offset(joint, wall.height), seam);
    canvas.drawLine(Offset(joint + 1.5, 0), Offset(joint + 1.5, wall.height), lip);
  }

  void _paintFloor(Canvas canvas, Size size, double floorY) {
    canvas.drawRect(
      Rect.fromLTRB(0, floorY, size.width, size.height),
      Paint()..color = _floorBase,
    );

    // Пол обязан читаться как отдельная плоскость. На первом снимке он
    // отличался от стены на пару единиц яркости и выглядел продолжением
    // кладки — аппараты висели в воздухе. Отсюда три полосы: тень в углу,
    // светлая кромка и мягкое затемнение вглубь.
    canvas.drawRect(
      Rect.fromLTRB(0, floorY, size.width, floorY + 3),
      Paint()..color = const Color(0x59000000),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, floorY + 3, size.width, floorY + 4),
      Paint()..color = const Color(0x1FFFD089),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, floorY + 4, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x4D000000)],
        ).createShader(
          Rect.fromLTRB(0, floorY + 4, size.width, size.height),
        ),
    );

    if (stage == GarageStage.plant) {
      // Решётка — видно, что под ногами уже не земля.
      final grate = Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 1;
      for (var x = 6.0; x < size.width; x += 12) {
        canvas.drawLine(Offset(x, floorY + 5), Offset(x, size.height), grate);
      }
    } else {
      // Трещина в бетоне. Одна, кривая, на своём месте.
      final crack = Path()..moveTo(size.width * 0.18, size.height);
      crack
        ..lineTo(size.width * 0.24, floorY + 9)
        ..lineTo(size.width * 0.21, floorY + 5);
      canvas.drawPath(
        crack,
        Paint()
          ..color = const Color(0x2B000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  // --- Обстановка по стадиям ---------------------------------------------

  void _paintGarageProps(Canvas canvas, Size size, double floorY) {
    // Гвоздь с мотком проволоки: гараж — это место, где всё однажды
    // пригодится.
    final x = size.width * 0.12;
    final y = floorY - 96;
    canvas.drawRect(
      Rect.fromLTWH(x, y, 2, 2),
      Paint()..color = const Color(0xFF6E6459),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(x + 1, y + 11), radius: 8),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = const Color(0x3F8C7A5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    _paintCrate(canvas, Offset(size.width - 44, floorY - 20), 34, 20);
  }

  void _paintShopProps(Canvas canvas, Size size, double floorY) {
    // Трубы под потолком.
    final pipe = Paint()..color = const Color(0xFF4A4038);
    final shine = Paint()..color = const Color(0x1AFFFFFF);
    for (final y in [22.0, 30.0]) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 5), pipe);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), shine);
    }
    // Хомуты.
    for (var x = 30.0; x < size.width; x += 72) {
      canvas.drawRect(
        Rect.fromLTWH(x, 20, 4, 17),
        Paint()..color = const Color(0xFF5C5148),
      );
    }

    // Вытяжка.
    final vent = Rect.fromLTWH(size.width * 0.72, 46, 40, 26);
    canvas.drawRect(vent, Paint()..color = const Color(0xFF2A2621));
    canvas.drawRect(
      vent.deflate(1),
      Paint()
        ..color = const Color(0xFF454039)
        ..style = PaintingStyle.stroke,
    );
    final slat = Paint()..color = const Color(0x26000000);
    for (var y = vent.top + 4; y < vent.bottom - 2; y += 5) {
      canvas.drawRect(Rect.fromLTWH(vent.left + 3, y, vent.width - 6, 2), slat);
    }

    _paintCrate(canvas, Offset(14, floorY - 24), 40, 24);
    _paintCrate(canvas, Offset(size.width - 52, floorY - 18), 40, 18);
  }

  void _paintPlantProps(Canvas canvas, Size size, double floorY) {
    // Окно в ночь. Единственное место, где в сцене есть холодный цвет —
    // поэтому оно и работает: снаружи холодно, внутри тепло.
    final win = Rect.fromLTWH(size.width * 0.66, 34, 76, 46);
    canvas.drawRect(
      win.inflate(3),
      Paint()..color = const Color(0xFF3A3A3E),
    );
    canvas.drawRect(win, Paint()..color = const Color(0xFF0C1220));
    final stars = math.Random(23);
    for (var i = 0; i < 16; i++) {
      final p = Offset(
        win.left + stars.nextDouble() * win.width,
        win.top + stars.nextDouble() * win.height,
      );
      // Звёзды разной яркости: одинаковые читаются как дырки в картоне.
      canvas.drawRect(
        Rect.fromLTWH(p.dx, p.dy, 1.2, 1.2),
        Paint()..color = Color.fromARGB(0x50 + stars.nextInt(0x70), 0xFF, 0xFF, 0xFF),
      );
    }
    final frame = Paint()
      ..color = const Color(0xFF3A3A3E)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(win.center.dx, win.top),
      Offset(win.center.dx, win.bottom),
      frame,
    );
    canvas.drawLine(
      Offset(win.left, win.center.dy),
      Offset(win.right, win.center.dy),
      frame,
    );

    // Манометры на стене.
    for (var i = 0; i < 3; i++) {
      final c = Offset(30.0 + i * 26, 46);
      canvas.drawCircle(c, 8, Paint()..color = const Color(0xFF2A2621));
      canvas.drawCircle(
        c,
        8,
        Paint()
          ..color = const Color(0xFF6E6459)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      final angle = -2.2 + i * 0.7;
      canvas.drawLine(
        c,
        c + Offset(math.cos(angle), math.sin(angle)) * 5.5,
        Paint()
          ..color = const Color(0xFFE8A33D)
          ..strokeWidth = 1.4,
      );
    }
  }

  void _paintCrate(Canvas canvas, Offset at, double w, double h) {
    final r = Rect.fromLTWH(at.dx, at.dy, w, h);
    canvas.drawRect(r, Paint()..color = const Color(0xFF4A3524));
    canvas.drawRect(
      r,
      Paint()
        ..color = const Color(0xFF6B4E33)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Доски.
    final board = Paint()
      ..color = const Color(0x1F000000)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(r.left + 2, r.top + h / 2),
      Offset(r.right - 2, r.top + h / 2),
      board,
    );
    canvas.drawLine(
      Offset(r.left + w / 2, r.top + 2),
      Offset(r.left + w / 2, r.bottom - 2),
      board,
    );
  }

  Color get _wallBase => switch (stage) {
        GarageStage.garage => const Color(0xFF241C15),
        GarageStage.shop => const Color(0xFF232019),
        GarageStage.plant => const Color(0xFF1B1F24),
      };

  /// Пол заметно темнее стены: на него не падает свет лампы, и именно этот
  /// перепад делает его полом, а не нижней частью стены.
  Color get _floorBase => switch (stage) {
        GarageStage.garage => const Color(0xFF130F0A),
        GarageStage.shop => const Color(0xFF151410),
        GarageStage.plant => const Color(0xFF101316),
      };

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
    this.pivotX = 0.82,
  });

  /// Смещение лампы от точки подвеса. Вынесено, чтобы свет и сама лампочка
  /// считали одно и то же число, а не разъехались.
  static double swing(double time, double heat) {
    final amplitude = 5 + 7 * heat.clamp(0.0, 1.0);
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pivot = Offset(size.width * pivotX, 0);
    final dx = SwingingLamp.swing(time, heat);
    final bulb = Offset(pivot.dx + dx, 34);

    // Свет. Идёт от лампочки и ездит вместе с ней.
    final warmth = 0.28 + 0.16 * heat.clamp(0.0, 1.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (bulb.dx / size.width) * 2 - 1,
            (bulb.dy / size.height) * 2 - 1,
          ),
          radius: 1.25,
          colors: [
            const Color(0xFFFFD089).withOpacity(warmth),
            const Color(0xFFFFD089).withOpacity(warmth * 0.25),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.28, 1.0],
        ).createShader(Offset.zero & size),
    );

    // Провод.
    canvas.drawPath(
      Path()
        ..moveTo(pivot.dx, pivot.dy)
        ..quadraticBezierTo(pivot.dx + dx * 0.35, bulb.dy * 0.6, bulb.dx, bulb.dy - 7),
      Paint()
        ..color = const Color(0xFF3A322A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Патрон.
    canvas.drawRect(
      Rect.fromCenter(center: bulb.translate(0, -8), width: 7, height: 7),
      Paint()..color = const Color(0xFF5C5148),
    );

    // Сама лампочка. Ореол рисуем отдельно и мягче — иначе получается солнце.
    canvas.drawCircle(
      bulb,
      13,
      Paint()..color = const Color(0xFFFFD089).withOpacity(0.10 + 0.10 * heat),
    );
    canvas.drawCircle(bulb, 5, Paint()..color = const Color(0xFFFFE9BC));
    canvas.drawCircle(
      bulb.translate(-1.4, -1.4),
      1.6,
      Paint()..color = const Color(0xFFFFFFFF),
    );

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
      paint.color = const Color(0xFFFFE9BC).withOpacity(0.24 * lit * lit);
      canvas.drawRect(Rect.fromLTWH(x, y, 1.4, 1.4), paint);
    }
  }

  @override
  bool shouldRepaint(_LampPainter old) => old.time != time || old.heat != heat;
}
