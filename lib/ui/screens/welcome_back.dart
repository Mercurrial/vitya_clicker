import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/game_clock.dart' show OfflineResult;
import '../../models/flux_state.dart';
import '../game/vitya_portrait.dart';
import '../pixel/pixel_portrait.dart';
import '../theme/garage.dart';

/// Экран возвращения — «пока тебя не было».
///
/// Момент редкий (раз в сессию), поэтому здесь шутка уместна: по правилу
/// частоты чем реже игрок видит строку, тем сильнее она может быть. На тапе
/// шуток нет, а вот тут — можно.
///
/// Пока игры не было, аппараты стояли — строки про это, а не про то, как
/// Витя гнал: за отсутствие теперь копится поток, а не самогон.
const List<String> _lines = [
  'Витя выспался. Время копилось.',
  'Аппараты стояли, зато время шло впрок.',
  'Витя отдохнул и готов гнать быстрее.',
  'Выспался — наверстаем.',
  'Время не пропало. Витя его отложил.',
];

/// Показывает итог отсутствия: сколько накопилось потока времени. Ничего не
/// возвращает — начисление уже сделано, это только витрина.
Future<void> showWelcomeBack(
  BuildContext context, {
  required OfflineResult away,
  required double gained,
  required FluxState flux,
  required VityaEra era,
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
                //
                // Портрет — тот же, что висит в гараже сейчас. Раньше здесь
                // навсегда был «хмурый»: директор возвращался в игру и
                // встречал себя начинающим.
                child: ColoredBox(
                  color: const Color(0xFF1A140F),
                  child: PixelPortrait(asset: era.asset),
                ),
              ),
              const SizedBox(height: GS.s4),
              Text(
                '+${Fmt.duration(Duration(seconds: gained.round()))}',
                style: GType.num(
                  size: 32,
                  weight: FontWeight.w700,
                  color: GColors.amber,
                  shadows: const [Shadow(color: GColors.amberGlow, blurRadius: 18)],
                ),
              ),
              Text(
                'накопилось потока за ${Fmt.playTime(away.elapsed)}',
                style: GType.num(size: 12, color: GColors.textMid),
              ),
              const SizedBox(height: GS.s3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: GS.s3, vertical: GS.s2),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  [
                    'В копилке ${Fmt.duration(Duration(seconds: flux.seconds.round()))} '
                        'из ${Fmt.duration(Duration(seconds: flux.bankSeconds.round()))}. '
                        'Поток ускоряет аппараты.',
                    // Полная копилка — единственное, что игрок теряет, пока
                    // его нет. Сказать об этом надо здесь, а не молча.
                    if (flux.isBankFull) 'Копилка полна — сверх неё поток не копится.',
                  ].join('\n'),
                  textAlign: TextAlign.center,
                  style: GType.ui(size: 12, color: GColors.textMid, height: 1.35),
                ),
              ),
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
                      'В ГАРАЖ',
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
