import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/widgets/hg_adaptive_sheet.dart';

void main() {
  testWidgets('adaptive sheet expands and dismisses with drag gestures', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showHgAdaptiveSheet<void>(
                  context,
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('sheet content'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet content'), findsOneWidget);

    final before = tester.getTopLeft(find.text('sheet content')).dy;
    await tester.drag(find.text('sheet content'), const Offset(0, -180));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.text('sheet content')).dy;
    expect(after, lessThan(before));

    await tester.drag(find.text('sheet content'), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('sheet content'), findsNothing);
  });

  testWidgets(
    'adaptive sheet keeps scrollable content on the sheet controller',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showHgAdaptiveSheetBuilder<void>(
                    context,
                    childScrollable: true,
                    builder: (_) => ListView.builder(
                      itemCount: 30,
                      itemBuilder: (_, index) =>
                          ListTile(title: Text('row $index')),
                    ),
                  ),
                  child: const Text('open list'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open list'));
      await tester.pumpAndSettle();
      expect(find.text('row 0'), findsOneWidget);

      final before = tester.getTopLeft(find.text('row 0')).dy;
      await tester.drag(find.text('row 0'), const Offset(0, -300));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.text('row 0')).dy;
      expect(after, lessThan(before));
    },
  );

  testWidgets('confirmation sheet returns explicit yes or no', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showHgConfirmSheet(
                    context,
                    title: '清除全部缓存？',
                    message: '会删除已下载的所有短剧文件。',
                    confirmLabel: '清除全部',
                    destructive: true,
                  );
                },
                child: const Text('confirm'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('confirm'));
    await tester.pumpAndSettle();
    expect(find.text('清除全部缓存？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hg-confirm-sheet-action')));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hg-confirm-sheet-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
