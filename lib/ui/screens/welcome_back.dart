import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/game_clock.dart';
import '../theme/garage.dart';

/// Экран возвращения — «пока тебя не было».
///
/// Момент редкий (раз в сессию), поэтому здесь шутка уместна: по правилу
/// частоты чем реже игрок видит строку, тем сильнее она может быть. На тапе
/// шуток нет, а вот тут — можно.
const List<String> _lines = [
  'Витя не спал. Витя гнал.',
  'Витя справился. В основном.',
  'Аппарат работал. Витя — присматривал.',
  'Витя всё это время был занят делом.',
  'Простоя не было. Почти.',
];

/// Показывает итог отсутствия. Ничего не возвращает — начисление уже сделано
/// при запуске, это только витрина.
Future<void> showWelcomeBack(
  BuildContext context, {
  required OfflineResult offline,
  required double gained,
}) {
  final line = _lines[math.Random().nextInt(_lines.length)];

  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC0A0806),
    builder: (ctx) => Dialog(
      backgroundColor: GColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GR.sheet)),
      insetPadding: const EdgeInsets.all(GS.s6),
      child: Padding(
        padding: const EdgeInsets.all(GS.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ПОКА ТЕБЯ НЕ БЫЛО', style: GType.label()),
            const SizedBox(height: GS.s4),
            ClipRRect(
              borderRadius: BorderRadius.circular(GR.button),
              child: Image.asset(
                'assets/images/vitya/vitya_frown.jpg',
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: GS.s4),
            Text(
              '+${Fmt.litres(gained)}',
              style: GType.num(
                size: 32,
                weight: FontWeight.w700,
                color: GColors.amber,
                shadows: const [Shadow(color: GColors.amberGlow, blurRadius: 18)],
              ),
            ),
            const SizedBox(height: GS.s1),
            Text(
              'за ${Fmt.duration(offline.credited)}',
              style: GType.num(size: 13, color: GColors.textMid),
            ),
            if (offline.capped) ...[
              const SizedBox(height: GS.s2),
              Text(
                'Бак переполнился через ${Fmt.duration(GameClock.offlineCap)} —\nостальное ушло в землю.',
                textAlign: TextAlign.center,
                style: GType.body().copyWith(color: GColors.textLo),
              ),
            ],
            const SizedBox(height: GS.s4),
            Text(line, textAlign: TextAlign.center, style: GType.quote()),
            const SizedBox(height: GS.s5),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GR.button),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [GColors.amber, GColors.amberDim],
                    ),
                  ),
                  child: Text(
                    'ЗАБРАТЬ',
                    style: GType.tab().copyWith(color: GColors.onAmber),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
