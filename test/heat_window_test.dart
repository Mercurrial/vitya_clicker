import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/models/upgrade.dart';
import 'package:idle_game/models/upgrades_state.dart';
import 'package:idle_game/ui/game/heat_controller.dart';

/// Окно жара и улучшения руки.
///
/// «Крепкая рука», «Трудовая мозоль» и «Дедовская хватка» продавались с
/// первой версии и не делали ничего: множитель считался в состоянии игры, а
/// контроллер жара о нём не знал. Эти тесты — о том, чтобы купленное
/// работало, и о том, чтобы оно не сломало саму механику.
void main() {
  UpgradesState withHands(int count) {
    final hands = kUpgrades.where((u) => u.target == UpgradeTarget.heatControl).toList();
    return UpgradesState(items: [
      for (final u in kUpgrades)
        hands.take(count).contains(u) ? u.copyWith(purchased: true) : u,
    ]);
  }

  test('каждое улучшение руки расширяет окно', () {
    var prev = 0.0;
    for (var n = 0; n <= 3; n++) {
      final scale = withHands(n).heatControlMultiplier;
      final size = (HeatController.baseWindowSize * scale)
          .clamp(0.0, HeatController.maxWindowSize);
      expect(size, greaterThan(prev), reason: 'после $n покупок окно не шире');
      prev = size;
    }
  });

  test('даже со всеми улучшениями окно не на всю шкалу', () {
    // Окно на всю шкалу — это «зажал и забыл», а ради этого механику не делали.
    final scale = withHands(3).heatControlMultiplier;
    expect(HeatController.baseWindowSize * scale,
        lessThanOrEqualTo(HeatController.maxWindowSize + 1e-9));
  });

  testWidgets('контроллер берёт ширину из улучшений и не заезжает в перегрев',
      (tester) async {
    final c = HeatController(vsync: tester);

    expect(c.windowEnd - c.windowStart,
        closeTo(HeatController.baseWindowSize, 1e-9));

    c.windowScale = withHands(3).heatControlMultiplier;
    expect(c.windowEnd - c.windowStart, greaterThan(HeatController.baseWindowSize * 1.9));

    // Две минуты хода окна: правый край не должен касаться зоны перегрева,
    // иначе «в окне» и «перегрел» наступали бы одновременно.
    for (var i = 0; i < 1200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.windowEnd, lessThan(HeatController.overheatAt));
    }
    // Тикер проверяется до teardown — освобождаем в самом тесте.
    c.dispose();
  });

  testWidgets('после паузы кадров жар не прыгает в перегрев', (tester) async {
    // Браузер в фоне и телефон на фризе присылают один кадр длиной в
    // секунды. Раньше жар на таком кадре улетал из холодного в перегрев.
    final c = HeatController(vsync: tester);
    c.startStoking();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 5));
    expect(c.heat, lessThan(0.1));
    c.dispose();
  });
}
