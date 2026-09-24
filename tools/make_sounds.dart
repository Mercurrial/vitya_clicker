/// Синтезатор звуков гаража.
///
///     dart run tools/make_sounds.dart
///
/// ## Почему синтез, а не звуковые файлы
///
/// Так же, как иконки и пиксель-арт: **исходник важнее результата**. Скачанный
/// wav — это двоичный файл, про который через полгода нельзя сказать ни откуда
/// он, ни под какой лицензией, ни как сделать «то же самое, но короче». Здесь
/// вместо файла лежит рецепт: «удар по бочке — сто герц с быстрым спадом плюс
/// щепоть шума», и он правится одной цифрой.
///
/// Шум берётся от [math.Random] с постоянным зерном. Это не мелочь: без
/// фиксированного зерна каждый пересборка давала бы новые байты, и звуки
/// светились бы в каждом дифе, ничего при этом не меняя по сути.
///
/// Формат — WAV PCM 16 бит, моно, 22050 Гц. Для коротких эффектов этого хватает
/// с избытком, а весит всё вместе меньше одной фотографии.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int kRate = 22050;

void main() {
  final dir = Directory('assets/sfx');
  dir.createSync(recursive: true);

  final sounds = <String, List<double>>{
    'stoke': _stoke(),
    'window': _window(),
    'overheat': _overheat(),
    'buy': _buy(),
    'sell': _sell(),
    'hangover': _hangover(),
    'raid': _raid(),
  };

  var total = 0;
  sounds.forEach((name, samples) {
    final bytes = _wav(samples);
    File('${dir.path}/$name.wav').writeAsBytesSync(bytes);
    total += bytes.length;
    final ms = (samples.length / kRate * 1000).round();
    stdout.writeln('  $name.wav — $ms мс, ${(bytes.length / 1024).toStringAsFixed(1)} КБ');
  });

  stdout.writeln('\nВсего ${sounds.length} звуков, ${(total / 1024).toStringAsFixed(1)} КБ.');
}

// ─────────────────────────────────────────────────────────────────────────────
// Сами звуки
// ─────────────────────────────────────────────────────────────────────────────

/// Подкинуть дров: глухой удар по железу и короткий выдох пламени.
List<double> _stoke() {
  final buf = _buffer(0.18);
  _tone(buf, freq: 124, to: 74, amp: 0.55, decay: 22);
  _tone(buf, freq: 248, to: 150, amp: 0.16, decay: 30);
  _noise(buf, amp: 0.13, decay: 16, seed: 1);
  return buf;
}

/// Жар вошёл в окно: две ноты вверх, тихо и коротко — звучит часто.
List<double> _window() {
  final buf = _buffer(0.22);
  _tone(buf, freq: 660, amp: 0.13, decay: 26, delay: 0.0);
  _tone(buf, freq: 880, amp: 0.15, decay: 22, delay: 0.06);
  return buf;
}

/// Перегрев: злое шипение со срывом вниз.
List<double> _overheat() {
  final buf = _buffer(0.55);
  _noise(buf, amp: 0.26, decay: 7, seed: 2);
  _tone(buf, freq: 340, to: 90, amp: 0.34, decay: 6, wave: _Wave.saw);
  _tone(buf, freq: 170, to: 45, amp: 0.20, decay: 5, wave: _Wave.square);
  return buf;
}

/// Покупка: собранный железный щелчок и нота вверх.
List<double> _buy() {
  final buf = _buffer(0.3);
  _noise(buf, amp: 0.10, decay: 60, seed: 3);
  _tone(buf, freq: 392, amp: 0.26, decay: 16);
  _tone(buf, freq: 588, amp: 0.20, decay: 14, delay: 0.08);
  return buf;
}

/// Продажа: пересчитанные деньги. Три быстрых звонких призвука.
List<double> _sell() {
  final buf = _buffer(0.42);
  for (var i = 0; i < 3; i++) {
    _tone(buf,
        freq: 900 + i * 260.0, amp: 0.15, decay: 30, delay: i * 0.055);
    _tone(buf,
        freq: 1350 + i * 390.0, amp: 0.08, decay: 34, delay: i * 0.055);
  }
  _tone(buf, freq: 523, amp: 0.18, decay: 9, delay: 0.1);
  return buf;
}

