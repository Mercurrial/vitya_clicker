/// Синтезатор звуков гаража.
///
///     dart run tools/make_sounds.dart
///
/// ## Почему синтез, а не звуковые файлы
///
/// Так же, как иконки и пиксель-арт: **исходник важнее результата**. Скачанный
/// wav — это двоичный файл, про который через полгода нельзя сказать ни откуда
/// он, ни под какой лицензией, ни как сделать «то же самое, но короче». Здесь
/// вместо файла лежит рецепт: «стук по полену — три обертона дерева и выдох
/// пламени», и он правится одной цифрой.
///
/// Шум берётся от [math.Random] с постоянным зерном. Это не мелочь: без
/// фиксированного зерна каждый пересборка давала бы новые байты, и звуки
/// светились бы в каждом дифе, ничего при этом не меняя по сути.
///
/// Формат — WAV PCM 16 бит, моно, 22050 Гц. Для коротких эффектов этого хватает
/// с избытком, а весит всё вместе меньше одной фотографии.
///
/// ## Чем плохи были первые звуки
///
/// Первая версия собиралась из голых синусов, пилы и меандра, и звучала как
/// телефон девяностых. Разобрали по пунктам — каждый пункт стал правилом:
///
/// - **Голые синусы пищат.** Настоящий предмет звучит набором обертонов, и
///   они у него не кратны основному тону: у дерева, стекла и железа свой
///   набор. Отсюда [_strike] — удар по предмету, а не нота.
/// - **Пила и меандр, посчитанные в лоб, дают алиасинг**: обертоны выше
///   половины частоты дискретизации отражаются вниз грязным скрежетом. Так
///   звучал перегрев. Теперь всё собрано из синусов и фильтрованного шума.
/// - **Бас телефон не играет.** Удар на 124→74 Гц и похмелье на 98→33 Гц из
///   динамика телефона были почти не слышны — оставался только шум. Всё, что
///   ниже 150 Гц, срезается ([_finish]), а тело звука живёт выше 250 Гц.
/// - **Самый частый звук был самым громким.** Стук дров — на каждое касание —
///   был на 10 дБ громче сигнала «в окне». Теперь громкость задана явно
///   ([_Sound.peak]): частое — тише, редкое — громче.
/// - **Хвост обрывался** на 3 % громкости, и в конце щёлкало. Теперь
///   последние миллисекунды плавно гаснут.
/// - **«Мягкий ограничитель» ничего не ограничивал**: `tan(atan(x))` — это
///   просто `x`. Его место заняла нормировка громкости.
///
/// Всё перечисленное стережёт `test/sfx_test.dart` — по готовым файлам.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int kRate = 22050;

/// Звук и его громкость — пик относительно полной шкалы.
class _Sound {
  final List<double> Function() build;
  final double peak;
  const _Sound(this.build, this.peak);
}

