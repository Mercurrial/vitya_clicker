import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/providers/settings_provider.dart';
import 'package:idle_game/ui/widgets/vitya_toast.dart';

/// Взятая цель объявляется плашкой.
///
/// Раньше открытые цели складывались в список, который никто не читал:
/// множитель рос молча, автопродажа включалась без единого слова, и игрок
/// узнавал о ней, когда бак вдруг продавался сам.
void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  ProviderContainer open({required double money}) {
    var state = newGame(content: kGenerators, upgrades: kUpgrades, now: t0);
    state = state.copyWith(resources: state.resources.copyWith(money: money));
    final container = ProviderContainer(
      overrides: [
        initialStateProvider.overrideWithValue(state),
        timeProvider.overrideWithValue(() => t0),
        settingsStoreProvider.overrideWithValue(MemorySettingsStore({})),
      ],
    );
    return container;
  }

  testWidgets('первая тысяча — плашка со значком и объяснением автопродажи',
      (tester) async {
    final c = open(money: 1500);
    c.read(gameProvider);
    await tester.pump(const Duration(milliseconds: 400));

    final toast = c.read(toastProvider);
    expect(toast, isNotNull, reason: 'цель взята, а плашки нет');
    expect(toast!.kind, 'ЦЕЛЬ ВЗЯТА');
    expect(toast.goalId, isNotNull, reason: 'у плашки цели должен быть её значок');
    expect(toast.note, contains('автопродажа'),
        reason: 'перк включился — игрок должен узнать об этом сразу');

    // Плашка уходит сама; таймер игры закрываем в самом тесте — проверка
    // висящих таймеров идёт раньше teardown.
    await tester.pump(const Duration(seconds: 3));
    c.dispose();
  });
}
