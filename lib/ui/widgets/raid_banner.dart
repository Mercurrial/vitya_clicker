/// Плашка ШУХЕРА и сама поимка.
///
/// Виджет делает две вещи, и это не небрежность: он показывает обход И следит
/// за тем, не попался ли Витя. Разделять их было бы хуже — слежение нужно ровно
/// тогда, когда плашка на экране, и живут они от одного тикера.
///
/// Красный тут единственный раз за всю игру. Гараж тёплый и медный; если
/// половина экрана стала красной, это ни с чем не спутаешь и объяснять не надо.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/raid.dart';
import '../../core/sfx.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../theme/garage.dart';

class RaidBanner extends ConsumerStatefulWidget {
  final HeatController heat;
  const RaidBanner({super.key, required this.heat});

  @override
  ConsumerState<RaidBanner> createState() => _RaidBannerState();
}

class _RaidBannerState extends ConsumerState<RaidBanner>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Обход, о котором уже провыла сирена. Без этого она звучала бы каждый кадр.
  int? _announced;

  /// Обход, на котором уже попались. Наказание — одно за обход, а не по разу
  /// в кадр: иначе бак вычерпывался бы досуха за секунду.
  int? _caught;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    final raid = raidAt(ref.read(timeProvider)());

    if (raid != null && raid.id != _announced) {
      _announced = raid.id;
      ref.read(feedbackProvider).hit(Sfx.raid, Buzz.medium);
    }

    // Попался: участковый у ворот, а палец всё ещё на экране.
    if (raid != null &&
        raid.isSearch &&
        widget.heat.isStoking &&
        raid.id != _caught) {
      _caught = raid.id;
      ref.read(gameProvider.notifier).caughtByPolice();
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final raid = raidAt(ref.read(timeProvider)());
    if (raid == null) return const SizedBox.shrink();

    final caught = _caught == raid.id;
    final color = caught ? GColors.textLo : GColors.hot;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: GS.s3),
      padding: const EdgeInsets.symmetric(horizontal: GS.s3, vertical: GS.s2),
      decoration: BoxDecoration(
        color: const Color(0xE6301008),
        borderRadius: BorderRadius.circular(GR.card),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          if (!caught)
            const BoxShadow(color: Color(0x66FF5A3C), blurRadius: 24),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caught ? 'ШУХЕР · не успел' : raid.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GType.ui(
                    size: 13,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caught ? 'Часть бака уехала с ним' : raid.advice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GType.num(size: 10, color: GColors.textMid),
                ),
              ],
            ),
          ),
          const SizedBox(width: GS.s2),
          Text(
            '${raid.remaining.inSeconds}',
            style: GType.num(size: 20, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

