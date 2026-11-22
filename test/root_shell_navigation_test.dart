import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/pages/root_shell.dart';
import 'package:guomu/hg/theme/hg_theme.dart';

const _items = [
  (Icons.home_outlined, Icons.home_rounded, '首页'),
  (Icons.grid_view_outlined, Icons.grid_view_rounded, '剧场'),
  (Icons.forum_outlined, Icons.forum_rounded, '吃瓜'),
  (Icons.emoji_events_outlined, Icons.emoji_events_rounded, '榜单'),
  (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
];

Widget _host({required int index, required ValueChanged<int> onSelected}) {
  return MaterialApp(
    theme: buildHgTheme(Brightness.light),
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: HgAppBottomBar(
        index: index,
        items: _items,
        onSelected: onSelected,
      ),
    ),
  );
}

void main() {
  testWidgets('bottom navigation moves its brand indicator with selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selected = 0;
    await tester.pumpWidget(
      _host(index: 0, onSelected: (value) => selected = value),
    );
    final first = tester.widget<AnimatedPositioned>(
      find.byKey(const ValueKey('hg-nav-active-indicator')),
    );
    expect(first.left, isNotNull);

    await tester.tap(find.byKey(const ValueKey('hg-nav-item-1')));
    expect(selected, 1);

    await tester.pumpWidget(_host(index: 1, onSelected: (_) {}));
    await tester.pump(const Duration(milliseconds: 250));
    final second = tester.widget<AnimatedPositioned>(
      find.byKey(const ValueKey('hg-nav-active-indicator')),
    );
    expect(second.left!, greaterThan(first.left!));
    expect(tester.takeException(), isNull);
  });
}
