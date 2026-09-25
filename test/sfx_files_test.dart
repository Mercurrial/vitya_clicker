import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/sfx.dart';

/// Готовые звуки — то, что можно измерить, не слушая.
///
/// Хорош ли звук, решают уши. Но у первой версии звуков половина бед была
/// измеримой, и ни один тест её не видел: стук дров на каждое касание был
/// на 10 дБ громче сигнала «в окне», удар и похмелье сидели ниже 250 Гц, где
/// динамик телефона почти ничего не играет, хвосты обрывались щелчком. Эти
/// проверки — ровно те поломки, числами.
///
/// Файлы синтезирует `tools/make_sounds.dart`; упал тест — править рецепт
/// там и пересобрать, а не подгонять числа здесь.
void main() {
  final sounds = {for (final sfx in Sfx.values) sfx: _Wav.read('assets/${sfx.asset}')};

  // Частые звуки слышны сотни раз за вечер: стук дров — на каждое касание,
  // «в окне» — на каждый удачный зажим, покупки идут пачками.
  const frequent = {Sfx.stoke, Sfx.window, Sfx.buy};

  test('формат, который играют все платформы: PCM 16 бит, моно', () {
    for (final MapEntry(key: sfx, value: wav) in sounds.entries) {
      expect(wav.format, 1, reason: '${sfx.name}: не PCM');
      expect(wav.channels, 1, reason: sfx.name);
      expect(wav.bits, 16, reason: sfx.name);
    }
  });

  test('не упирается в потолок', () {
    // Срезанная верхушка слышна треском.
    for (final MapEntry(key: sfx, value: wav) in sounds.entries) {
      expect(wav.peak, lessThan(0.95), reason: sfx.name);
    }
  });

  test('начинается и кончается тишиной — без щелчка', () {
    for (final MapEntry(key: sfx, value: wav) in sounds.entries) {
      expect(wav.samples.first.abs(), lessThan(0.01), reason: '${sfx.name}: щелчок в начале');
      final tail = wav.samples.sublist(wav.samples.length - wav.rate ~/ 200);
      final loudestTail = tail.map((s) => s.abs()).reduce(math.max);
      expect(loudestTail, lessThan(0.01), reason: '${sfx.name}: обрыв в конце');
    }
  });

  test('слышен в динамике телефона: тело звука выше 200 Гц', () {
    for (final MapEntry(key: sfx, value: wav) in sounds.entries) {
      expect(wav.lowShare(200), lessThan(0.25), reason: sfx.name);
    }
  });

  test('частые звуки короткие', () {
    for (final sfx in frequent) {
      expect(sounds[sfx]!.seconds, lessThanOrEqualTo(0.4), reason: sfx.name);
    }
  });

  test('частые звуки тише событий', () {
    final loudestFrequent = frequent.map((s) => sounds[s]!.loudness).reduce(math.max);
    final quietestEvent = sounds.entries
        .where((e) => !frequent.contains(e.key))
        .map((e) => e.value.loudness)
        .reduce(math.min);
    expect(loudestFrequent, lessThan(quietestEvent));
  });
}

/// WAV без сжатия — ровно такой, какой пишет `tools/make_sounds.dart`.
class _Wav {
  final int format, channels, rate, bits;
  final List<double> samples;

  _Wav(this.format, this.channels, this.rate, this.bits, this.samples);

  factory _Wav.read(String path) {
    final bytes = ByteData.sublistView(File(path).readAsBytesSync());
    final format = bytes.getUint16(20, Endian.little);
    final channels = bytes.getUint16(22, Endian.little);
    final rate = bytes.getUint32(24, Endian.little);
    final bits = bytes.getUint16(34, Endian.little);
    final length = bytes.getUint32(40, Endian.little);
    final samples = [
      for (var i = 0; i < length ~/ 2; i++) bytes.getInt16(44 + i * 2, Endian.little) / 32768,
    ];
    return _Wav(format, channels, rate, bits, samples);
  }

  double get seconds => samples.length / rate;

  double get peak => samples.map((s) => s.abs()).reduce(math.max);

  /// Громкость самых громких 100 мс, дБ. Средняя по всему файлу занизила бы
  /// короткий удар с длинным тихим хвостом.
  double get loudness {
    final window = rate ~/ 10;
    var sum = 0.0, best = 0.0;
    for (var i = 0; i < samples.length; i++) {
      sum += samples[i] * samples[i];
      if (i >= window) sum -= samples[i - window] * samples[i - window];
      best = math.max(best, sum);
    }
    final n = math.min(window, samples.length);
    return 10 * math.log(best / n) / math.ln10;
  }

  /// Доля энергии ниже [cutoff] герц — через фильтр нижних частот второго
  /// порядка.
  double lowShare(double cutoff) {
    final w = 2 * math.pi * cutoff / rate;
    final alpha = math.sin(w) / (2 * 0.707);
    final c = math.cos(w);
    final a0 = 1 + alpha;
    final b0 = (1 - c) / 2 / a0, b1 = (1 - c) / a0, b2 = (1 - c) / 2 / a0;
    final a1 = -2 * c / a0, a2 = (1 - alpha) / a0;
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    var low = 0.0, total = 0.0;
    for (final x in samples) {
      final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
      low += y * y;
      total += x * x;
    }
    return low / total;
  }
}
