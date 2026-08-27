import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/achievements.dart';
import '../../core/formatters.dart';
import '../../engine/market.dart';
import '../../engine/production.dart';
import '../../models/achievement.dart';
import '../../models/prestige_state.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../game/heat_gauge.dart';
import '../game/vitya_portrait.dart';
import '../pixel/garage_scene.dart';
import '../theme/art_style.dart';
import '../theme/garage.dart';
import '../widgets/shop.dart';

/// Ширина «телефона»: на широком экране игра не растягивается, иначе карточки
/// разъезжаются на пол-экрана и верстка ломается.
const double _kPhoneWidth = 460;

/// Режим «купить максимум».
const int kBuyMax = -1;

/// Сколько штук берём за одно нажатие: 1, 10, 100 или максимум.
final buyAmountProvider = StateProvider<int>((ref) => 1);

/// Переключатель количества. Появляется только после достижения, которое его
/// открывает: автоматизация в жанре зарабатывается, а не выдаётся.
class _BuyAmountSelector extends ConsumerWidget {
  final int mode;
  const _BuyAmountSelector({required this.mode});

  static const _options = [
    (1, '×1'),
    (10, '×10'),
    (100, '×100'),
    (kBuyMax, 'МАКС'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: GColors.wellBg,
        borderRadius: BorderRadius.circular(GR.pill),
      ),
      child: Row(
        children: [
          for (final (value, label) in _options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(buyAmountProvider.notifier).state = value;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == mode ? GColors.copper : null,
                    borderRadius: BorderRadius.circular(GR.pill),
                  ),
                  child: Text(
                    label,
                    style: GType.num(
                      size: 11,
                      weight: FontWeight.w700,
                      color: value == mode ? GColors.textHi : GColors.textMid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen>
    with TickerProviderStateMixin {
  late final HeatController _heat;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _heat = HeatController(vsync: this);
    // Жар живёт в интерфейсе, но множит пассивный поток в движке — поэтому
    // текущее значение непрерывно отдаём в состояние игры.
    _heat.addListener(_pushHeat);
  }

  void _pushHeat() => ref.read(gameProvider.notifier).setHeat(_heat.multiplier);

  @override
  void dispose() {
    _heat.removeListener(_pushHeat);
    _heat.dispose();
    super.dispose();
  }

  ({String text, Color color}) _onTap() {
    final applied = _heat.stoke();
    final gained = ref.read(gameProvider).tapYield * applied;
    ref.read(gameProvider.notifier).tap(heatMultiplier: applied);

    final color = _heat.isOverheated
        ? GColors.hot
        : applied >= HeatController.greenMultiplier
            ? GColors.green
            : GColors.brew;
    return (text: '+${Fmt.volume(gained)}', color: color);
  }

  @override
  Widget build(BuildContext context) {
    final era = ref.watch(
      gameProvider.select((s) => _eraFor(s.prestige.totalEverEarned)),
    );
    final style = ref.watch(artStyleProvider);

    return ColoredBox(
      color: GColors.bg,
      child: Stack(
        children: [
          const Positioned.fill(child: _LampLight()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kPhoneWidth),
              child: SafeArea(
                child: Column(
                  children: [
                    const _Counter(),
                    // Гараж — центр экрана. Портрет висит на его стене, а
                    // купленные аппараты встают на полки: империю видно.
                    //
                    // На низком окне сцена уступает место списку: иначе нижняя
                    // панель уезжает за край и до кнопок не добраться.
                    Expanded(
                      flex: MediaQuery.of(context).size.height < 760 ? 3 : 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: GS.s3),
                        child: AnimatedBuilder(
                          animation: _heat,
                          builder: (context, _) => GarageScene(
                            heat: _heat.heat,
                            hanging: _PortraitWithHint(
                              portrait: VityaPortrait(
                                era: era,
                                onTap: _onTap,
                                size: 116,
                                style: style.portrait,
                                radius: style.radius * 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(GS.s6, GS.s3, GS.s6, GS.s3),
                      child: HeatGauge(controller: _heat),
                    ),
                    Expanded(
                      flex: 4,
                      child: _Shelf(
                        tab: _tab,
                        onTab: (i) => setState(() => _tab = i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Переключатель стиля — временный, чтобы выбрать язык игры глазами.
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 10,
            child: _StyleToggle(style: style),
          ),
        ],
      ),
    );
  }
}

/// Кнопка смены визуального языка. Инструмент выбора, а не часть игры —
/// уедет, как только стиль будет утверждён.
class _StyleToggle extends ConsumerWidget {
  final ArtStyle style;
  const _StyleToggle({required this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          ref.read(artStyleProvider.notifier).state = style.next,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GColors.wellBg,
          borderRadius: BorderRadius.circular(style.radius > 0 ? GR.pill : 0),
          border: Border.all(color: GColors.border),
        ),
        child: Text(style.label, style: GType.label()),
      ),
    );
  }
}

/// Эпоха Вити по суммарно нагнанному.
///
/// Пороги низкие намеренно: ранг — бесплатный источник ощущения роста, и если
/// он не меняется за первые полчаса, он не работает вовсе.
VityaEra _eraFor(double lifetime) {
  if (lifetime < 1e4) return VityaEra.start; // до 10 литров
  if (lifetime < 1e7) return VityaEra.work; // до 10 тысяч литров
  return VityaEra.boss;
}

/// Вкладка «Цели» — достижения сеткой рядов.
///
/// Открытое достижение множит производство, а **полностью закрытый ряд — ещё
/// раз и заметно сильнее**. Из-за этого ряд хочется добить, и список галочек
/// превращается в систему прогресса. Подсказки у закрытых работают встроенным
/// гидом: игрок всегда видит, что делать дальше.
class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ach = ref.watch(gameProvider.select((s) => s.achievements));

    return ListView(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      children: [
        _Panel(
          child: Column(
            children: [
              Text('ОБЩИЙ МНОЖИТЕЛЬ', style: GType.label()),
              Text(
                Fmt.mult(ach.multiplier),
                style: GType.num(
                  size: 30,
                  weight: FontWeight.w700,
                  color: GColors.amber,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${ach.count} из ${kAllAchievements.length} · '
                'рядов закрыто ${ach.completedRows} из ${kAchievementRows.length}',
                style: GType.num(size: 11, color: GColors.textMid),
              ),
            ],
          ),
        ),
        const SizedBox(height: GS.s3),
        for (final row in kAchievementRows) ...[
          _AchievementRowView(row: row, unlocked: ach.unlocked),
          const SizedBox(height: GS.s3),
        ],
      ],
    );
  }
}

class _AchievementRowView extends StatelessWidget {
  final AchievementRow row;
  final Set<String> unlocked;

  const _AchievementRowView({required this.row, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final done = row.items.every((a) => unlocked.contains(a.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(row.title.toUpperCase(), style: GType.label()),
            const SizedBox(width: GS.s2),
            Text(
              done ? 'ряд закрыт · ${Fmt.mult(kRowMultiplier)}' : 'ряд: ${Fmt.mult(kRowMultiplier)}',
              style: GType.num(
                size: 10,
                color: done ? GColors.green : GColors.textLo,
              ),
            ),
          ],
        ),
        const SizedBox(height: GS.s2),
        Row(
          children: [
            for (final a in row.items) ...[
              Expanded(child: _AchievementCell(a: a, done: unlocked.contains(a.id))),
              if (a != row.items.last) const SizedBox(width: GS.s2),
            ],
          ],
        ),
      ],
    );
  }
}

class _AchievementCell extends StatelessWidget {
  final Achievement a;
  final bool done;

  const _AchievementCell({required this.a, required this.done});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: done ? a.name : a.hint,
      textStyle: GType.ui(size: 12, color: GColors.textHi),
      decoration: BoxDecoration(
        color: GColors.surface3,
        borderRadius: BorderRadius.circular(GR.button),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? GColors.copperDim : GColors.wellBg,
            borderRadius: BorderRadius.circular(GR.button),
            border: Border.all(
              color: done ? GColors.amber : GColors.border,
            ),
            boxShadow: done
                ? const [BoxShadow(color: GColors.amberGlow, blurRadius: 10)]
                : null,
          ),
          child: Text(
            done ? a.name : a.hint,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GType.ui(
              size: 9,
              weight: done ? FontWeight.w700 : FontWeight.w400,
              color: done ? GColors.textHi : GColors.textLo,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

/// Вкладка «Витя»: похмелье, итоги и сброс.
///
/// Похмелье объясняется ЗАРАНЕЕ, ещё до того как станет доступным. Это не
/// вежливость: игры теряют игроков ровно перед кнопкой престижа, потому что
/// никто не понимает, что она делает, — подсказка с превью даёт заметный
/// прирост удержания.
class _VityaTab extends ConsumerWidget {
  const _VityaTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(gameProvider.select((s) => s.prestige));
    final pending = p.pendingWisdom;
    final progress = (p.totalEverEarned /
            ((p.wisdom + 1) * (p.wisdom + 1) * PrestigeState.mlPerWisdomStep))
        .clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      children: [
        _Panel(
          child: Column(
            children: [
              Text('МУДРОСТЬ', style: GType.label()),
              Text(
                '${p.wisdom}',
                style: GType.num(
                  size: 36,
                  weight: FontWeight.w700,
                  color: GColors.amber,
                ),
              ),
              Text(
                '+${(PrestigeState.bonusPerWisdom * 100 * p.wisdom).toStringAsFixed(0)}% ко всему производству',
                style: GType.body(),
              ),
            ],
          ),
        ),
        const SizedBox(height: GS.s3),
        _Panel(
          child: Column(
            children: [
              _StatLine('Нагнано за всё время', Fmt.volume(p.totalEverEarned)),
              const SizedBox(height: GS.s2),
              _StatLine('Похмелий пережито', '${p.hangovers}'),
            ],
          ),
        ),
        const SizedBox(height: GS.s3),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ПОХМЕЛЬЕ', style: GType.label()),
              const SizedBox(height: GS.s2),
              Text(
                pending > 0
                    ? 'Витя проснётся в пустом гараже: аппараты и деньги исчезнут. '
                        'Но останется мудрость — и следующий заход пойдёт быстрее.'
                    : 'Витя пока бодр. Когда нагонит достаточно, можно будет лечь '
                        'проспаться: гараж обнулится, но мудрость останется навсегда.',
                style: GType.body(),
              ),
              const SizedBox(height: GS.s3),
              if (pending <= 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(GR.pill),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        const ColoredBox(
                          color: GColors.wellBg,
                          child: SizedBox.expand(),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: const ColoredBox(color: GColors.copper),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: GS.s2),
                Text(
                  'До следующей мудрости: ${(progress * 100).toStringAsFixed(0)}%',
                  style: GType.num(size: 11, color: GColors.textMid),
                ),
              ],
              const SizedBox(height: GS.s3),
              _WideButton(
                label: pending > 0 ? 'ЛЕЧЬ ПРОСПАТЬСЯ · +$pending' : 'ЕЩЁ РАНО',
                enabled: pending > 0,
                onTap: () => _confirmPrestige(context, ref, pending),
              ),
            ],
          ),
        ),
        const SizedBox(height: GS.s6),
        _WideButton(
          label: 'НАЧАТЬ ЗАНОВО',
          enabled: true,
          danger: true,
          onTap: () => _confirmReset(context, ref),
        ),
        const SizedBox(height: GS.s2),
        Text(
          'Сброс стирает всё, включая мудрость.',
          textAlign: TextAlign.center,
          style: GType.num(size: 11, color: GColors.textLo),
        ),
      ],
    );
  }

  Future<void> _confirmPrestige(BuildContext context, WidgetRef ref, int pending) async {
    final ok = await _ask(
      context,
      title: 'Лечь проспаться?',
      body: 'Аппараты, улучшения и деньги исчезнут.\n'
          'Витя получит +$pending мудрости навсегда.',
      confirm: 'Спать',
    );
    if (ok) ref.read(gameProvider.notifier).sleepItOff();
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await _ask(
      context,
      title: 'Начать заново?',
      body: 'Сотрётся весь прогресс, включая мудрость и историю. '
          'Отменить это будет нельзя.',
      confirm: 'Стереть',
      danger: true,
    );
    if (ok) await ref.read(gameProvider.notifier).hardReset();
  }

  Future<bool> _ask(
    BuildContext context, {
    required String title,
    required String body,
    required String confirm,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GColors.surface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GR.card),
        ),
        title: Text(title, style: GType.ui(size: 16, weight: FontWeight.w600)),
        content: Text(body, style: GType.body()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: GType.ui(size: 14, color: GColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirm,
              style: GType.ui(
                size: 14,
                weight: FontWeight.w700,
                color: danger ? GColors.hot : GColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GS.s4),
      decoration: BoxDecoration(
        color: GColors.surface2,
        borderRadius: BorderRadius.circular(GR.card),
        border: Border.all(color: GColors.border),
      ),
      child: child,
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GType.body()),
        Text(
          value,
          style: GType.num(size: 13, weight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _WideButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool danger;
  final VoidCallback onTap;

  const _WideButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GR.button),
          gradient: enabled && !danger
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [GColors.amber, GColors.amberDim],
                )
              : null,
          color: enabled && !danger ? null : GColors.wellBg,
          border: Border.all(
            color: danger ? GColors.hot : (enabled ? GColors.amber : GColors.border),
          ),
        ),
        child: Text(
          label,
          style: GType.ui(
            size: 14,
            weight: FontWeight.w700,
            color: danger
                ? GColors.hot
                : (enabled ? GColors.onAmber : GColors.textLo),
          ),
        ),
      ),
    );
  }
}

/// Портрет с подсказкой для самого начала.
///
/// Без неё игра не сообщает главного: что жать надо по Вите. Тестировавший
/// нашёл это перебором — значит подсказки не хватало. Она живёт ровно до
/// первого нажатия и больше не появляется.
class _PortraitWithHint extends ConsumerStatefulWidget {
  final Widget portrait;
  const _PortraitWithHint({required this.portrait});

  @override
  ConsumerState<_PortraitWithHint> createState() => _PortraitWithHintState();
}

class _PortraitWithHintState extends ConsumerState<_PortraitWithHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taps = ref.watch(gameProvider.select((s) => s.clicker.totalTaps));
    if (taps > 0) return widget.portrait;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(scale: 1 + 0.04 * t, child: child),
            const SizedBox(height: GS.s2),
            Opacity(
              opacity: 0.55 + 0.45 * t,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: GColors.amber,
                  borderRadius: BorderRadius.circular(GR.pill),
                ),
                child: Text(
                  'ЖМИ ПО ВИТЕ — ОН ПОДКИНЕТ ДРОВ',
                  style: GType.ui(
                    size: 10,
                    weight: FontWeight.w700,
                    color: GColors.onAmber,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.portrait,
    );
  }
}

/// Тёплый свет лампы под потолком гаража.
class _LampLight extends StatelessWidget {
  const _LampLight();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.85),
            radius: 1.0,
            colors: [GColors.lampGlow, Color(0x0014100C)],
            stops: [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}

/// Счётчик литров. Плавно догоняет реальное значение, иначе при тике раз в
/// 200 мс число дёргается скачками и «дешевит» ощущение.
class _Counter extends ConsumerStatefulWidget {
  const _Counter();

  @override
  ConsumerState<_Counter> createState() => _CounterState();
}

class _CounterState extends ConsumerState<_Counter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _shown = 0;
  String _last = '';
  Duration _prev = Duration.zero;

  @override
  void initState() {
    super.initState();
    _shown = ref.read(gameProvider).resources.money;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = _prev == Duration.zero ? 0.016 : (now - _prev).inMicroseconds / 1e6;
    _prev = now;

    // Касса сглаживается: при продаже число не должно прыгать скачком.
    final target = ref.read(gameProvider).resources.money;
    _shown += (target - _shown) * (dt * 9).clamp(0.0, 1.0);

    final text = Fmt.money(_shown);
    if (text != _last) {
      _last = text;
      if (mounted) setState(() {});
    }
    // Бак и рынок меняются непрерывно — обновляем каждый кадр.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final now = DateTime.now();
    final price = Market.pricePerLitre(now, state.upgrades);
    final value = state.resources.ml * Market.pricePerMl(now, state.upgrades);
    final goodMoment = Market.isGoodMoment(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s3, GS.s4, GS.s2),
      child: Column(
        children: [
          Text('КАССА', style: GType.label()),
          Text(Fmt.money(_shown), style: GType.counter()),
          const SizedBox(height: GS.s2),
          _TankBar(
            fraction: state.tankFraction,
            ml: state.resources.ml,
            capacity: state.tankCapacity,
            rate: state.mlPerSecond,
            heat: ref.watch(heatMultiplierProvider),
            buffer: state.tankBuffer,
            full: state.isTankFull,
          ),
          const SizedBox(height: GS.s2),
          Row(
            children: [
              Expanded(
                child: _SellButton(
                  value: value,
                  // Кнопка не должна предлагать продать на ноль рублей:
                  // раньше при копейках в баке она выглядела активной и
                  // обещала «ПРОДАТЬ · 0 ₽».
                  enabled: value >= 1,
                  hot: goodMoment,
                  onTap: () => ref.read(gameProvider.notifier).sell(),
                ),
              ),
              const SizedBox(width: GS.s3),
              _PriceTag(price: price, hot: goodMoment),
            ],
          ),
        ],
      ),
    );
  }
}

/// Бак: сколько налито и как быстро прибывает. Полный бак — красный сигнал,
/// потому что в этот момент аппараты стоят.
class _TankBar extends StatelessWidget {
  final double fraction;
  final double ml;
  final double capacity;
  final double rate;
  final double heat;
  final Duration buffer;
  final bool full;

