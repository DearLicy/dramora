import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/auth/app_controllers.dart';
import 'package:guomu/hg/models/hg_models.dart';
import 'package:guomu/hg/pages/profile_page.dart';
import 'package:guomu/hg/theme/hg_theme.dart';
import 'package:guomu/hg/utils/hg_local_history.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProfileApi extends HgApi {
  _ProfileApi({this.items = const []}) : super(baseUrl: 'https://example.test');

  final List<HgPlaylistItem> items;

  @override
  Future<HgPage<HgPlaylistItem>> myCollects({
    int page = 1,
    int size = 20,
  }) async {
    return HgPage<HgPlaylistItem>(
      items: items,
      pagination: HgPagination(
        page: 1,
        pages: 1,
        size: size,
        total: items.length,
      ),
    );
  }

  @override
  Future<int> unreadMessageCount() async => 0;
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required _ProfileApi api,
  required SharedPreferences prefs,
  Brightness brightness = Brightness.light,
}) async {
  HgLocalHistory.resetQueueForTesting();
  final auth = AuthController(api, prefs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<HgApi>.value(value: api),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        theme: buildHgTheme(brightness),
        home: const ProfilePage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('guest profile keeps one login entry and shows sync benefits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pumpProfile(tester, api: _ProfileApi(), prefs: prefs);

    expect(find.byKey(const ValueKey('hg-profile-login')), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('登录后可用'), findsOneWidget);
    expect(find.text('多设备续播'), findsOneWidget);
    expect(find.text('追剧与收藏同步'), findsOneWidget);
    expect(find.text('点赞与消息同步'), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-profile-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-profile-messages')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library grid adapts to two columns on a narrow dark screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final user = HgUser(
      id: 338861,
      username: 'DearLicy',
      nickname: 'DearLicy',
      counts: const {'following': 2, 'follower': 3, 'like': 4},
    );
    SharedPreferences.setMockInitialValues({
      'guomu.hg.token': 'test-token',
      'guomu.hg.user': jsonEncode(user.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final api = _ProfileApi(
      items: const [
        HgPlaylistItem(
          id: 1,
          videoId: 1,
          title: '回归短剧一',
          cover: '',
          lastEpisode: 2,
          totalEpisodes: 6,
          positionMs: 30000,
          durationMs: 100000,
        ),
        HgPlaylistItem(
          id: 2,
          videoId: 2,
          title: '回归短剧二',
          cover: '',
          lastEpisode: 1,
          totalEpisodes: 4,
        ),
        HgPlaylistItem(
          id: 3,
          videoId: 3,
          title: '回归短剧三',
          cover: '',
          lastEpisode: 3,
          totalEpisodes: 8,
        ),
      ],
    );

    await _pumpProfile(
      tester,
      api: api,
      prefs: prefs,
      brightness: Brightness.dark,
    );

    expect(find.byKey(const ValueKey('hg-profile-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-profile-messages')), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-profile-settings')), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

    final gridFinder = find.byKey(const ValueKey('hg-profile-library-grid'));
    expect(gridFinder, findsOneWidget);
    final grid = tester.widget<SliverGrid>(gridFinder);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(delegate.maxCrossAxisExtent, 140);

    final first = tester.getTopLeft(
      find.byKey(const ValueKey('hg-profile-library-card-1')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('hg-profile-library-card-2')),
    );
    final third = tester.getTopLeft(
      find.byKey(const ValueKey('hg-profile-library-card-3')),
    );
    expect(second.dy, closeTo(first.dy, 0.5));
    expect(third.dy, greaterThan(first.dy));
    expect(third.dx, closeTo(first.dx, 0.5));

    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    final expectedTrack = buildHgTheme(
      Brightness.dark,
    ).colorScheme.outlineVariant.withValues(alpha: 0.72);
    expect(progress.backgroundColor, expectedTrack);
    expect(tester.takeException(), isNull);
  });
}
