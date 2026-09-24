/// Подсказка обучения — одна строка в заголовке пульта жара.
///
/// Живёт на месте подписи жара, а не отдельной плашкой: первые шаги обучения
/// именно про жар, и смотрят в этот момент именно туда. Своей высоты у неё
/// нет — закончилась, и на её месте просто появилась обычная подпись.
///
/// Прошлая версия лежала янтарной таблеткой поверх низа сцены и закрывала
/// ровно то, чему учила: аппарат и огонь под ним.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/tutorial.dart';
import '../../core/settings.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../../providers/settings_provider.dart';
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

  /// Что показывать, когда учить уже нечему.
  final Widget fallback;

  const TutorialHint({super.key, required this.heat, required this.fallback});

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
    if (furthest.isDone) return widget.fallback;

    final state = ref.watch(gameProvider);
    final engine = ref.read(gameEngineProvider);
    final first = state.generators.items.first;

    final step = tutorialStepFor(
      TutorialFacts(
        hasTouched: state.clicker.totalTaps > 0,
        wasInWindow: _wasInWindow,
        series: widget.heat.series,
        tankFraction: state.tankFraction,
        canAffordStill: state.resources.money >=
            engine.generatorCost(first, ref.read(timeProvider)()),
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

    if (step.isDone) return widget.fallback;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Row(
        key: ValueKey(step),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: GColors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${step.index + 1}/${TutorialStep.values.length - 1}',
              style: GType.num(size: 9, weight: FontWeight.w700, color: GColors.onAmber),
            ),
          ),
          const SizedBox(width: GS.s2),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                step.text,
                maxLines: 1,
                style: GType.ui(size: 12, weight: FontWeight.w700, color: GColors.amber),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
