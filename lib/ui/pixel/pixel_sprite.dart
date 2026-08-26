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

  @override
  void paint(Canvas canvas, Size size) {
    if (sprite.width == 0 || size.isEmpty) return;

    // Целое число пикселей на клетку — иначе появляются швы и дрожание.
    final scale = (size.width / sprite.width).floorToDouble().clamp(1.0, 64.0);
    final drawnW = sprite.width * scale;
    final drawnH = sprite.height * scale;
    final ox = ((size.width - drawnW) / 2).floorToDouble();
    final oy = ((size.height - drawnH) / 2).floorToDouble();

    final paint = Paint()..isAntiAlias = false;

    for (var y = 0; y < sprite.height; y++) {
      final row = sprite.rows[y];
      final shift = rowShift?.call(y) ?? 0;
      for (var x = 0; x < row.length; x++) {
        final color = palette[row[x]];
        if (color == null) continue; // '.' и незнакомые символы — прозрачно
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            ox + (x + shift) * scale,
            oy + y * scale,
            scale,
            scale,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PixelPainter oldDelegate) =>
      oldDelegate.sprite != sprite || oldDelegate.rowShift != rowShift;
}

/// Виджет-обёртка вокруг [PixelPainter].
class PixelImage extends StatelessWidget {
  final PixelSprite sprite;
  final double size;
  final int Function(int row)? rowShift;

  const PixelImage({
    super.key,
    required this.sprite,
    required this.size,
    this.rowShift,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * (sprite.height / sprite.width),
      child: CustomPaint(
        painter: PixelPainter(sprite: sprite, rowShift: rowShift),
        size: Size.infinite,
      ),
    );
  }
}
