import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/bootstrap.dart';
import 'core/game_clock.dart';
import 'core/sfx_player.dart';
import 'providers/feedback_provider.dart';
import 'providers/game_provider.dart';
import 'ui/game/vitya_portrait.dart';
import 'ui/screens/balance_news.dart';
import 'ui/screens/garage_screen.dart';
import 'ui/screens/test_save_notice.dart';
import 'ui/screens/welcome_back.dart';
import 'providers/settings_provider.dart';
import 'ui/theme/garage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // В браузере правая кнопка над игрой открывала бы меню «Сохранить картинку
  // как…». Игре оно ни к чему, а во время зажима — прямо мешает.
  if (kIsWeb) BrowserContextMenu.disableContextMenu();

  // Гараж свёрстан под вертикальный экран: в альбоме сцена и магазин не
  // помещаются одновременно. Проще запретить поворот, чем делать вторую
  // вёрстку ради положения, в котором в эту игру никто не играет.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Системные панели — в цвет гаража, значки светлые.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: GColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Сейв поднимается ДО первого кадра: игрок сразу видит свой гараж, а не
  // пустой экран, который через мгновение подменится загруженными данными.
  final boot = await bootstrapGame();

  runApp(
    ProviderScope(
      overrides: [
        initialStateProvider.overrideWithValue(boot.state),
        saveServiceProvider.overrideWithValue(boot.saves),
        settingsStoreProvider.overrideWithValue(boot.settings),
        // Настоящий звук подставляется только здесь. Во всех тестах остаётся
        // тишина по умолчанию — ни один из них не пытается открыть динамик.
        soundOutputProvider.overrideWith((ref) {
          final output = AudioSfxOutput();
          ref.onDispose(output.dispose);
          return output;
        }),
      ],
      child: VityaApp(boot: boot),
    ),
  );
}

class VityaApp extends StatelessWidget {
  final Bootstrap boot;
  const VityaApp({super.key, required this.boot});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kGameTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GColors.bg,
        fontFamily: GType.uiFamily,
        useMaterial3: true,
      ),
      home: _Root(boot: boot),
    );
  }
}

/// Следит за жизненным циклом: при сворачивании пишет прогресс и гасит
/// ускорение, после сна показывает, сколько накопилось потока.
class _Root extends ConsumerStatefulWidget {
  final Bootstrap boot;
  const _Root({required this.boot});

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Диалоги показываем после первого кадра, иначе контекст ещё не готов.
    //
    // Порядок важен: сперва «что изменилось», потом «сколько накапало». Если
    // поменялся баланс, игрок должен узнать об этом ДО того, как увидит
    // цифры, — иначе он успеет решить, что игра сломалась.
    if (widget.boot.testSaveDropped ||
        widget.boot.hasBalanceNews ||
        widget.boot.shouldGreet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIntro());
    }
  }

  Future<void> _openIntro() async {
    if (!mounted) return;
    if (widget.boot.testSaveDropped) {
      await showTestSaveNotice(context);
      // Сообщение показывается, пока своего сейва нет. Запись сразу — чтобы
      // закрытое до автосейва приложение не повторило его без нужды.
      await ref.read(gameProvider.notifier).saveNow();
      if (!mounted) return;
    }
    if (widget.boot.hasBalanceNews) {
      await showBalanceNews(context, widget.boot.balanceNews);
      // Отметка о просмотре — это запись сейва с текущей версией баланса.
      // Пока она не легла на диск, экран покажется снова; так честнее, чем
      // потерять уведомление из-за закрытия приложения.
      await ref.read(gameProvider.notifier).saveNow();
    }
    if (!mounted || !widget.boot.shouldGreet) return;
    _greet(widget.boot.offline, widget.boot.fluxGained);
  }

  void _greet(OfflineResult away, double gained) {
    final s = ref.read(gameProvider);
    showWelcomeBack(
      context,
      away: away,
      gained: gained,
      flux: s.flux,
      era: vityaEraFor(s.prestige.totalEverEarned),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Возврат во вкладку ничего не начисляет: пока вкладка была скрыта, тики
  /// шли и гнали — это игра. Раньше здесь начислялся ещё и оффлайн от
  /// момента ухода, и отлучка короче бака засчитывалась дважды. Уснувшее
  /// приложение ловит тик — по разрыву во времени (`GameNotifier.afkGap`).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(gameProvider.notifier);
    switch (state) {
      case AppLifecycleState.inactive:
        // Окно без фокуса — игра на соседнем мониторе, её видно.
        notifier.saveNow();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Игру убрали с глаз — ускорение гаснет, иначе поток сгорит, пока
        // игрок не смотрит.
        notifier.stopBoost();
        notifier.saveNow();
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Система усыпляла игру — тик заметил разрыв и начислил поток.
    ref.listen<AfkReturn?>(afkReturnProvider, (_, back) {
      if (back == null) return;
      ref.read(afkReturnProvider.notifier).state = null;
      final full = ref.read(gameProvider).flux.isBankFull;
      if (mounted && back.away.isMeaningful && (back.gained > 0 || full)) {
        _greet(back.away, back.gained);
      }
    });
    return const Scaffold(
      backgroundColor: GColors.bg,
      body: GarageScreen(),
    );
  }
}
