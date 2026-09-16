// Генератор иконок приложения.
//
// Иконка нарисована здесь же, пикселями, как и всё остальное искусство в игре —
// так она остаётся в репозитории текстом, её видно в диффе и можно поправить
// одним символом. Никаких бинарных ассетов, которые никто не решается тронуть.
//
// Запуск:  dart run tools/make_icons.dart
//
// Пишет PNG в android/app/src/main/res/mipmap-*/, web/icons/ и web/favicon.png.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Трёхлитровая банка — то, с чего Витя начинает.
///
/// Каждая строка обязана быть ровно [_side] символов; проверка ниже ловит
/// опечатку сразу, а не через три этапа сборки.
const List<String> _art = [
  '................................', // 0
  '................................',
  '................................',
  '................................',
  '...........llllllllll...........', // 4  крышка
  '...........lLLLLLLLLl...........',
  '...........llllllllll...........',
  '............#gggggg#............', // 7  горло
  '............#gggggg#............',
  '..........##gggggggg##..........', // 9  плечи
  '........##gggggggggggg##........',
  '........#gggggggggggggg#........', // 11 корпус
  '........#Gggggggggggggg#........',
  '........#Gggggggggggggg#........',
  '........#hAAAAAAAAAAAAd#........', // 14 зеркало самогона
  '........#hwaaaaaaaaaaAd#........',
  '........#hwaaaaaaaaaaad#........',
  '........#haaaaaaaaaaaad#........', // 17
  '........#haaaaaaaaaaaad#........',
  '........#haaaaaaaaaaaad#........',
  '........#haaaaaaaaaaaad#........',
  '........#haaaaaaaaaaaad#........',
  '........#haaaaaaaaaaaad#........',
  '........#haaaaaaaaaaaad#........',
  '........#haaaaaaaaaaaad#........',
  '........#haaaaaaaaaaaad#........', // 25
  '........#hddddddddddddd#........', // 26 осадок
  '........################........', // 27 дно
  '........,,,,,,,,,,,,,,,,........', // 28 тень
  '................................',
  '................................',
  '................................',
];

const int _side = 32;

/// Палитра — те же цвета, что и в `lib/ui/theme/garage.dart`.
const Map<String, int> _palette = {
  '.': 0xFF14100C, // фон гаража
  ',': 0xFF241A10, // тёплая тень под банкой
  '#': 0xFF3A2A1A, // кромка стекла
  'g': 0xFF2A2118, // пустое стекло
  'G': 0xFF8A7A66, // блик по стеклу выше уровня
  'h': 0xFFF2C173, // тот же блик, но сквозь самогон — значит тёплый
  'l': 0xFF8C5430, // крышка
  'L': 0xFFC87941, // блик на крышке
  'd': 0xFFB87C24, // самогон в тени
  'a': 0xFFE8A33D, // самогон
  'A': 0xFFFFD089, // зеркало жидкости
  'w': 0xFFF5EDE0, // блик
};

/// Куда и в каком размере класть результат.
const Map<String, int> _targets = {
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  // Заставка. Плотности заданы явно, иначе Android растянет один файл и
  // пиксель-арт поплывёт.
  'android/app/src/main/res/drawable-mdpi/launch_image.png': 72,
  'android/app/src/main/res/drawable-hdpi/launch_image.png': 108,
  'android/app/src/main/res/drawable-xhdpi/launch_image.png': 144,
  'android/app/src/main/res/drawable-xxhdpi/launch_image.png': 216,
  'android/app/src/main/res/drawable-xxxhdpi/launch_image.png': 288,
  'web/icons/Icon-192.png': 192,
  'web/icons/Icon-512.png': 512,
  'web/icons/Icon-maskable-192.png': 192,
  'web/icons/Icon-maskable-512.png': 512,
  'web/favicon.png': 32,
};

