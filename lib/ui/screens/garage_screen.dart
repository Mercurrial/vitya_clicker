import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/achievements.dart';
import '../../core/formatters.dart';
import '../../engine/production.dart';
import '../../models/achievement.dart';
import '../../models/prestige_state.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../game/heat_gauge.dart';
import '../game/vitya_portrait.dart';
import '../pixel/garage_scene.dart';
import '../pixel/pixel_portrait.dart';
import '../theme/garage.dart';
import '../widgets/shop.dart';
import '../widgets/top_panel.dart';
import '../widgets/transfer_progress.dart';
import '../widgets/vitya_toast.dart';

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
    // Жар живёт в интерфейсе, но двигает и СОРТ, и всё производство —
    // поэтому и состояние окна, и множитель серии непрерывно отдаём в игру.
    _heat.addListener(_pushHeat);
  }

  void _pushHeat() {
    ref.read(heatStatusProvider.notifier).state = _heat.status;
    ref.read(heatMultiplierProvider.notifier).state = _heat.multiplier;
  }

  @override
  void dispose() {
    _heat.removeListener(_pushHeat);
    _heat.dispose();
    super.dispose();
  }

  void _startStoking() {
    _heat.startStoking();
    ref.read(gameProvider.notifier).registerTouch();
  }

  void _stopStoking() => _heat.stopStoking();

  @override
  Widget build(BuildContext context) {
    final era = ref.watch(
      gameProvider.select((s) => _eraFor(s.prestige.totalEverEarned)),
    );

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
                    TopPanel(heat: _heat),
                    // Гараж — центр экрана. Портрет висит на его стене, а
                    // купленные аппараты встают на полки: империю видно.
                    //
                    // На низком окне сцена уступает место списку: иначе нижняя
                    // панель уезжает за край и до кнопок не добраться.
                    Expanded(
                      flex: MediaQuery.of(context).size.height < 760 ? 3 : 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: GS.s3),
                        // Без AnimatedBuilder намеренно: сцена подписывается
                        // на жар сама, и только теми частями, которые от него
                        // рисуются. Обёртка здесь перестраивала бы всё дерево
                        // сцены шестьдесят раз в секунду.
                        // Зажимать можно ВЕЗДЕ по сцене, а не только по
                        // портрету. Целиться в маленькую картинку, чтобы
                        // подкинуть дров, было неинтуитивно: гараж — это и
                        // есть кнопка.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _startStoking(),
                          onTapUp: (_) => _stopStoking(),
                          onTapCancel: _stopStoking,
                          onLongPressDown: (_) => _startStoking(),
                          onLongPressUp: _stopStoking,
                          onLongPressCancel: _stopStoking,
                          child: GarageScene(
                            heat: _heat,
                            hanging: _PortraitWithHint(
                              portrait: VityaPortrait(
                                era: era,
                                onPress: _startStoking,
                                onRelease: _stopStoking,
                                // 98, а не 116: при 116 портрет съедал шестьдесят
                                // процентов сцены, и на аппараты оставалось
                                // столько, что первая банка выходила ростом в
                                // полтора сантиметра. Витя главный, но гараж —
                                // не только он.
                                size: 98,
                                style: PixelPortraitStyle.pixel,
                                radius: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(GS.s6, GS.s3, GS.s6, GS.s3),
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
          // Плашки событий — поверх сцены, но ниже переключателя.
          Positioned(
            top: MediaQuery.of(context).padding.top + 44,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kPhoneWidth),
                child: const VityaToast(),
              ),
            ),
          ),
        ],
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
              done
                  ? 'ряд закрыт · ${Fmt.mult(kRowMultiplier)}'
                  : 'ряд: ${Fmt.mult(kRowMultiplier)}',
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
              Expanded(
                  child: _AchievementCell(a: a, done: unlocked.contains(a.id))),
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
    final progress = p.progressToNext;

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
        const SizedBox(height: GS.s3),
        const TransferProgress(),
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

  Future<void> _confirmPrestige(
      BuildContext context, WidgetRef ref, int pending) async {
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
            child: Text('Отмена',
                style: GType.ui(size: 14, color: GColors.textMid)),
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
            color: danger
                ? GColors.hot
                : (enabled ? GColors.amber : GColors.border),
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
        // Подсказка лежит НАД сценой, а не в её колонке. Пока она была
        // обычной строкой, она отъедала высоту у полок, и первая купленная
        // банка сжималась до точки — видно на снимке экрана. Заодно пропал
        // скачок вёрстки в момент, когда подсказка исчезает.
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Transform.scale(scale: 1 + 0.04 * t, child: child),
            Positioned(
              bottom: -26,
              child: Opacity(
                opacity: 0.55 + 0.45 * t,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: GColors.amber,
                    borderRadius: BorderRadius.circular(GR.pill),
                  ),
                  child: Text(
                    'ЖМИ ПО ВИТЕ — ОН ПОДКИНЕТ ДРОВ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.ui(
                      size: 10,
                      weight: FontWeight.w700,
                      color: GColors.onAmber,
                      letterSpacing: 0.5,
                    ),
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

/// Показывать ли уже купленные улучшения.
///
/// По умолчанию нет. Список рос с каждой покупкой, купленное копилось сверху,
/// и найти то, что ещё можно взять, становилось всё труднее — а именно за
/// этим на вкладку и заходят.
final showBoughtUpgradesProvider = StateProvider<bool>((ref) => false);

class _UpgradesTab extends ConsumerWidget {
  const _UpgradesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final showBought = ref.watch(showBoughtUpgradesProvider);
    // Улучшения тоже покупаются за деньги.
    final money = state.resources.money;

    final bought = state.upgrades.items.where((u) => u.purchased).length;

    // Показываем только те, что уже имеют смысл: иначе список пугает.
    final visible = state.upgrades.items.where((u) {
      if (u.purchased) return showBought;
      return money >= u.cost * 0.35;
    }).toList();

    // Кнопка «показать купленное» идёт последней строкой списка, а не над
    // ним: сверху она отодвигала бы то, ради чего на вкладку заходят.
    final extra = bought > 0 ? 1 : 0;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      itemCount: visible.isEmpty ? 1 + extra : visible.length + extra,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s2),
      itemBuilder: (context, i) {
        if (visible.isEmpty && i == 0) {
          return Padding(
            padding: const EdgeInsets.all(GS.s6),
            child: Text(
              'Пока нечего улучшать.\nГони дальше.',
              textAlign: TextAlign.center,
              style: GType.body(),
            ),
          );
        }
        if (i >= visible.length) {
          return _ToggleBought(count: bought, showing: showBought);
        }
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

/// Кнопка «показать купленное».
class _ToggleBought extends ConsumerWidget {
  final int count;
  final bool showing;

  const _ToggleBought({required this.count, required this.showing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(showBoughtUpgradesProvider.notifier).state = !showing;
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(top: GS.s2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GR.pill),
          border: Border.all(color: GColors.border),
        ),
        child: Text(
          showing ? 'СКРЫТЬ КУПЛЕННОЕ' : 'ПОКАЗАТЬ КУПЛЕННОЕ · $count',
          style: GType.label(),
        ),
      ),
    );
  }
}
