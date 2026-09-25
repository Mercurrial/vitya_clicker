import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/transfer_progress.dart';

/// Перенос прогресса, когда браузер не даёт буфер обмена.
///
/// Так бывает во встроенных браузерах мессенджеров, во вкладке без фокуса,
/// при запрете в настройках. Раньше отказ улетал необработанным исключением,
/// и игрок не видел ничего: ни кода, ни объяснения. Проверяется, что код всё
/// равно можно унести и принести — руками.
void main() {
  late ProviderContainer game;

  // Контейнером владеет дерево виджетов, а не тест: у игры тикает таймер, и
  // закрыться он обязан вместе с экраном, а не после проверки таймеров.
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveServiceProvider
              .overrideWithValue(SaveService(storage: MemorySaveStorage())),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily),
          home: const Scaffold(
            body: SingleChildScrollView(child: TransferProgress()),
          ),
        ),
      ),
    );
    game = ProviderScope.containerOf(tester.element(find.byType(TransferProgress)));
  }

  /// Браузер отказывает и в записи в буфер, и в чтении из него.
  void denyClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.setData' ||
        'Clipboard.getData' =>
          throw PlatformException(code: 'NotAllowedError'),
        // Поля ввода сами спрашивают, есть ли что вставить, — это не отказ.
        'Clipboard.hasStrings' => <String, Object>{'value': false},
        _ => null,
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
  }

  testWidgets('не дали скопировать — код показан целиком', (tester) async {
    await open(tester);
    denyClipboard(tester);

    await tester.tap(find.text('СКОПИРОВАТЬ'));
    await tester.pumpAndSettle();

    final shown = find.byType(SelectableText);
    expect(shown, findsOneWidget, reason: 'отказ буфера снова прошёл молча');
    final code = tester.widget<SelectableText>(shown).data;
    expect(decodeSaveCode(code).isOk, isTrue,
        reason: 'показанный код не принимается обратно');
  });

  testWidgets('не дали вставить — код принимается из поля', (tester) async {
    // Код «с другого устройства»: там в кассе 777.
    final other = ProviderContainer(
      overrides: [
        saveServiceProvider
            .overrideWithValue(SaveService(storage: MemorySaveStorage())),
      ],
    );
    final notifier = other.read(gameProvider.notifier);
    notifier.state = notifier.state.copyWith(
      resources: notifier.state.resources.copyWith(money: 777),
    );
    final code = notifier.exportCode();
    other.dispose();

    await open(tester);
    denyClipboard(tester);

    await tester.tap(find.text('ВСТАВИТЬ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Заменить'));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    expect(field, findsOneWidget, reason: 'некуда вставить код руками');
    await tester.enterText(field, code);
    await tester.tap(find.text('Принять'));
    await tester.pumpAndSettle();

    expect(game.read(gameProvider).resources.money, closeTo(777, 1e-6));
  });

  testWidgets('передумал вставлять — гараж не тронут', (tester) async {
    await open(tester);
    denyClipboard(tester);
    final notifier = game.read(gameProvider.notifier);
    notifier.state = notifier.state.copyWith(
      resources: notifier.state.resources.copyWith(money: 555),
    );

    await tester.tap(find.text('ВСТАВИТЬ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Заменить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(game.read(gameProvider).resources.money, 555);
  });
}