/// Похмелье: длинный уход вниз. Не трагедия, но и не победа.
List<double> _hangover() {
  final buf = _buffer(1.1);
  _tone(buf, freq: 196, to: 65, amp: 0.30, decay: 3.2, wave: _Wave.triangle);
  _tone(buf, freq: 98, to: 33, amp: 0.22, decay: 2.8);
  _noise(buf, amp: 0.05, decay: 4, seed: 4);
  return buf;
}

/// ШУХЕР: две ноты туда-сюда. Не настоящая сирена — намёк на неё.
List<double> _raid() {
  final buf = _buffer(0.9);
  for (var i = 0; i < 4; i++) {
    _tone(buf,
        freq: i.isEven ? 740 : 560,
        amp: 0.22,
        decay: 13,
        delay: i * 0.2,
        wave: _Wave.square);
  }
  return buf;
}

// ─────────────────────────────────────────────────────────────────────────────
// Кирпичики синтеза
// ─────────────────────────────────────────────────────────────────────────────

enum _Wave { sine, triangle, square, saw }

List<double> _buffer(double seconds) =>
    List<double>.filled((seconds * kRate).round(), 0.0);

/// Тон с экспоненциальным спадом и, если задано [to], со сползанием частоты.
///
/// [decay] — во сколько раз в секунду затухает громкость: чем больше, тем
/// короче хвост. Резать по времени было бы проще, но щелчок на обрыве слышен.
void _tone(
  List<double> buf, {
  required double freq,
  double? to,
  double amp = 0.3,
  double decay = 12,
  double delay = 0,
  _Wave wave = _Wave.sine,
}) {
  final start = (delay * kRate).round();
  var phase = 0.0;

  for (var i = start; i < buf.length; i++) {
    final t = (i - start) / kRate;
    final life = (buf.length - start) / kRate;
    final f = to == null ? freq : freq + (to - freq) * (t / life);

    phase += 2 * math.pi * f / kRate;
    final raw = switch (wave) {
      _Wave.sine => math.sin(phase),
      _Wave.triangle => 2 / math.pi * math.asin(math.sin(phase)),
      _Wave.square => math.sin(phase) >= 0 ? 1.0 : -1.0,
      _Wave.saw => 2 * ((phase / (2 * math.pi)) % 1.0) - 1.0,
    };

    buf[i] += raw * amp * math.exp(-decay * t) * _attack(t);
  }
}

/// Шум с тем же спадом — из него делаются удары, шипение и щелчки.
void _noise(
  List<double> buf, {
  double amp = 0.2,
  double decay = 12,
  double delay = 0,
  required int seed,
}) {
  final rnd = math.Random(seed);
  final start = (delay * kRate).round();

  // Один полюс низких частот: без него шум звучит как помехи радио, а нужен
  // воздух и пламя.
  var last = 0.0;
  for (var i = start; i < buf.length; i++) {
    final t = (i - start) / kRate;
    final white = rnd.nextDouble() * 2 - 1;
    last += (white - last) * 0.35;
    buf[i] += last * amp * math.exp(-decay * t) * _attack(t);
  }
}

/// Мягкий вход за три миллисекунды: без него каждый звук начинается щелчком.
double _attack(double t) {
  const a = 0.003;
  return t >= a ? 1.0 : t / a;
}

// ─────────────────────────────────────────────────────────────────────────────
// WAV
// ─────────────────────────────────────────────────────────────────────────────

/// PCM 16 бит, моно. Заголовок собирается руками — это сорок четыре байта,
/// и ради них незачем тянуть зависимость.
Uint8List _wav(List<double> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    // Мягкое ограничение вместо обрезания: сумма нескольких тонов легко
    // выходит за единицу, и жёсткий clip слышен как треск.
    final soft = math.tan(math.atan(samples[i] * 1.6)) / 1.6;
    final v = (soft.clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(i * 2, v, Endian.little);
  }
  final pcm = data.buffer.asUint8List();

  final out = BytesBuilder();
  void ascii(String s) => out.add(s.codeUnits);
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little))
      .buffer
      .asUint8List());
  void u16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little))
      .buffer
      .asUint8List());

  ascii('RIFF');
  u32(36 + pcm.length);
  ascii('WAVE');
  ascii('fmt ');
  u32(16); // размер блока fmt
  u16(1); // PCM без сжатия
  u16(1); // моно
  u32(kRate);
  u32(kRate * 2); // байт в секунду
  u16(2); // байт на кадр
  u16(16); // бит на отсчёт
  ascii('data');
  u32(pcm.length);
  out.add(pcm);

  return out.toBytes();
}