void main() {
  final dir = Directory('assets/sfx');
  dir.createSync(recursive: true);

  // Громкость — по тому, как часто звук слышен. Стук дров — на каждое касание,
  // «в окне» — на каждый удачный зажим, покупка — пачками подряд. Им тише.
  // Продажа, перегрев и похмелье — события, их не должно быть не слышно.
  final sounds = <String, _Sound>{
    'stoke': const _Sound(_stoke, 0.41),
    'window': const _Sound(_window, 0.16),
    'buy': const _Sound(_buy, 0.42),
    'sell': const _Sound(_sell, 0.44),
    'overheat': const _Sound(_overheat, 0.47),
    'hangover': const _Sound(_hangover, 0.46),
  };

  var total = 0;
  sounds.forEach((name, sound) {
    final samples = _finish(sound.build(), sound.peak);
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

/// Подкинуть дров: стук полена о полено и короткий выдох пламени.
///
/// Звучит на каждое касание, поэтому короткий и тихий: его слушают сотни
/// раз за вечер.
List<double> _stoke() {
  final buf = _buffer(0.2);
  _strike(buf, freq: 280, partials: _wood, amp: 0.8);
  _noiseBand(buf, centre: 700, q: 0.8, amp: 0.55, attack: 0.015, decay: 18, delay: 0.01, seed: 1);
  return buf;
}

/// Жар вошёл в окно: два лёгких «тинь» по стеклу банки, второй выше — «так
/// держать». Тоже частый, тоже тихий.
List<double> _window() {
  final buf = _buffer(0.4);
  _strike(buf, freq: 1175, partials: _glass, amp: 0.7, decay: 14, attack: 0.004); // ре
  _strike(buf, freq: 1568, partials: _glass, amp: 0.8, decay: 12, delay: 0.07, attack: 0.004); // соль
  return buf;
}

/// Покупка: щелчок, банка встала на полку — глухо по дереву и звонко по
/// стеклу. Покупают пачками, поэтому звук короткий.
List<double> _buy() {
  final buf = _buffer(0.28);
  _noiseBand(buf, centre: 3200, q: 1.5, amp: 0.5, attack: 0.001, decay: 250, seed: 3);
  _strike(buf, freq: 330, partials: _wood, amp: 0.8, decay: 32, delay: 0.004);
  _strike(buf, freq: 1760, partials: _glass, amp: 0.45, decay: 22, delay: 0.018, attack: 0.003);
  return buf;
}

/// Продажа: монеты в кассу и звонок кассы.
List<double> _sell() {
  final buf = _buffer(0.75);
  // Монеты падают вразнобой: разная высота, неровный шаг. Жребий с зерном —
  // каждая сборка звенит одинаково.
  final rnd = math.Random(5);
  const drops = [0.0, 0.045, 0.085, 0.14, 0.205];
  for (var i = 0; i < drops.length; i++) {
    _strike(buf,
        freq: 2300 + rnd.nextDouble() * 900,
        partials: _coin,
        amp: 0.55 - i * 0.06,
        decay: 30 + rnd.nextDouble() * 10,
        delay: drops[i]);
  }
  _bell(buf, freq: 1318, ratio: 1.4, index: 2.2, amp: 0.7, decay: 5.5, delay: 0.06); // ми
  return buf;
}

/// Перегрев: закипело — шипит пар, крышка подпрыгивает, и всё сползает вниз.
/// Досада, но не сирена.
List<double> _overheat() {
  final buf = _buffer(0.65);
  _noiseBand(buf, centre: 4200, q: 0.7, amp: 0.9, attack: 0.03, decay: 5, seed: 2);
  const bounces = [0.0, 0.075, 0.135];
  for (var i = 0; i < bounces.length; i++) {
    _strike(buf, freq: 520, partials: _metal, amp: 0.7 - i * 0.18, delay: bounces[i]);
  }
  _glide(buf, from: 330, to: 150, amp: 0.35, decay: 9, length: 0.3, delay: 0.02);
  return buf;
}

/// Похмелье: сонная шкатулка на спуск и выдох. Не трагедия, но и не победа.
List<double> _hangover() {
  final buf = _buffer(1.5);
  const notes = [784.0, 659.0, 523.0, 392.0]; // соль, ми, до, соль ниже
  for (var i = 0; i < notes.length; i++) {
    final last = i == notes.length - 1;
    _strike(buf,
        freq: notes[i],
        partials: _musicBox,
        amp: last ? 0.9 : 0.7,
        decay: last ? 3.5 : 6,
        delay: i * 0.19,
        attack: 0.006);
  }
  _noiseBand(buf, centre: 450, q: 1.2, amp: 0.22, attack: 0.3, decay: 4, delay: 0.55, seed: 4);
  return buf;
}

// ─────────────────────────────────────────────────────────────────────────────
// Из чего сделаны предметы: обертоны удара
// ─────────────────────────────────────────────────────────────────────────────

/// Обертон: во сколько раз выше основного тона, громкость, во сколько раз
/// быстрее гаснет.
typedef _Partial = (double ratio, double amp, double decay);

/// Дерево: обертоны далеко и гаснут почти сразу — «ток».
const List<_Partial> _wood = [(1, 1, 1), (2.57, 0.45, 1.6), (4.1, 0.2, 2.4)];

/// Стекло банки: звонче и дольше.
const List<_Partial> _glass = [(1, 1, 1), (2.71, 0.3, 1.8), (5.1, 0.1, 2.8)];

/// Железо крышки: обертоны тесно — отсюда дребезг.
const List<_Partial> _metal = [(1, 1, 1), (1.47, 0.6, 1.15), (2.09, 0.4, 1.3), (2.56, 0.25, 1.5)];

/// Монета: высоко и негармонично.
const List<_Partial> _coin = [(1, 1, 1), (1.53, 0.5, 1.2), (2.31, 0.3, 1.5)];

/// Язычок шкатулки: почти чистый тон с тихим призвуком.
const List<_Partial> _musicBox = [(1, 1, 1), (2, 0.12, 1.6), (3.9, 0.08, 2.5)];

// ─────────────────────────────────────────────────────────────────────────────
// Кирпичики синтеза
// ─────────────────────────────────────────────────────────────────────────────

List<double> _buffer(double seconds) =>
    List<double>.filled((seconds * kRate).round(), 0.0);

/// Удар по предмету: набор затухающих обертонов.
///
/// [decay] — во сколько раз в секунду гаснет основной тон; обертоны гаснут
/// быстрее, по своему множителю. Так и звучит настоящий предмет: сначала
/// звонко, потом остаётся тон.
void _strike(
  List<double> buf, {
  required double freq,
  required List<_Partial> partials,
  double amp = 0.5,
  double decay = 40,
  double delay = 0,
  double attack = 0.002,
}) {
  for (final (ratio, level, speed) in partials) {
    final f = freq * ratio;
    if (f >= kRate / 2) continue; // выше половины частоты — отразится скрежетом
    _partial(buf, freq: f, amp: amp * level, decay: decay * speed, delay: delay, attack: attack);
  }
}

/// Один затухающий синус с плавной атакой: без неё звук начинается щелчком.
///
/// Дереву и монете хватает двух миллисекунд — щелчок удара и есть их
/// звук. Стеклу и шкатулке нужно дольше: у тона резкий вход слышен
/// посторонним треском поверх ноты.
void _partial(
  List<double> buf, {
  required double freq,
  required double amp,
  required double decay,
  double delay = 0,
  double attack = 0.002,
}) {
  final start = (delay * kRate).round();
  final w = 2 * math.pi * freq / kRate;
  for (var i = start; i < buf.length; i++) {
    final t = (i - start) / kRate;
    final env = math.exp(-decay * t) * _ramp(t, attack);
    if (env < 1e-5 && t > 0.01) break;
    buf[i] += math.sin(w * (i - start)) * amp * env;
  }
}

/// Колокольчик частотной модуляцией: модулятор с нецелым [ratio] даёт
/// негармоничные обертоны колокола, а гаснущий [index] — яркий удар и
/// чистый хвост.
void _bell(
  List<double> buf, {
  required double freq,
  required double ratio,
  required double index,
  required double amp,
  required double decay,
  double delay = 0,
}) {
  final start = (delay * kRate).round();
  for (var i = start; i < buf.length; i++) {
    final t = (i - start) / kRate;
    final env = math.exp(-decay * t) * _ramp(t, 0.002);
    final mod = index * math.exp(-decay * 2 * t) * math.sin(2 * math.pi * freq * ratio * t);
    buf[i] += math.sin(2 * math.pi * freq * t + mod) * amp * env;
  }
}

/// Тон, сползающий по высоте за [length] секунд.
void _glide(
  List<double> buf, {
  required double from,
  required double to,
  required double amp,
  required double decay,
  required double length,
  double delay = 0,
}) {
  final start = (delay * kRate).round();
  var phase = 0.0;
  for (var i = start; i < buf.length; i++) {
    final t = (i - start) / kRate;
    final f = from + (to - from) * math.min(1.0, t / length);
    phase += 2 * math.pi * f / kRate;
    buf[i] += math.sin(phase) * amp * math.exp(-decay * t) * _ramp(t, 0.005);
  }
}

/// Шум в полосе вокруг [centre]: из него пламя, пар и щелчки.
///
/// Белый шум целиком звучит как помехи радио. Полоса делает из него
/// предмет: низкая — выдох пламени, высокая — шипение пара.
void _noiseBand(
  List<double> buf, {
  required double centre,
  required double q,
  required double amp,
  required double attack,
  required double decay,
  double delay = 0,
  required int seed,
}) {
  final rnd = math.Random(seed);
  final start = (delay * kRate).round();
  final band = _Biquad.bandPass(centre, q);
  final band2 = _Biquad.bandPass(centre, q); // второй проход — круче края
  for (var i = start; i < buf.length; i++) {
    final t = (i - start) / kRate;
    final white = rnd.nextDouble() * 2 - 1;
    final shaped = band2.step(band.step(white));
    final env = _ramp(t, attack) * math.exp(-decay * math.max(0.0, t - attack));
    buf[i] += shaped * amp * env;
  }
}

/// Вход по полусинусу, а не по прямой: у прямой излом в конце — тоже щелчок.
double _ramp(double t, double length) =>
    t >= length ? 1.0 : 0.5 - 0.5 * math.cos(math.pi * t / length);

/// Последняя обработка — одна на все звуки.
///
/// Срезать то, что ниже 150 Гц: телефон это не сыграет, а запас громкости
/// оно съедает. Плавно погасить хвост: обрыв слышен щелчком. Привести пик к
/// заданной громкости: иначе частый звук легко выходит громче редкого.
List<double> _finish(List<double> buf, double peak) {
  final hp = _Biquad.highPass(150, 0.707);
  final out = [for (final s in buf) hp.step(s)];

  const fade = 0.015;
  final fadeLen = (fade * kRate).round();
  for (var i = 0; i < fadeLen; i++) {
    final k = out.length - 1 - i;
    out[k] *= 0.5 - 0.5 * math.cos(math.pi * i / fadeLen);
  }

  final loudest = out.fold<double>(0, (m, s) => math.max(m, s.abs()));
  if (loudest == 0) return out;
  return [for (final s in out) s / loudest * peak];
}

/// Биквадратный фильтр по «поваренной книге» Роберта Бристоу-Джонсона.
class _Biquad {
  final double b0, b1, b2, a1, a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  _Biquad._(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory _Biquad.bandPass(double centre, double q) {
    final w = 2 * math.pi * centre / kRate;
    final alpha = math.sin(w) / (2 * q);
    final a0 = 1 + alpha;
    return _Biquad._(alpha / a0, 0, -alpha / a0, -2 * math.cos(w) / a0, (1 - alpha) / a0);
  }

  factory _Biquad.highPass(double cutoff, double q) {
    final w = 2 * math.pi * cutoff / kRate;
    final alpha = math.sin(w) / (2 * q);
    final c = math.cos(w);
    final a0 = 1 + alpha;
    return _Biquad._((1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0, -2 * c / a0, (1 - alpha) / a0);
  }

  double step(double x) {
    final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WAV
// ─────────────────────────────────────────────────────────────────────────────

/// PCM 16 бит, моно. Заголовок собирается руками — это сорок четыре байта,
/// и ради них незачем тянуть зависимость.
Uint8List _wav(List<double> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
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
