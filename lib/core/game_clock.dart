/// Время и отсутствие игрока.
///
/// Всё время хранится в **UTC epoch ms** — часовые пояса и переходы на летнее
/// время не должны влиять на начисления.
///
/// Античит: игра одиночная, поэтому не строим крепость — достаточно не дарить
/// прогресс за перевод часов. Если системные часы ушли назад (`now < lastSeen`),
/// начисление не делается, метка просто подтягивается к текущему моменту.
///
/// Потолка у отсутствия больше нет. Он держал баланс, пока за отсутствие
/// наливался бак; теперь за него копится поток, и держит его копилка
/// потока, а не часы.
library;

/// Результат расчёта отсутствия игрока.
class OfflineResult {
  /// Сколько прошло — за столько и начисляется поток.
  final Duration elapsed;

  /// Обнаружен перевод часов назад — начисления не было.
  final bool rolledBack;

  const OfflineResult({required this.elapsed, this.rolledBack = false});

  static const none = OfflineResult(elapsed: Duration.zero);

  /// Стоит ли вообще показывать экран возвращения.
  bool get isMeaningful => elapsed.inSeconds >= 60;
}

class GameClock {
  /// Источник времени — подменяется в тестах.
  final DateTime Function() _now;

  const GameClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  DateTime nowUtc() => _now().toUtc();

  int nowMillis() => nowUtc().millisecondsSinceEpoch;

  /// Расчёт отсутствия по сохранённой метке.
  OfflineResult since(int? lastSeenMillis) {
    if (lastSeenMillis == null || lastSeenMillis <= 0) return OfflineResult.none;

    final deltaMs = nowMillis() - lastSeenMillis;

    // Часы перевели назад — ничего не начисляем.
    if (deltaMs < 0) {
      return const OfflineResult(elapsed: Duration.zero, rolledBack: true);
    }
    return OfflineResult(elapsed: Duration(milliseconds: deltaMs));
  }
}