  const _TankBar({
    required this.fraction,
    required this.ml,
    required this.capacity,
    required this.rate,
    required this.heat,
    required this.buffer,
    required this.full,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(GR.pill),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                const ColoredBox(color: GColors.wellBg, child: SizedBox.expand()),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: full
                            ? const [GColors.hot, GColors.hot]
                            : const [GColors.brew, GColors.amber],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              // Запас времени важнее литров: именно его покупают, расширяя тару.
              rate > 0 && !full
                  ? '${Fmt.volume(ml)} / ${Fmt.volume(capacity)} · хватит на ${Fmt.duration(buffer)}'
                  : '${Fmt.volume(ml)} / ${Fmt.volume(capacity)}',
              style: GType.num(size: 11, color: GColors.textMid),
            ),
            if (full)
              Text(
                'БАК ПОЛОН — АППАРАТЫ СТОЯТ',
                style: GType.num(size: 11, color: GColors.hot),
              )
            else if (rate <= 0)
              Text('аппараты простаивают', style: GType.num(size: 11, color: GColors.copper))
            else if (heat > 1.001)
              // Показываем фактическую скорость: без этого не видно, что даёт жар.
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: Fmt.short(rate),
                    style: GType.num(size: 11, color: GColors.textLo).copyWith(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  TextSpan(
                    text: '  ${Fmt.rate(rate * heat)}',
                    style: GType.num(
                      size: 11,
                      weight: FontWeight.w700,
                      color: GColors.green,
                    ),
                  ),
                ]),
              )
            else
              Text(Fmt.rate(rate), style: GType.num(size: 11, color: GColors.copper)),
          ],
        ),
      ],
    );
  }
}

