/// Ближайшие моменты событий по расписанию — для осмотра игры глазами.
///
/// Гости выводятся из часов (см. шапку
/// `lib/content/events.dart`), поэтому их нельзя «вызвать» — только дождаться
/// или подвести часы. Скрипт находит ближайшие моменты, а `tools/serve.py`
/// умеет открыть игру в любом из них:
///
///   dart run tools/moments.dart
///   http://localhost:8770/?t=<миллисекунды из вывода>
library;

import 'dart:io';

import 'package:idle_game/content/events.dart';

void main() {
  final start = DateTime.now().toUtc();
  final found = <String, DateTime>{};

  void mark(String name, DateTime t) => found.putIfAbsent(name, () => t);

  // Каждый гость и «тихо».
  final wanted = kGarageEvents.length + 1;
  for (var s = 0; s < 3 * 24 * 3600 && found.length < wanted; s += 5) {
    final t = start.add(Duration(seconds: s));
    final guest = eventAt(t);
    if (guest != null) {
      mark('гость (${guest.event.id})', t.add(const Duration(minutes: 1)));
    } else {
      mark('тихо', t);
    }
  }

  found.forEach((name, t) {
    stdout.writeln('${t.millisecondsSinceEpoch}\t$name');
  });
}
