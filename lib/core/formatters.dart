/// Форматирование чисел для «Витя в деле».
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
  ///
  /// Однобуквенные — заглавными, трёхбуквенные — строчными. Раньше и
  /// длинные писались с заглавной, и «4.12Окт ₽» читалось «4.120кт»:
  /// кириллическая «О» в цифровом шрифте неотличима от нуля, а после
  /// мантиссы с двумя знаками она выглядит третьим. Строчная «о» ниже цифр
  /// и с нулём не путается. Правило одно на все длинные — «спт» рядом с
  /// «Окт» выглядело бы опечаткой (docs/DECISIONS.md, «Интерфейс»).
  ///
  /// Список доходит до 10⁴²: цена коллайдера — около 10²³, и запас в
  /// девятнадцать порядков покрывает кассу и нагнанное далеко за порталом
  /// (проверяет test/core_test.dart).
  static const List<String> _suffixes = [
    '', // 1
    'К', // тысяча
    'М', // миллион
    'Б', // миллиард
    'Т', // триллион
    'квд', // квадриллион
    'квт', // квинтиллион
    'скс', // секстиллион
    'спт', // септиллион
    'окт', // октиллион
    'нон', // нониллион
    'дец', // дециллион
    'унд', // ундециллион
    'дуо', // дуодециллион
    'трд', // тредециллион
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

    // Делим, пока мантисса не округлится меньше чем до тысячи: 999 999 — это
    // «1М», а не «1000К». Раньше граница стояла ровно на тысяче, и на стыке
    // ступеней касса на миг становилась четырёхзначной.
    var reduced = value;
    var tier = 0;
    while (reduced >= 999.5 && tier < _suffixes.length - 1) {
      reduced /= 1000;
      tier++;
    }

    final mantissa = _threeDigits(reduced);
    return '${trim ? _trimZeros(mantissa) : mantissa}${_suffixes[tier]}';
  }

  /// Три значащие цифры: «1.23», «12.3», «123».
  ///
  /// Сколько знаков после точки, решает округлённое число, а не исходное:
  /// 9.996 с двумя знаками — это «10.00», четыре цифры вместо трёх.
  static String _threeDigits(double x) {
    if (x < 9.995) return x.toStringAsFixed(2);
    if (x < 99.95) return x.toStringAsFixed(1);
    return x.toStringAsFixed(0);
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
    if (l >= 999.5) return short(l, trim: trim);
    final s = _threeDigits(l);
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

  /// Длительность для статистики, где счёт идёт на дни: «3 дн 4 ч».
  ///
  /// Отдельно от [duration]: тот нужен коротким отрезкам вроде потока в
  /// копилке, а сотня часов игры в виде «127 ч 12 мин» не читается.
  static String playTime(Duration d) {
    if (d.inHours < 24) return duration(d);
    final h = d.inHours.remainder(24);
    return h == 0 ? '${d.inDays} дн' : '${d.inDays} дн $h ч';
  }

  /// Дата по-нашему: «25.09.2026». В местном времени — день игрок считает
  /// по своим часам, а не по Гринвичу.
  static String date(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year}';
  }

  /// Число со склонённым словом: «3 ванны», «12 ванн», «2.5К ванн».
  ///
  /// Дробь до тысячи отбрасывается: «1.9 бассейна» звучит как отчёт, а
  /// «1 бассейн» — как хвастовство. После тысячи идёт сокращение, и слово
  /// всегда во множественном: «2.5К» читается «две с половиной тысячи ванн».
  static String counted(double n, String one, String few, String many) {
    if (n < 1000) {
      final whole = n.floor();
      return '$whole ${plural(whole, one, few, many)}';
    }
    return '${short(n)} $many';
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
