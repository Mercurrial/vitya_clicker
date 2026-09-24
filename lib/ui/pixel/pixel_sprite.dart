import 'package:flutter/widgets.dart';

/// Пиксельная графика, нарисованная прямо в коде.
///
/// Спрайт — это сетка символов плюс палитра. Такой формат читается и правится
/// глазами прямо в исходнике, не требует художника и графических файлов, а на
/// экране даёт честные квадратные пиксели.
class PixelSprite {
  /// Строки одинаковой длины; каждый символ — ключ палитры.
  final List<String> rows;

  const PixelSprite(this.rows);

  int get height => rows.length;
  int get width => rows.isEmpty ? 0 : rows.first.length;
}

/// Общая палитра гаража. Ключи короткие, чтобы спрайт оставался читаемым.
///
/// `.` — прозрачно.
const Map<String, Color> kGaragePalette = {
  'k': Color(0xFF1A1410), // контур, тень
  'K': Color(0xFF2E241A), // мягкая тень
  'm': Color(0xFF6E6459), // металл
  'M': Color(0xFF9A8F80), // металл на свету
  'c': Color(0xFF8C5430), // медь в тени
  'C': Color(0xFFC87941), // медь
  'a': Color(0xFFE8A33D), // латунь, янтарь
  'g': Color(0xFF3B4A47), // стекло в тени
  'G': Color(0xFF5E7A73), // стекло
  'b': Color(0xFFD8C48A), // брага
  'B': Color(0xFFF2E2B8), // самогон на свету
  'w': Color(0xFFFFF3D6), // блик
  'r': Color(0xFF8E3B22), // ржавчина
  'f': Color(0xFFFF8A00), // огонь
  'F': Color(0xFFFFD089), // пламя на свету
  's': Color(0x593B4A47), // пар (полупрозрачный)
};

/// Рисует спрайт квадратными пикселями без сглаживания.
class PixelPainter extends CustomPainter {
  final PixelSprite sprite;
  final Map<String, Color> palette;

  /// Сдвиг отдельных строк — дешёвый способ анимации (кипение, дрожь).
  final int Function(int row)? rowShift;

  const PixelPainter({
    required this.sprite,
    this.palette = kGaragePalette,
    this.rowShift,
  });

  /// Рисует спрайт двумя приёмами, и оба нужны.
  ///
  /// **Слияние в отрезки.** Подряд идущие пиксели одного символа — это один
  /// прямоугольник, а не десять. В спрайтах гаража таких полос много: корпус,
  /// жидкость, тени.
  ///
  /// **Группировка по цвету.** Отрезки собираются в контур на каждый цвет и
  /// уходят одним вызовом. Палитра маленькая, поэтому вместо сотен вызовов
  /// получается около десятка.
  ///
  /// Замер до правки: один аппарат стоил 67 мкс — 84 % отведённого бюджета,
  /// и это на настольной машине. Шесть аппаратов по шестьдесят кадров в
  /// секунду телефон бы не вытянул.
  @override
  void paint(Canvas canvas, Size size) {
    if (sprite.width == 0 || size.isEmpty) return;

    // Клетка кратна половине точки. На телефоне это целое число физических
    // пикселей (там их два-три на точку), поэтому швов нет, а спрайт можно
    // вписать плотнее, чем при целых точках: фляга в значке списка выходила
    // вдвое мельче банки только потому, что 1.7 округлялось до единицы.
    final scale = ((size.width / sprite.width) * 2).floorToDouble().clamp(2.0, 128.0) / 2;
    final drawnW = sprite.width * scale;
    final drawnH = sprite.height * scale;
    final ox = ((size.width - drawnW) / 2).floorToDouble();
    final oy = ((size.height - drawnH) / 2).floorToDouble();

    final byColour = <Color, Path>{};

    for (var y = 0; y < sprite.height; y++) {
      final row = sprite.rows[y];
      final shift = rowShift?.call(y) ?? 0;
      final top = oy + y * scale;

      var x = 0;
      while (x < row.length) {
        final symbol = row[x];
        final colour = palette[symbol];
        if (colour == null) {
          x++; // '.' и незнакомые символы — прозрачно
          continue;
        }

        var end = x + 1;
        while (end < row.length && row[end] == symbol) {
          end++;
        }

        (byColour[colour] ??= Path()).addRect(
          Rect.fromLTWH(ox + (x + shift) * scale, top, (end - x) * scale, scale),
        );
        x = end;
      }
    }

    final paint = Paint()..isAntiAlias = false;
    byColour.forEach((colour, path) {
      paint.color = colour;
      canvas.drawPath(path, paint);
    });
  }

  @override
  bool shouldRepaint(PixelPainter oldDelegate) =>
      oldDelegate.sprite != sprite ||
      oldDelegate.rowShift != rowShift ||
      oldDelegate.palette != palette;
}

/// Крупнейший размер клетки (с шагом в полточки), при котором спрайт
/// помещается в квадрат [box].
double pixelToFit(PixelSprite sprite, double box, {double max = 8}) {
  final side = sprite.width > sprite.height ? sprite.width : sprite.height;
  if (side == 0) return 1;
  return ((box / side) * 2).floorToDouble().clamp(2.0, max * 2) / 2;
}

/// Виджет-обёртка вокруг [PixelPainter].
class PixelImage extends StatelessWidget {
  final PixelSprite sprite;
  final double size;
  final int Function(int row)? rowShift;
  final Map<String, Color> palette;

  const PixelImage({
    super.key,
    required this.sprite,
    required this.size,
    this.rowShift,
    this.palette = kGaragePalette,
  });

  /// Спрайт с заданным размером пикселя, а не шириной.
  ///
  /// Для сцены это главное: аппараты разного размера обязаны рисоваться одним
  /// и тем же пикселем. Когда каждый подгонялся под свою ширину, банка
  /// выходила крупнозернистой, а цистерна — мелкой, и сцена рассыпалась на
  /// картинки из разных игр.
  factory PixelImage.scaled({
    Key? key,
    required PixelSprite sprite,
    required double pixel,
    Map<String, Color> palette = kGaragePalette,
  }) =>
      PixelImage(
        key: key,
        sprite: sprite,
        size: sprite.width * pixel,
        palette: palette,
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * (sprite.height / sprite.width),
      child: CustomPaint(
        painter: PixelPainter(sprite: sprite, rowShift: rowShift, palette: palette),
        size: Size.infinite,
      ),
    );
  }
}
