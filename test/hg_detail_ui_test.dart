import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/auth/app_controllers.dart';
import 'package:guomu/hg/models/hg_models.dart';
import 'package:guomu/hg/pages/detail_page.dart';
import 'package:guomu/hg/theme/hg_theme.dart';
import 'package:guomu/hg/utils/hg_download_manager.dart';
import 'package:guomu/hg/utils/hg_local_history.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DetailApi extends HgApi {
  _DetailApi() : super(baseUrl: 'https://example.test');

  @override
  Future<HgVideoDetail> video(int id) async => HgVideoDetail.fromJson({
    'id': id,
    'title': '界面回归短剧',
    'cover': '',
    'total_episodes': 1,
    'episodes': [
      {'ep_num': 1},
    ],
  });
}

void main() {
  testWidgets('detail action dock fits a narrow phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _DetailApi();
    final auth = AuthController(api, prefs);
    final downloads = HgDownloadManager(api, prefs);
    HgLocalHistory.resetQueueForTesting();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HgApi>.value(value: api),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider<HgDownloadManager>.value(value: downloads),
        ],
        child: MaterialApp(
          theme: buildHgTheme(Brightness.light),
          home: const DramaDetailPage(videoId: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const ValueKey('hg-detail-action-dock')), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-detail-follow')), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-detail-play')), findsOneWidget);
    expect(find.text('立即播放 · 第 1 集'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
