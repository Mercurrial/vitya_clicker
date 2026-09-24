/// Ближайшие моменты событий по расписанию — для осмотра игры глазами.
///
/// Гость, участковый и неприятности выводятся из часов (см. шапку
/// `lib/content/events.dart`), поэтому их нельзя «вызвать» — только дождаться
/// или подвести часы. Скрипт находит ближайшие моменты, а `tools/serve.py`
/// умеет открыть игру в любом из них:
///
///   dart run tools/moments.dart
///   http://localhost:8770/?t=<миллисекунды из вывода>
library;

import 'dart:io';

import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/expenses.dart';
import 'package:idle_game/content/raid.dart';

void main() {
  final start = DateTime.now().toUtc();
  final found = <String, DateTime>{};

  void mark(String name, DateTime t) => found.putIfAbsent(name, () => t);

  for (var s = 0; s < 3 * 24 * 3600 && found.length < 7; s += 5) {
    final t = start.add(Duration(seconds: s));
    final guest = eventAt(t);
    final raid = raidAt(t);
    final expense = expenseAt(t);
    if (guest != null && raid == null && expense == null) {
      mark('гость (${guest.event.id})', t.add(const Duration(minutes: 1)));
    }
    if (raid != null && raid.isWarning && guest == null) mark('участковый: предупреждение', t);
    if (raid != null && raid.isSearch && guest == null) mark('участковый: обыск', t);
    if (expense != null && guest == null && raid == null) {
      mark('неприятность (${expense.expense.id})', t.add(const Duration(minutes: 1)));
    }
    if (guest == null && raid == null && expense == null) mark('тихо', t);
  }

  found.forEach((name, t) {
    stdout.writeln('${t.millisecondsSinceEpoch}\t$name');
  });
}
