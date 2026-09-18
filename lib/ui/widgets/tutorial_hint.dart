/// Подсказка обучения — одна строка внизу сцены.
///
/// Живёт поверх гаража, а не отдельной панелью: подсказка должна быть рядом с
/// тем, о чём говорит, и не двигать вёрстку, когда исчезает.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/tutorial.dart';
import '../../core/settings.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../theme/art_style.dart';
import '../theme/garage.dart';

/// Самый дальний пройденный шаг. Переживает перезапуск, но лежит в настройках,
/// а не в сейве: это не прогресс гаража, и поднимать ради него версию формата
/// сохранения незачем.
class TutorialProgress extends Notifier<TutorialStep> {
  @override
  TutorialStep build() {
    final saved = ref.read(settingsStoreProvider).read(SettingsKeys.tutorial);
    return TutorialStep.values.firstWhere(
      (s) => s.name == saved,
      orElse: () => TutorialStep.hold,
    );
  }

  void reach(TutorialStep step) {
    if (step.index <= state.index) return;
    state = step;
    ref.read(settingsStoreProvider).write(SettingsKeys.tutorial, step.name);
  }
}

final tutorialProgressProvider =
    NotifierProvider<TutorialProgress, TutorialStep>(TutorialProgress.new);

class TutorialHint extends ConsumerStatefulWidget {
  final HeatController heat;

  const TutorialHint({super.key, required this.heat});

  @override
  ConsumerState<TutorialHint> createState() => _TutorialHintState();
}

class _TutorialHintState extends ConsumerState<TutorialHint> {
  /// Побывал ли жар в окне хоть раз. Это факт из интерфейса — в состоянии
  /// игры его нет и быть не должно.
  bool _wasInWindow = false;

  @override
  void initState() {
    super.initState();
    widget.heat.addListener(_watch);
  }

  void _watch() {
    if (_wasInWindow || widget.heat.status != HeatStatus.inWindow) return;
    setState(() => _wasInWindow = true);
  }

  @override
  void dispose() {
    widget.heat.removeListener(_watch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final furthest = ref.watch(tutorialProgressProvider);
    if (furthest.isDone) return const SizedBox.shrink();

    final state = ref.watch(gameProvider);
    final engine = ref.read(gameEngineProvider);
    final first = state.generators.items.first;

    final step = tutorialStepFor(
      TutorialFacts(
        hasTouched: state.clicker.totalTaps > 0,
        wasInWindow: _wasInWindow,
        series: widget.heat.series,
        tankFraction: state.tankFraction,
        canAffordStill: state.resources.money >= engine.generatorCost(first),
        stillsOwned: state.generators.items
            .fold(0, (sum, g) => sum + g.ownedCount),
      ),
      furthest,
    );

    // Запись о продвижении — после кадра: менять состояние провайдера прямо
    // во время сборки нельзя.
    if (step != furthest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(tutorialProgressProvider.notifier).reach(step);
      });
    }

    if (step.isDone) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Container(
          key: ValueKey(step),
          margin: const EdgeInsets.symmetric(horizontal: GS.s3),
          padding: const EdgeInsets.symmetric(
            horizontal: GS.s3,
            vertical: GS.s2,
          ),
          decoration: BoxDecoration(
            color: GColors.amber,
            borderRadius: BorderRadius.circular(GR.pill),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            step.text,
            textAlign: TextAlign.center,
            style: GType.ui(
              size: 11,
              weight: FontWeight.w700,
              color: GColors.onAmber,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
