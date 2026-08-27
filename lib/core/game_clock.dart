/// Время и оффлайн-прогресс.
///
/// Всё время хранится в **UTC epoch ms** — часовые пояса и переходы на летнее
/// время не должны влиять на начисления.
///
/// Античит: игра одиночная, поэтому не строим крепость — достаточно не дарить
/// прогресс за перевод часов. Если системные часы ушли назад (`now < lastSeen`),
/// начисление не делается, метка просто подтягивается к текущему моменту.
library;

/// Результат расчёта отсутствия игрока.
class OfflineResult {
  /// Сколько времени реально засчитано (после потолка).
  final Duration credited;

  /// Сколько прошло на самом деле (для текста «тебя не было 3 дня»).
  final Duration elapsed;

  /// Часы упёрлись в потолок — начислено не за всё время.
  final bool capped;

  /// Обнаружен перевод часов назад — начисления не было.
  final bool rolledBack;

  const OfflineResult({
    required this.credited,
    required this.elapsed,
    this.capped = false,
    this.rolledBack = false,
  });

  static const none = OfflineResult(credited: Duration.zero, elapsed: Duration.zero);

  /// Стоит ли вообще показывать экран возвращения.
  bool get isMeaningful => credited.inSeconds >= 60;
}

class GameClock {
  /// Потолок оффлайн-начисления. Держит баланс: вернуться приятно, но уход на
  /// неделю не должен пропускать полигры.
  static const Duration offlineCap = Duration(hours: 8);

  /// Источник времени — подменяется в тестах.
  final DateTime Function() _now;

  const GameClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  DateTime nowUtc() => _now().toUtc();

  int nowMillis() => nowUtc().millisecondsSinceEpoch;

  /// Расчёт отсутствия по сохранённой метке.
  OfflineResult since(int? lastSeenMillis) {
    if (lastSeenMillis == null || lastSeenMillis <= 0) return OfflineResult.none;

    final now = nowMillis();
    final deltaMs = now - lastSeenMillis;

    // Часы перевели назад — ничего не начисляем.
    if (deltaMs < 0) {
      return const OfflineResult(
        credited: Duration.zero,
        elapsed: Duration.zero,
        rolledBack: true,
      );
    }

    final elapsed = Duration(milliseconds: deltaMs);
    if (elapsed <= offlineCap) {
      return OfflineResult(credited: elapsed, elapsed: elapsed);
    }
    return OfflineResult(credited: offlineCap, elapsed: elapsed, capped: true);
  }
}