void main() {
  for (var y = 0; y < _art.length; y++) {
    if (_art[y].length != _side) {
      stderr.writeln('строка $y длиной ${_art[y].length}, а нужно $_side');
      exit(1);
    }
  }
  if (_art.length != _side) {
    stderr.writeln('строк ${_art.length}, а нужно $_side');
    exit(1);
  }

  final grid = _resolve();
  _targets.forEach((path, size) {
    final png = _encodePng(_scale(grid, size), size, size);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png);
    stdout.writeln('$path  ${size}x$size');
  });
}

/// Символы → цвета, плюс мягкое тёплое свечение по фону: иконка не должна
/// выглядеть наклейкой на чёрном квадрате.
Uint32List _resolve() {
  final out = Uint32List(_side * _side);
  const centre = (_side - 1) / 2;
  final maxDistance = math.sqrt(2 * centre * centre);

  for (var y = 0; y < _side; y++) {
    for (var x = 0; x < _side; x++) {
      final symbol = _art[y][x];
      var colour = _palette[symbol];
      if (colour == null) {
        stderr.writeln('неизвестный символ «$symbol» в строке $y');
        exit(1);
      }
      if (symbol == '.') {
        // Свет идёт от банки наружу и гаснет к краям.
        final dx = x - centre;
        final dy = y - centre;
        final t = 1 - math.sqrt(dx * dx + dy * dy) / maxDistance;
        colour = _mix(_palette['.']!, 0xFF3A2A18, (t * t * 0.55).clamp(0, 1));
      }
      out[y * _side + x] = colour;
    }
  }
  return out;
}

int _mix(int a, int b, double t) {
  int channel(int shift) {
    final from = (a >> shift) & 0xFF;
    final to = (b >> shift) & 0xFF;
    return (from + (to - from) * t).round().clamp(0, 255);
  }

  return (0xFF << 24) | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

/// Увеличение «ближайшим соседом»: пиксель обязан остаться пикселем, любое
/// сглаживание превращает арт в кашу.
Uint32List _scale(Uint32List grid, int size) {
  final out = Uint32List(size * size);
  for (var y = 0; y < size; y++) {
    final sy = y * _side ~/ size;
    for (var x = 0; x < size; x++) {
      out[y * size + x] = grid[sy * _side + (x * _side ~/ size)];
    }
  }
  return out;
}

// --- PNG ---------------------------------------------------------------
// Минимальный кодировщик: цвет 8 бит RGBA, фильтр 0. Пакета `image` в
// зависимостях нет и ради генератора иконок тянуть его в проект незачем.

Uint8List _encodePng(Uint32List pixels, int width, int height) {
  final raw = Uint8List(height * (1 + width * 4));
  var i = 0;
  for (var y = 0; y < height; y++) {
    raw[i++] = 0; // фильтр строки: None
    for (var x = 0; x < width; x++) {
      final argb = pixels[y * width + x];
      raw[i++] = (argb >> 16) & 0xFF;
      raw[i++] = (argb >> 8) & 0xFF;
      raw[i++] = argb & 0xFF;
      raw[i++] = (argb >> 24) & 0xFF;
    }
  }

  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final header = BytesBuilder()
    ..add(_uint32(width))
    ..add(_uint32(height))
    ..add([8, 6, 0, 0, 0]);
  out.add(_chunk('IHDR', header.takeBytes()));
  out.add(_chunk('IDAT', ZLibCodec(level: 9).encode(raw) as Uint8List));
  out.add(_chunk('IEND', Uint8List(0)));
  return out.takeBytes();
}

Uint8List _chunk(String type, Uint8List data) {
  final name = ascii.encode(type);
  final body = Uint8List(name.length + data.length)
    ..setAll(0, name)
    ..setAll(name.length, data);
  return Uint8List.fromList([
    ..._uint32(data.length),
    ...body,
    ..._uint32(_crc32(body)),
  ]);
}

List<int> _uint32(int value) =>
    [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
