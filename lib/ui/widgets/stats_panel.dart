/// Статистика игрока — панель на вкладке «Витя».
///
/// Здесь только показ. Счётчики — факты из сейва ([StatsState], касания,
/// нагнанное, похмелья); всё остальное — доля времени в окне, средняя цена,
/// банки и бассейны — считается прямо тут, при каждой сборке. Поэтому правка
/// формулы показа доходит до всех сразу, и в сейве нечему устаревать.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/measures.dart';
import '../../core/formatters.dart';
import '../../models/stats_state.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import 'panel.dart';

class StatsPanel extends ConsumerWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(gameProvider.select((s) => s.stats));
    final taps = ref.watch(gameProvider.select((s) => s.clicker.totalTaps));
    final lifetime = ref.watch(gameProvider.select((s) => s.prestige.totalEverEarned));
    final hangovers = ref.watch(gameProvider.select((s) => s.prestige.hangovers));
    final now = ref.read(timeProvider)();

    // Часы, переведённые назад, дали бы «−3 дня» — показываем ноль.
    final days = now.difference(t.firstLaunch).inDays.clamp(0, 1 << 30);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('СТАТИСТИКА', style: GType.label()),
          const SizedBox(height: GS.s3),
          StatLine('Первый запуск', Fmt.date(t.firstLaunch)),
          _gap,
          StatLine(
            'С тех пор',
            days == 0 ? 'первый день' : Fmt.counted(days.toDouble(), 'день', 'дня', 'дней'),
          ),
          const _Section('ВРЕМЯ'),
          StatLine('В игре', _time(t.playSeconds)),
          _gap,
          StatLine('Держал жар', _time(t.holdSeconds)),
          _gap,
          StatLine('Жар в окне', _windowShare(t)),
          _gap,
          StatLine('Касаний', _count(taps)),
          const _Section('ТОРГОВЛЯ'),
          StatLine('Продано', Fmt.volume(t.soldMl)),
          _gap,
          StatLine('Выручка', Fmt.money(t.earned)),
          _gap,
          StatLine('Сделок', _count(t.sales)),
          _gap,
          StatLine('Из них с гостями', _count(t.guestSales)),
          _gap,
          StatLine('Лучшая сделка', t.sales == 0 ? '—' : Fmt.money(t.bestSale)),
          _gap,
          StatLine('Средняя цена', _averagePrice(t)),
          const _Section('ХОЗЯЙСТВО'),
          StatLine('Куплено аппаратов', _count(t.stillsBought)),
          _gap,
          StatLine('Куплено улучшений', _count(t.upgradesBought)),
          _gap,
          StatLine('Нагнано за всё время', Fmt.volume(lifetime)),
          _gap,
          StatLine('Похмелий пережито', _count(hangovers)),
          _gap,
          StatLine(
            'Самый быстрый заход',
            switch (t.fastestRunSeconds) {
              final s? => _time(s),
              null => '—',
            },
          ),
          const _Section('ЕСЛИ СЛИТЬ ВСЁ НАГНАННОЕ'),
          _Poured(ml: lifetime),
        ],
      ),
    );
  }

  static const _gap = SizedBox(height: GS.s2);

  static String _time(double seconds) =>
      Fmt.playTime(Duration(milliseconds: (seconds * 1000).round()));

  static String _count(int n) => Fmt.short(n.toDouble());

  /// Сколько жар простоял в окне и какая это доля всего времени в игре. Доля
  /// — от игры, а не от зажима: жар проходит окно и без пальца, пока остывает,
  /// и доля от зажима бывала бы больше ста процентов.
  static String _windowShare(StatsState t) {
    final time = _time(t.windowSeconds);
    if (t.playSeconds < 1) return time;
    final share = (t.windowSeconds / t.playSeconds * 100).round();
    return '$time · $share%';
  }

  static String _averagePrice(StatsState t) {
    // Меньше литра — цена за литр вышла бы пересчётом с капли и прыгала бы
    // от каждой продажи.
    if (t.soldMl < 1000) return '—';
    return Fmt.pricePerLitre(t.earned / (t.soldMl / 1000));
  }
}

/// Заголовок группы строк.
class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: GS.s4, bottom: GS.s2),
      child: Text(title, style: GType.label()),
    );
  }
}

/// Нагнанное в понятных мерах.
class _Poured extends StatelessWidget {
  final double ml;
  const _Poured({required this.ml});

  @override
  Widget build(BuildContext context) {
    final poured = pourInto(ml);
    if (poured.isEmpty) {
      return Text('Пока не набралось и на рюмку.', style: GType.body());
    }

    final value = GType.num(size: 13, weight: FontWeight.w700);
    final note = GType.body();
    final jars = poured.first.$2 == kJar ? poured.first.$1 : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (count, m)) in poured.indexed) ...[
          if (i > 0) const SizedBox(height: GS.s1),
          Text.rich(
            TextSpan(children: [
              if (i > 0) TextSpan(text: 'или ', style: note),
              TextSpan(text: Fmt.counted(count, m.one, m.few, m.many), style: value),
            ]),
          ),
        ],
        // Витя начинал с одной банки — и это число растёт у игрока на глазах.
        // Кивок в прошлое, а не подначка. Отдельной строкой в конце: хвостом
        // к банкам фраза на узком экране рвалась посередине.
        if (jars >= 2) ...[
          const SizedBox(height: GS.s2),
          Text('А начинал Витя с одной банки.', style: note),
        ],
      ],
    );
  }
}
