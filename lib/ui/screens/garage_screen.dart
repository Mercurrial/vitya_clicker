import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sfx.dart';
import '../../models/game_state.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../game/heat_gauge.dart';
import '../game/vitya_portrait.dart';
import '../pixel/garage_scene.dart';
import '../pixel/pixel_portrait.dart';
import '../theme/garage.dart';
import '../widgets/top_panel.dart';
import '../widgets/vitya_toast.dart';
import 'shelf.dart';
import 'shelf_sheet.dart';

export 'shelf.dart' show buyAmountProvider, kBuyMax, kBuyModes;
export 'shelf_sheet.dart' show ShelfPosition, shelfPositionProvider;

/// Ширина «телефона»: на широком экране игра не растягивается, иначе карточки
/// разъезжаются на пол-экрана и верстка ломается.
const double _kPhoneWidth = 460;

class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final HeatController _heat;
  int _tab = 0;

  /// Прошлое состояние жара — чтобы не звенеть «в окне» при выходе из
  /// паузы: жар в окне и был, нового попадания игрок не сделал.
  HeatStatus _lastStatus = HeatStatus.off;

  @override
  void initState() {
    super.initState();
    _heat = HeatController(vsync: this);
    // Жар живёт в интерфейсе, но двигает и СОРТ, и всё производство —
    // поэтому и состояние окна, и множитель серии непрерывно отдаём в игру.
    _heat.addListener(_pushHeat);
    // Звук жара привязан к СМЕНЕ состояния, а не к кадру: контроллер тикает
    // шестьдесят раз в секунду, и «играть при перегреве» означало бы шестьдесят
    // сирен в секунду.
    _heat.statusNotifier.addListener(_onHeatStatus);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onHeatStatus() {
    final was = _lastStatus;
    _lastStatus = _heat.status;
    if (was == HeatStatus.paused) return;
    switch (_heat.status) {
      case HeatStatus.inWindow:
        ref.read(feedbackProvider).play(Sfx.window);
      case HeatStatus.overheated:
        ref.read(feedbackProvider).hit(Sfx.overheat, Buzz.medium);
      case HeatStatus.off:
      case HeatStatus.paused:
        break;
    }
  }

  /// Ушли из игры с зажатым пальцем — отпускаем за игрока.
  ///
  /// В браузере это не редкость, а обычное дело: Alt+Tab, переключение
  /// вкладки, свёрнутое окно. Событие «отпустил» при этом не приходит вовсе, и
  /// жар остаётся включённым навсегда — вернувшись, игрок застаёт вечный
  /// перегрев и никак не может его снять.
  ///
  /// Здесь же останавливаются часы «времени в игре». Считается, пока игра
  /// ВИДНА: окно без фокуса (inactive) — это игра на соседнем мониторе, и
  /// idle-игру так и держат. Свёрнутая вкладка, свёрнутое приложение,
  /// погасший экран — уже нет.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopStoking();
    ref.read(onScreenProvider.notifier).state =
        state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
  }

  /// Пробел и Enter — тот же зажим, что и палец.
  ///
  /// На компьютере держать кнопку мыши минутами неудобно, а игра требует
  /// именно этого. Автоповтор клавиши (`KeyRepeatEvent`) намеренно съедается:
  /// он не значит «нажал ещё раз», а зажим у нас и так непрерывный.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.space &&
        event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _startStoking();
    } else if (event is KeyUpEvent) {
      _stopStoking();
    }
    return KeyEventResult.handled;
  }

  void _pushHeat() {
    ref.read(heatStatusProvider.notifier).state = _heat.status;
    ref.read(heatMultiplierProvider.notifier).state = _heat.multiplier;
    ref.read(heatHoldingProvider.notifier).state = _heat.isStoking;
    // Контроллер жара уведомляет на каждом кадре — это и есть пульс «игра на
    // экране» для времени в игре. Если тикер жара когда-нибудь станут
    // останавливать ради батареи, пульс надо брать в другом месте, иначе
    // время в игре встанет вместе с ним.
    ref.read(framePulseProvider).beat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heat.statusNotifier.removeListener(_onHeatStatus);
    _heat.removeListener(_pushHeat);
    _heat.dispose();
    super.dispose();
  }

  void _startStoking() {
    // Магазин развёрнут — руки заняты. Пробел на компьютере сюда доходит,
    // хотя гаража не видно.
    if (_heat.paused) return;
    _heat.startStoking();
    ref.read(gameProvider.notifier).registerTouch();
    setState(() {}); // портрет показывает отдачу
  }

  void _stopStoking() {
    _heat.stopStoking();
    if (mounted) setState(() {});
  }

  /// Что с Витей происходит прямо сейчас.
  ///
  /// Порядок важен: сначала то, что требует действия, потом то, что просто
  /// приятно.
  VityaMood _moodFor(GameState state) {
    if (_heat.status == HeatStatus.overheated) return VityaMood.burnt;
    if (state.isTankFull) return VityaMood.stuck;
    if (_heat.status == HeatStatus.inWindow) return VityaMood.inWork;
    return VityaMood.calm;
  }

  @override
  Widget build(BuildContext context) {
    final era = ref.watch(
      gameProvider.select((s) => vityaEraFor(s.prestige.totalEverEarned)),
    );
    final mood = _moodFor(ref.watch(gameProvider));
    // Улучшения «руки» расширяют окно жара. Контроллер живёт в интерфейсе,
    // поэтому множитель ему отдаёт экран — при каждой сборке, дёшево.
    _heat.windowScale = ref.watch(
      gameProvider.select((s) => s.upgrades.heatControlMultiplier),
    );

    // Шторка развёрнута — у Вити заняты руки. Пауза ставится там, где
    // решается положение, а не в кадре анимации: тянуть шторку ещё не
    // значит уйти в магазин.
    // В слушателе, а не присваиванием в build: пауза уведомляет
    // подписчиков жара, а те пишут в провайдеры — посреди сборки нельзя.
    ref.listen(shelfPositionProvider, (_, to) {
      _heat.paused = to == ShelfPosition.shop;
    });
    final shop = ref.watch(shelfPositionProvider) == ShelfPosition.shop;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: GColors.bg,
        child: Stack(
          children: [
            const Positioned.fill(child: _LampLight()),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kPhoneWidth),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, c) => Stack(
                      children: [
                        Column(
                          children: [
                            const TopPanel(),
                            Expanded(child: _garage(era, mood)),
                            // Место под шторку в положении «Гараж»: сама
                            // шторка лежит поверх, а гараж над ней получает
                            // всё остальное. Пришёл гость — ужимается сцена,
                            // а не магазин.
                            SizedBox(height: shelfGarageHeight(c.maxHeight)),
                          ],
                        ),
                        Positioned.fill(
                          child: ShelfSheet(
                            strip: AnimatedBuilder(
                              animation: _heat,
                              builder: (context, _) => ShopStrip(
                                series: _heat.seriesMultiplier,
                                onTap: () => ref.read(shelfPositionProvider.notifier).state =
                                    ShelfPosition.garage,
                              ),
                            ),
                            child: Shelf(
                              tab: _tab,
                              onTab: (i) => setState(() => _tab = i),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Плашки событий — поверх всего. В гараже — под строкой кассы, над
            // сценой. В развёрнутом магазине — внизу: сверху там вкладки и
            // первые строки списка, а цели берутся как раз покупками, и
            // плашка закрывала бы то, что сейчас покупают.
            Positioned(
              top: shop ? null : MediaQuery.of(context).padding.top + kShopStripHeight,
              bottom: shop ? MediaQuery.of(context).padding.bottom + GS.s4 : null,
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
      ),
    );
  }

  /// Гараж: сцена и пульт жара под ней — вся эта область зажимается.
  ///
  /// Пульт — в низу сцены, под пальцем: зажимают там же, где смотрят на
  /// шкалу. Снизу — поле под ручку шторки: она выступает над своим краем
  /// (см. kShelfGrabOverhang) и заходит на нижнее поле пульта, где ни
  /// надписей, ни шкалы.
  Widget _garage(VityaEra era, VityaMood mood) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s3, 0, GS.s3, kShelfGrabOverhang - 6),
      // Зажимать можно ВЕЗДЕ по гаражу: гараж — это и есть кнопка.
      // Listener, а не GestureDetector: арена жестов откладывает решение, и
      // зажим не начинался вовсе. MouseRegion — ради браузера: курсор
      // говорит, что гараж нажимается, а onExit снимает жар, если мышь
      // увели с гаража с зажатой кнопкой.
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onExit: (_) => _stopStoking(),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _startStoking(),
          onPointerUp: (_) => _stopStoking(),
          onPointerCancel: (_) => _stopStoking(),
          child: Column(
            children: [
              // Портрет висит на стене, аппараты стоят на полу и на полках:
              // империю видно.
              Expanded(
                child: GarageScene(
                  heat: _heat,
                  portrait: (size) => VityaPortrait(
                    era: era,
                    mood: mood,
                    pressed: _heat.isStoking,
                    size: size,
                    style: PixelPortraitStyle.pixel,
                    radius: 0,
                  ),
                ),
              ),
              const SizedBox(height: GS.s2),
              HeatPanel(controller: _heat),
            ],
          ),
        ),
      ),
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

