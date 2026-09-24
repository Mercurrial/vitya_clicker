/// Форматирование чисел для «Витя гонит».
///
/// Единая точка для всех чисел в игре. Вся арифметика игры ведётся в `double`
/// (потолок ~1.79e308 — недостижим для нашего масштаба). Если когда-нибудь
/// упрёмся в потолок, замена на big-number затронет только этот модуль.
///
/// Формат намеренно русский и «тёплый» (1.5К, 2.3М), а не научный (4.2e23) —
/// научная нотация ломает тон игры про гараж.
library;

class Fmt {
  Fmt._();

  /// Короткие русские суффиксы по степеням тысячи.
  static const List<String> _suffixes = [
    '', // 1
    'К', // тысяча
    'М', // миллион
    'Б', // миллиард
    'Т', // триллион
    'Квд', // квадриллион
    'Квт', // квинтиллион
    'Скс', // секстиллион
    'Спт', // септиллион
    'Окт', // октиллион
    'Нон', // нониллион
    'Дец', // дециллион
    'Унд', // ундециллион
    'Дуо', // дуодециллион
    'Трд', // тредециллион
  ];

  /// Основной формат: 950 → «950», 1500 → «1.5К», 2_300_000 → «2.3М».
  ///
  /// Хвостовые нули срезаются: «10К л», а не «10.00К л», и «2К ₽», а не
  /// «2.00К ₽». Нули нужны только живым счётчикам, у которых ширина не должна
  /// прыгать каждый кадр, — для них [trim] выключают.
  static String short(double value, {bool trim = true}) {
    if (value.isNaN) return '0';
    if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
    if (value < 0) return '-${short(-value, trim: trim)}';
    if (value < 1000) return value.floor().toString();

    var reduced = value;
    var tier = 0;
    while (reduced >= 1000 && tier < _suffixes.length - 1) {
      reduced /= 1000;
      tier++;
    }

    final String mantissa;
    if (reduced < 10) {
      mantissa = reduced.toStringAsFixed(2);
    } else if (reduced < 100) {
      mantissa = reduced.toStringAsFixed(1);
    } else {
      mantissa = reduced.toStringAsFixed(0);
    }

    return '${trim ? _trimZeros(mantissa) : mantissa}${_suffixes[tier]}';
  }

  /// «2.50» → «2.5», «10.0» → «10», «999» → «999».
  static String _trimZeros(String s) {
    if (!s.contains('.')) return s;
    var out = s.replaceFirst(RegExp(r'0+$'), '');
    if (out.endsWith('.')) out = out.substring(0, out.length - 1);
    return out;
  }

  /// Объём. Внутри игра считает в МИЛЛИЛИТРАХ — так начало ощущается честно:
  /// Витя капает по чуть-чуть, а не сразу литрами.
  ///
  /// До литра показываем миллилитры («850 мл»), дальше переключаемся на литры
  /// с суффиксами («1.20 л», «2.30К л»).
  static String volume(double ml, {bool trim = true}) {
    if (ml.isNaN) return '0 мл';
    if (ml < 0) return '-${volume(-ml, trim: trim)}';
    if (ml < 1000) return '${ml.floor()} мл';
    return '${_litres(ml / 1000, trim: trim)} л';
  }

  /// Литры с тремя значащими цифрами.
  ///
  /// Отдельно от [short], потому что там значения меньше тысячи округляются до
  /// целого — для литров это потеря: 1200 мл превратились бы в «1 л».
  static String _litres(double l, {bool trim = true}) {
    if (l >= 1000) return short(l, trim: trim);
    final String s;
    if (l < 10) {
      s = l.toStringAsFixed(2);
    } else if (l < 100) {
      s = l.toStringAsFixed(1);
    } else {
      s = l.toStringAsFixed(0);
    }
    return trim ? _trimZeros(s) : s;
  }

  /// Скорость производства: «120 мл/с», «1.20 л/с».
  static String rate(double mlPerSecond, {bool trim = true}) =>
      '${volume(mlPerSecond, trim: trim)}/с';

  /// Только число объёма, без единицы — для крупного счётчика,
  /// где единица выводится отдельным элементом.
  static String volumeNumber(double ml, {bool trim = true}) =>
      ml < 1000 ? ml.floor().toString() : _litres(ml / 1000, trim: trim);

  /// Единица, подходящая величине: «мл» или «л».
  static String volumeUnit(double ml) => ml < 1000 ? 'мл' : 'л';

  /// Рубли: «1.20К ₽». До тысячи — целыми, копейки в игре не нужны.
  static String money(double value, {bool trim = true}) {
    if (value.isNaN) return '0 ₽';
    if (value < 0) return '-${money(-value, trim: trim)}';
    return '${short(value, trim: trim)} ₽';
  }

  /// Цена за литр — с точностью, потому что её сравнивают глазами.
  static String pricePerLitre(double value) {
    if (value < 1000) return '${value.toStringAsFixed(0)} ₽/л';
    return '${short(value)} ₽/л';
  }

  /// Множитель: 2.0 → «×2», 1.5 → «×1.5», 2.25 → «×2.25».
  static String mult(double value) {
    if (value == value.roundToDouble()) return '×${value.toStringAsFixed(0)}';
    if ((value * 10) == (value * 10).roundToDouble()) {
      return '×${value.toStringAsFixed(1)}';
    }
    return '×${value.toStringAsFixed(2)}';
  }

  /// Проценты: 0.15 → «+15%».
  static String percent(double fraction) {
    final p = fraction * 100;
    final sign = p >= 0 ? '+' : '';
    if (p == p.roundToDouble()) return '$sign${p.toStringAsFixed(0)}%';
    return '$sign${p.toStringAsFixed(1)}%';
  }

  /// Обратный отсчёт: «12:03», «1:05:00». Для того, что тикает на глазах —
  /// «12 мин» полминуты стоит на месте, и отсчёт кажется зависшим.
  static String clock(Duration d) {
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours}:$m:$s';
    }
    return '${d.inMinutes}:$s';
  }

  /// Длительность по-русски для экрана возвращения: «2 ч 14 мин».
  static String duration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} сек';
    if (d.inMinutes < 60) return '${d.inMinutes} мин';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '$h ч' : '$h ч $m мин';
  }

  /// Русское склонение по числу: plural(2, 'литр', 'литра', 'литров').
  static String plural(int n, String one, String few, String many) {
    final mod100 = n.abs() % 100;
    if (mod100 >= 11 && mod100 <= 14) return many;
    switch (n.abs() % 10) {
      case 1:
        return one;
      case 2:
      case 3:
      case 4:
        return few;
      default:
        return many;
    }
  }
}
