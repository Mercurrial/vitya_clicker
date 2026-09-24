import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/game_clock.dart';
import '../pixel/pixel_portrait.dart';
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
  required bool tankFull,
}) {
  final line = _lines[math.Random().nextInt(_lines.length)];

  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC0A0806),
    builder: (ctx) => Dialog(
      backgroundColor: GColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GR.card),
        side: const BorderSide(color: GColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: GS.s6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(GS.s5, GS.s5, GS.s5, GS.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ПОКА ТЕБЯ НЕ БЫЛО', style: GType.label()),
              const SizedBox(height: GS.s4),
              // Тот же пиксельный портрет, что висит в гараже, — а не сырая
              // фотография: игрок должен узнать своего Витю, а не чужой снимок.
              Container(
                width: 92,
                height: 100,
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [GColors.copper, GColors.copperDim],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 6)),
                  ],
                ),
                // Тёмная подложка — на время, пока портрет считается: иначе
                // первые мгновения в раме горел пустой медный квадрат.
                child: const ColoredBox(
                  color: Color(0xFF1A140F),
                  child: PixelPortrait(asset: 'assets/images/vitya/vitya_frown.jpg'),
                ),
              ),
              const SizedBox(height: GS.s4),
              Text(
                '+${Fmt.volume(gained)}',
                style: GType.num(
                  size: 32,
                  weight: FontWeight.w700,
                  color: GColors.amber,
                  shadows: const [Shadow(color: GColors.amberGlow, blurRadius: 18)],
                ),
              ),
              Text(
                'нагнано за ${Fmt.duration(offline.credited)}',
                style: GType.num(size: 12, color: GColors.textMid),
              ),
              if (offline.capped || tankFull) ...[
                const SizedBox(height: GS.s3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: GS.s3, vertical: GS.s2),
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    [
                      // Потолок — на ЗАСЧИТАННОЕ время, а не на бак. Прошлая
                      // подпись говорила «бак переполнился», и игрок искал
                      // бак побольше там, где помогло бы заходить почаще.
                      if (offline.capped)
                        'Засчитано ${Fmt.duration(GameClock.offlineCap)} из '
                            '${Fmt.duration(offline.elapsed)}: дольше без присмотра '
                            'аппараты не гонят.',
                      if (tankFull) 'Бак полон — аппараты стоят, пока не продашь.',
                    ].join('\n'),
                    textAlign: TextAlign.center,
                    style: GType.ui(size: 12, color: GColors.textMid, height: 1.35),
                  ),
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
                      boxShadow: const [
                        BoxShadow(color: GColors.amberGlow, blurRadius: 14, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Text(
                      tankFull ? 'В ГАРАЖ — ПРОДАВАТЬ' : 'В ГАРАЖ',
                      style: GType.tab().copyWith(color: GColors.onAmber),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
