import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/models/hg_download_models.dart';
import 'package:guomu/hg/pages/downloads_page.dart';
import 'package:guomu/hg/theme/hg_theme.dart';
import 'package:guomu/hg/utils/hg_download_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApi extends HgApi {
  _FakeApi() : super(baseUrl: 'https://example.test');
}

class _PreviewDownloads extends HgDownloadManager {
  _PreviewDownloads(this.api, SharedPreferences prefs, this.task)
    : super(api, prefs);

  final _FakeApi api;
  final HgDownloadTask task;
  int resumeCalls = 0;

  @override
  List<HgDownloadTask> get tasks => [task];

  @override
  HgDownloadTask? taskFor(int videoId) => task.videoId == videoId ? task : null;

  @override
  Future<void> restore() async {}

  @override
  Future<void> resumeDownload(int videoId) async {
    resumeCalls++;
  }
}

Future<_PreviewDownloads> _managerFor(HgDownloadTask task) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return _PreviewDownloads(_FakeApi(), prefs, task);
}

Widget _host(HgDownloadManager manager, HgApi api) {
  return MultiProvider(
    providers: [
      Provider<HgApi>.value(value: api),
      ChangeNotifierProvider<HgDownloadManager>.value(value: manager),
    ],
    child: MaterialApp(
      theme: buildHgTheme(Brightness.light),
      home: const DownloadsPage(),
    ),
  );
}

void main() {
  testWidgets(
    'active download shows current bytes, speed and smooth progress',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mib = 1024 * 1024;
      final manager = await _managerFor(
        const HgDownloadTask(
          videoId: 10586,
          title: '蜜桃臀',
          cover: '',
          state: '下载中 · 第 1/6 集',
          totalEpisodes: 6,
          progress: 0.1,
          receivedBytes: 20 * mib,
          totalBytes: 500 * mib,
          speedBytesPerSecond: 100 * 1024,
        ),
      );
      addTearDown(manager.dispose);
      await tester.pumpWidget(_host(manager, manager.api));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('100.0 KB/s'), findsOneWidget);
      expect(find.text('本集 20.0 MB / 500.0 MB'), findsOneWidget);
      expect(find.textContaining('剩余 1 小时'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(0.1, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('paused download exposes an explicit resume action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final manager = await _managerFor(
      const HgDownloadTask(
        videoId: 11734,
        title: '寄生帚',
        cover: '',
        state: '已暂停',
        totalEpisodes: 6,
        lastError: 'network',
      ),
    );
    addTearDown(manager.dispose);

    await tester.pumpWidget(_host(manager, manager.api));
    await tester.pump();

    expect(find.text('已暂停 · 可继续下载'), findsOneWidget);
    final resume = find.byKey(const ValueKey('hg-download-resume-11734'));
    expect(resume, findsOneWidget);
    await tester.tap(resume);
    await tester.pump();
    expect(manager.resumeCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
