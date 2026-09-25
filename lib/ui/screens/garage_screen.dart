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

export 'shelf.dart' show buyAmountProvider, kBuyMax, kBuyModes;

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
    switch (_heat.status) {
      case HeatStatus.inWindow:
        ref.read(feedbackProvider).play(Sfx.window);
      case HeatStatus.overheated:
        ref.read(feedbackProvider).hit(Sfx.overheat, Buzz.medium);
      case HeatStatus.off:
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
                    builder: (context, c) => Column(
                    children: [
                      const TopPanel(),
                      // Гараж — центр экрана. Портрет висит на стене, аппараты
                      // стоят на полу и на полках: империю видно.
                      //
                      // Высота — половина того, что остаётся после кассы и
                      // пульта, но в пределах: на низком окне магазин не
                      // должен сжиматься до одной строки, а на высоком сцена
                      // не должна растягиваться в пустую кирпичную стену.
                      SizedBox(
                        height: ((c.maxHeight - _fixedHeight) * 0.5).clamp(190.0, 380.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: GS.s3),
                          // Зажимать можно ВЕЗДЕ по сцене: гараж — это и есть
                          // кнопка. Listener, а не GestureDetector: арена жестов
                          // откладывает решение, и зажим не начинался вовсе.
                          // MouseRegion — ради браузера: курсор говорит, что
                          // гараж нажимается, а onExit снимает жар, если мышь
                          // увели со сцены с зажатой кнопкой.
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onExit: (_) => _stopStoking(),
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (_) => _startStoking(),
                              onPointerUp: (_) => _stopStoking(),
                              onPointerCancel: (_) => _stopStoking(),
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
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(GS.s3, GS.s2, GS.s3, GS.s2),
                        child: HeatPanel(controller: _heat),
                      ),
                      Expanded(
                        child: Shelf(
                          tab: _tab,
                          onTab: (i) => setState(() => _tab = i),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            ),
            // Плашки событий — поверх сцены, но ниже кассы.
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
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
}

/// Сколько по высоте занимают касса с продажей и пульт жара — всё, кроме
/// сцены и магазина. Оценка, а не замер: от неё зависит только то, как
/// остаток делится между сценой и магазином, и промах на десяток точек
/// ничего не ломает.
const double _fixedHeight = 300;

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

