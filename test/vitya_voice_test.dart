import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/vitya_quotes.dart';

void main() {
  group('Голос Вити', () {
    test('на каждое событие есть что сказать', () {
      for (final event in VityaEvent.values) {
        final pool = kVityaLines[event];
        expect(pool, isNotNull, reason: 'нет реплик для $event');
        expect(pool!, isNotEmpty);
      }
    });

    test('не повторяет одну реплику подряд', () {
      final voice = VityaVoice(random: math.Random(7));
      var previous = voice.line(VityaEvent.gradeUp);
      for (var i = 0; i < 40; i++) {
        final next = voice.line(VityaEvent.gradeUp);
        expect(next, isNot(previous),
            reason: 'повтор подряд убивает реплику надёжнее плохой шутки');
        previous = next;
      }
    });

    test('со временем перебирает весь набор', () {
      final voice = VityaVoice(random: math.Random(3));
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(voice.line(VityaEvent.sold));
      }
      expect(seen.length, kVityaLines[VityaEvent.sold]!.length);
    });

    test('реплики сухие: без восклицаний и эмодзи', () {
      // Объяснённая шутка мертва — тон держим сдержанным.
      final all = kVityaLines.values.expand((l) => l);
      for (final line in all) {
        expect(line.contains('!'), isFalse, reason: 'восклицание в «$line»');
        expect(
          RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true).hasMatch(line),
          isFalse,
          reason: 'эмодзи в «$line»',
        );
      }
    });
  });
}
