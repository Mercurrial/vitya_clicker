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
  /// Значащих цифр всегда 3, поэтому ширина строки почти не скачет при
  /// обновлении счётчика.
  static String short(double value) {
    if (value.isNaN) return '0';
    if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
    if (value < 0) return '-${short(-value)}';
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

    return '$mantissa${_suffixes[tier]}';
  }

  /// Объём. Внутри игра считает в МИЛЛИЛИТРАХ — так начало ощущается честно:
  /// Витя капает по чуть-чуть, а не сразу литрами.
  ///
  /// До литра показываем миллилитры («850 мл»), дальше переключаемся на литры
  /// с суффиксами («1.20 л», «2.30К л»).
  static String volume(double ml) {
    if (ml.isNaN) return '0 мл';
    if (ml < 0) return '-${volume(-ml)}';
    if (ml < 1000) return '${ml.floor()} мл';
    return '${_litres(ml / 1000)} л';
  }

  /// Литры с тремя значащими цифрами.
  ///
  /// Отдельно от [short], потому что там значения меньше тысячи округляются до
  /// целого — для литров это потеря: 1200 мл превратились бы в «1 л».
  static String _litres(double l) {
    if (l >= 1000) return short(l);
    if (l < 10) return l.toStringAsFixed(2);
    if (l < 100) return l.toStringAsFixed(1);
    return l.toStringAsFixed(0);
  }

  /// Скорость производства: «120 мл/с», «1.20 л/с».
  static String rate(double mlPerSecond) => '${volume(mlPerSecond)}/с';

  /// Только число объёма, без единицы — для крупного счётчика,
  /// где единица выводится отдельным элементом.
  static String volumeNumber(double ml) =>
      ml < 1000 ? ml.floor().toString() : _litres(ml / 1000);

  /// Единица, подходящая величине: «мл» или «л».
  static String volumeUnit(double ml) => ml < 1000 ? 'мл' : 'л';

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
