/// Форматирование больших чисел для UI.
/// Масштабируемый: поддерживает суффиксы до бесконечности.
class NumberFormatter {
  static const List<String> _suffixes = [
    '', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc',
    'UDc', 'DDc', 'TDc', 'QaDc', 'QiDc', 'SxDc', 'SpDc', 'OcDc', 'NoDc',
    'Vg', 'UVg',
  ];

  /// Форматирует число с автоматическим суффиксом.
  /// 1500 → "1.5K", 2300000 → "2.3M"
  /// Числа < 1000 показываются с 1 знаком после запятой.
  static String format(double value) {
    if (value < 0) return '-${format(-value)}';
    if (value < 1000) return value.toStringAsFixed(1);

    int suffixIndex = 0;
    double reduced = value;

    while (reduced >= 1000 && suffixIndex < _suffixes.length - 1) {
      reduced /= 1000;
      suffixIndex++;
    }

    // Показываем 2 знака для чисел < 10, 1 знак для < 100, 0 для >= 100
    final String formatted;
    if (reduced < 10) {
      formatted = reduced.toStringAsFixed(2);
    } else if (reduced < 100) {
      formatted = reduced.toStringAsFixed(1);
    } else {
      formatted = reduced.toStringAsFixed(0);
    }

    return '$formatted${_suffixes[suffixIndex]}';
  }

  /// Короткий формат для стоимости (без десятичных для целых чисел < 1000).
  static String formatCost(double value) {
    if (value < 1000 && value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return format(value);
  }
}