/// Кнопка продажи. Янтарная — только когда есть что сдавать; на пике рынка
/// добавляется свечение, чтобы момент было видно боковым зрением.
class _SellButton extends StatefulWidget {
  final double value;
  final bool enabled;
  final bool hot;
  final VoidCallback onTap;

  const _SellButton({
    required this.value,
    required this.enabled,
    required this.hot,
    required this.onTap,
  });

  @override
  State<_SellButton> createState() => _SellButtonState();
}

class _SellButtonState extends State<_SellButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: on
          ? () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GR.button),
            gradient: on
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [GColors.amber, GColors.amberDim],
                  )
                : null,
            color: on ? null : GColors.wellBg,
            border: on ? null : Border.all(color: GColors.border),
            boxShadow: on && widget.hot
                ? const [BoxShadow(color: GColors.amberGlow, blurRadius: 20)]
                : null,
          ),
          child: Text(
            on ? 'ПРОДАТЬ · ${Fmt.money(widget.value)}' : 'НЕЧЕГО ПРОДАВАТЬ',
            style: GType.ui(
              size: 14,
              weight: FontWeight.w700,
              color: on ? GColors.onAmber : GColors.textLo,
            ),
          ),
        ),
      ),
    );
  }
}

/// Текущая цена на рынке. Её видно всегда — иначе решение «продавать сейчас
/// или подождать» превращается в угадайку.
class _PriceTag extends StatelessWidget {
  final double price;
  final bool hot;

