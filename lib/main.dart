import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap.dart';
import 'providers/game_provider.dart';
import 'ui/screens/garage_screen.dart';
import 'ui/screens/welcome_back.dart';
import 'ui/theme/garage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Сейв поднимается ДО первого кадра: игрок сразу видит свой гараж, а не
  // пустой экран, который через мгновение подменится загруженными данными.
  final boot = await bootstrapGame();

  runApp(
    ProviderScope(
      overrides: [
        initialStateProvider.overrideWithValue(boot.state),
        saveServiceProvider.overrideWithValue(boot.saves),
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
      title: 'Витя гонит',
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

/// Следит за жизненным циклом: при сворачивании пишет прогресс, при возврате
/// начисляет за отсутствие. Без этого «idle» не работает как idle.
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

    // Итог отсутствия показываем после первого кадра, иначе контекст ещё не
    // готов к диалогу.
    if (widget.boot.shouldGreet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showWelcomeBack(
          context,
          offline: widget.boot.offline,
          gained: widget.boot.offlineGain,
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(gameProvider.notifier);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        notifier.saveNow();
      case AppLifecycleState.resumed:
        final away = ref.read(clockProvider).since(_leftAt);
        final before = ref.read(gameProvider).resources.litres;
        notifier.applyOffline(away.credited);
        final gained = ref.read(gameProvider).resources.litres - before;
        if (away.isMeaningful && gained > 0 && mounted) {
          showWelcomeBack(context, offline: away, gained: gained);
        }
    }
    if (state != AppLifecycleState.resumed) {
      _leftAt = ref.read(clockProvider).nowMillis();
    }
  }

  int? _leftAt;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: GColors.bg,
      body: GarageScreen(),
    );
  }
}
