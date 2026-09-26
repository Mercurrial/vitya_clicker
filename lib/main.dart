import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/bootstrap.dart';
import 'core/game_clock.dart';
import 'core/home_screen.dart';
import 'core/save_code.dart';
import 'core/sfx_player.dart';
import 'providers/feedback_provider.dart';
import 'providers/game_provider.dart';
import 'providers/ios_launch_provider.dart';
import 'ui/game/vitya_portrait.dart';
import 'ui/screens/balance_news.dart';
import 'ui/screens/garage_screen.dart';
import 'ui/screens/home_screen_hint.dart';
import 'ui/screens/save_rescue.dart';
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
        ...bootOverrides(boot),
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

/// Что игра получает от запуска. Отдельно от [main], чтобы тест собирал
/// игру ровно так же.
List<Override> bootOverrides(Bootstrap boot) => [
      initialStateProvider.overrideWithValue(boot.state),
      // Сейв новой версии: сервиса нет, и записать поверх нечем — ни
      // автосейву, ни сворачиванию. Гаража на экране нет и так, но запись
      // при сворачивании зовётся мимо экрана, и полагаться на то, что до
      // неё не дойдёт, — значит однажды затереть чужой прогресс.
      if (!boot.saveFromFuture) saveServiceProvider.overrideWithValue(boot.saves),
      settingsStoreProvider.overrideWithValue(boot.settings),
    ];

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
      // Сейв новой версии — не игра, а просьба обновиться (save_rescue.dart).
      home: boot.saveFromFuture
          ? const SaveFromFutureScreen()
          : _Root(boot: boot),
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
  /// Подсказать поставить игру на экран «Домой» (`core/home_screen.dart`).
  late final bool _suggestHomeScreen = shouldSuggestHomeScreen(
      ref.read(iosLaunchProvider), ref.read(settingsStoreProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Диалоги показываем после первого кадра, иначе контекст ещё не готов.
    //
    // Порядок важен. Сперва — что стало с сейвом: тестовый не перенесён,
    // свой не прочитался, отложенная копия снова читается. От этого зависит,
    // какой гараж перед игроком, а всё дальнейшее — уже про этот гараж.
    // Потом «что изменилось», потом «сколько накапало»: если поменялся
    // баланс, игрок должен узнать об этом ДО того, как увидит цифры, — иначе
    // он успеет решить, что игра сломалась.
    //
    // Подсказка «на экран Домой» — сразу после сообщений о сейве: она тоже
    // про то, где живёт этот гараж, и не должна их перебивать. Но до
    // новостей и возвращения — те про цифры и стоят вплотную к игре.
    final boot = widget.boot;
    if (boot.testSaveDropped ||
        boot.saveWasLost ||
        boot.rescuedGarage != null ||
        _suggestHomeScreen ||
        boot.hasBalanceNews ||
        boot.shouldGreet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIntro());
    }
  }

  Future<void> _openIntro() async {
    if (!mounted) return;
    final boot = widget.boot;
    if (boot.testSaveDropped) {
      await showTestSaveNotice(context);
      // Сообщение показывается, пока своего сейва нет. Запись сразу — чтобы
      // закрытое до автосейва приложение не повторило его без нужды.
      await ref.read(gameProvider.notifier).saveNow();
      if (!mounted) return;
    }
    final broken = boot.brokenSave;
    if (broken != null) {
      await showBrokenSaveNotice(context,
          save: broken, kept: boot.brokenSaveKept);
      // Так же, как с тестовым сейвом: сообщение живёт, пока битый сейв
      // лежит под основным ключом. Копия отложена ещё при запуске, до
      // первой записи, так что писать новый гараж уже можно.
      await ref.read(gameProvider.notifier).saveNow();
      if (!mounted) return;
    }
    final copy = boot.rescuedGarage;
    if (copy != null) {
      final restore = await offerRescuedGarage(
        context,
        copy: copy.state,
        current: ref.read(gameProvider),
      );
      if (restore && await _restore(copy)) {
        // Новости баланса и экран возвращения посчитаны для гаража, которого
        // больше нет, — показывать их про вернувшийся было бы неправдой.
        return;
      }
      if (!restore) await boot.saves.forget(copy.raw);
      if (!mounted) return;
    }
    if (_suggestHomeScreen) {
      // После возврата гаража из копии (return выше) подсказка ждёт
      // следующего запуска: закрыть её ещё не успели.
      await showHomeScreenHint(context);
      await markHomeScreenHintSeen(ref.read(settingsStoreProvider));
      if (!mounted) return;
    }
    if (boot.hasBalanceNews) {
      await showBalanceNews(context, boot.balanceNews);
      // Отметка о просмотре — это запись сейва с текущей версией баланса.
      // Пока она не легла на диск, экран покажется снова; так честнее, чем
      // потерять уведомление из-за закрытия приложения.
      await ref.read(gameProvider.notifier).saveNow();
    }
    if (!mounted || !boot.shouldGreet) return;
    _greet(boot.offline, boot.fluxGained);
  }

  /// Вернуть гараж из отложенной копии.
  ///
  /// Тем же путём, что и перенос кодом: тот же разбор с миграциями и та же
  /// запись, уже проверенные тестами переноса. Отдельная дорога в обход
  /// `GameNotifier` разошлась бы с ним при первой же правке формата.
  Future<bool> _restore(RescuedGarage copy) async {
    final error = await ref
        .read(gameProvider.notifier)
        .importCode(encodeSaveCode(copy.raw));
    if (error != null) return false;
    // Копия выбрасывается только после записи вернувшегося гаража: закрой
    // игру между ними — вопрос повторится, но гараж не пропадёт.
    await widget.boot.saves.forget(copy.raw);
    return true;
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
