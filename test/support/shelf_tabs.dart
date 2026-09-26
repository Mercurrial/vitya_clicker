import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Строка вкладок шторки.
final shelfTabs = find.byKey(const Key('shelf-tabs'));

/// Вкладка шторки по подписи — долистанная до экрана, если строка листается.
///
/// На узком экране вкладок больше, чем влезает, и строка листается вбок
/// (см. shelf.dart). Дальние вкладки при этом не построены вовсе, пока до
/// них не долистали, — как и палец игрока, тест до них сначала листает.
Future<Finder> shelfTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: shelfTabs, matching: find.text(label));
  final scroll = find.descendant(of: shelfTabs, matching: find.byType(Scrollable));
  if (scroll.evaluate().isNotEmpty) {
    // Строку могли уже пролистать дальше этой вкладки — листаем от начала.
    if (tab.evaluate().isEmpty) {
      tester.state<ScrollableState>(scroll.first).position.jumpTo(0);
      await tester.pump();
    }
    await tester.scrollUntilVisible(tab, 40, scrollable: scroll.first);
  }
  return tab;
}