  const _PriceTag({required this.price, required this.hot});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: GS.s3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GColors.wellBg,
        borderRadius: BorderRadius.circular(GR.button),
        border: Border.all(color: hot ? GColors.amber : GColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('РЫНОК', style: GType.label().copyWith(fontSize: 9)),
          Text(
            Fmt.pricePerLitre(price),
            style: GType.num(
              size: 12,
              weight: FontWeight.w700,
              color: hot ? GColors.amber : GColors.textHi,
            ),
          ),
        ],
      ),
    );
  }
}

/// Нижняя полка: вкладки и списки покупок.
class _Shelf extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  const _Shelf({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GR.sheet)),
        boxShadow: GShadow.sheet,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(GS.s4, GS.s3, GS.s4, GS.s2),
            child: _Tabs(index: tab, onChanged: onTab),
          ),
          Expanded(
            child: switch (tab) {
              0 => const _StillsTab(),
              1 => const _UpgradesTab(),
              2 => const _GoalsTab(),
              _ => const _VityaTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.index, required this.onChanged});

  static const _labels = ['АППАРАТЫ', 'УЛУЧШЕНИЯ', 'ЦЕЛИ', 'ВИТЯ'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GColors.wellBg,
        borderRadius: BorderRadius.circular(GR.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: gEase,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? GColors.copper : null,
                    borderRadius: BorderRadius.circular(GR.pill),
                  ),
                  child: Text(
                    _labels[i],
                    // Четыре вкладки на телефоне — подпись должна влезать.
                    style: GType.tab().copyWith(
                      fontSize: 11,
                      color: i == index ? GColors.textHi : GColors.textMid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StillsTab extends ConsumerWidget {
  const _StillsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final engine = ref.read(gameEngineProvider);
    final gens = state.generators.items;
    // Аппараты покупаются за ДЕНЬГИ, а не за товар в баке.
    final money = state.resources.money;

    // Открыт первый аппарат и любой следующий за уже купленным — лестница
    // ведёт игрока и не вываливает сразу 13 позиций.
    bool unlocked(int i) => i == 0 || gens[i - 1].ownedCount > 0;

    final visible = <int>[];
    for (var i = 0; i < gens.length; i++) {
      if (unlocked(i)) {
        visible.add(i);
      } else {
        visible.add(i); // одна закрытая строка-дразнилка
        break;
      }
    }

    final bulk = state.achievements.hasPerk(AchievementPerk.bulkBuy);
    final mode = ref.watch(buyAmountProvider);

    return Column(
      children: [
        if (bulk)
          Padding(
            padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, 0),
            child: _BuyAmountSelector(mode: mode),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: GS.s2),
            itemBuilder: (context, k) {
              final i = visible[k];
              final g = gens[i];
              final open = unlocked(i);

              // Сколько уйдёт за одно нажатие в текущем режиме.
              final wanted = (!bulk || mode == 1)
                  ? 1
                  : (mode == kBuyMax ? engine.affordableCount(state, g) : mode);
              final count = wanted < 1 ? 1 : wanted;
              final cost = count > 1
                  ? engine.bulkCost(g, count)
                  : engine.generatorCost(g);

              return StillRow(
                name: g.name,
                owned: g.ownedCount,
                output: Production.generatorOutput(
                  g,
                  state.generators,
                  state.upgrades,
                  state.prestige,
                  state.achievements.multiplier,
                ),
                cost: cost,
                buyCount: count,
                affordable: open && money >= cost,
                locked: !open,
                onBuy: () => ref
                    .read(gameProvider.notifier)
                    .buyGenerator(g.id, count: count),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UpgradesTab extends ConsumerWidget {
  const _UpgradesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    // Улучшения тоже покупаются за деньги.
    final money = state.resources.money;

    // Показываем только те, что уже имеют смысл: иначе список пугает.
    final visible = state.upgrades.items.where((u) {
      if (u.purchased) return true;
      return money >= u.cost * 0.35;
    }).toList();

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GS.s6),
          child: Text(
            'Пока нечего улучшать.\nГони дальше.',
            textAlign: TextAlign.center,
            style: GType.body(),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s2),
      itemBuilder: (context, i) {
        final u = visible[i];
        return UpgradeRow(
          name: u.name,
          effect: u.description,
          cost: u.cost,
          affordable: money >= u.cost,
          purchased: u.purchased,
          onBuy: () => ref.read(gameProvider.notifier).buyUpgrade(u.id),
        );
      },
    );
  }
}
