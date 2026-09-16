@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/ui/pixel/garage_room.dart';

/// Снимки комнаты на каждой стадии.
///
/// Нужны не для сравнения байтов, а чтобы глазами проверить, что сцена
/// выглядит так, как задумано: раньше «портрет не работает» вскрылось только
/// после того, как человек посмотрел на экран, а не на код.
///
/// Обновить снимки:
///   flutter test --update-goldens test/garage_room_golden_test.dart
///
/// Тег `golden` стоит намеренно: рендер зависит от версии движка, поэтому в
/// общем прогоне эти тесты не участвуют (см. dart_test.yaml).
void main() {
  for (final stage in GarageStage.values) {
    testWidgets('комната: ${stage.name}', (tester) async {
      tester.view
        ..physicalSize = const Size(342, 300)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 342,
            height: 300,
            child: Stack(
              children: [
                Positioned.fill(child: RoomBackground(stage: stage)),
                // Момент выбран так, чтобы лампу было видно отклонённой.
                const Positioned.fill(child: SwingingLamp(time: 2.1, heat: 0.7)),
              ],
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Stack),
        matchesGoldenFile('goldens/room_${stage.name}.png'),
      );
    });
  }
}
