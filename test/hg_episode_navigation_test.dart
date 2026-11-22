import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/auth/app_controllers.dart';
import 'package:guomu/hg/models/hg_models.dart';
import 'package:guomu/hg/models/hg_download_models.dart';
import 'package:guomu/hg/pages/detail_page.dart';
import 'package:guomu/hg/pages/downloads_page.dart';
import 'package:guomu/hg/pages/episodes_sheet.dart';
import 'package:guomu/hg/pages/short_video_page.dart';
import 'package:guomu/hg/theme/hg_theme.dart';
import 'package:guomu/hg/utils/hg_download_manager.dart';
import 'package:guomu/hg/utils/hg_local_history.dart';
import 'package:guomu/hg/widgets/hg_pressable.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

HgVideoDetail _detail({List<int>? numbers}) => HgVideoDetail.fromJson({
  'id': 1,
  'title': '仅供回归测试的短剧',
  'cover': '',
  'episode_count': 90,
  'total_episodes': 90,
  'is_finished': true,
  'episodes': [
    for (final n in numbers ?? List.generate(90, (i) => i + 1)) {'ep_num': n},
  ],
});

class _EpisodeApi extends HgApi {
  _EpisodeApi() : super(baseUrl: 'https://example.test');
  final requests = <int>[];
  @override
  Future<HgVideoDetail> video(int id) async => _detail();
  @override
  Future<HgPlayInfo> playback(int videoId, int episode) async {
    requests.add(episode);
    return HgPlayInfo(
      videoId: videoId,
      episode: episode,
      videoUrl: 'https://example.test/$episode.mp4',
    );
  }

  @override
  Future<void> prefetchPlaybackAround(
    HgVideoDetail detail,
    int currentEpisode,
  ) async {}
}

class _Players extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final episodes = <int, int>{};
  final playing = <int, bool>{};
  final positions = <int, Duration>{};
  Completer<void>? pendingSeek;
  int get active => playing.entries.singleWhere((e) => e.value).key;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = events.length + 1;
    final stream = events[id] = StreamController<VideoEvent>();
    episodes[id] = int.parse(
      Uri.parse(options.dataSource.uri!).pathSegments.first.split('.').first,
    );
    positions[id] = Duration.zero;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 100),
        size: const Size(1080, 1920),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    playing[playerId] = false;
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> pause(int playerId) async {
    playing[playerId] = false;
  }

  @override
  Future<void> play(int playerId) async {
    playing[playerId] = true;
  }

  @override
  Future<Duration> getPosition(int playerId) async => positions[playerId]!;
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    await pendingSeek?.future;
    positions[playerId] = position;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

class _CachedDownloads extends HgDownloadManager {
  _CachedDownloads(super.api, super.prefs, this.task);
  final HgDownloadTask task;
  @override
  List<HgDownloadTask> get tasks => [task];
  @override
  HgDownloadTask? taskFor(int videoId) => videoId == task.videoId ? task : null;
  @override
  Future<void> restore() async {}
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _EpisodeApi api;
  late _Players platform;
  late VideoPlayerPlatform previous;
  late SharedPreferences prefs;
  late AuthController auth;
  late HgDownloadManager downloads;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = _EpisodeApi();
    auth = AuthController(api, prefs);
    downloads = HgDownloadManager(api, prefs);
    previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform = _Players();
  });
  tearDown(() async {
    if (platform.pendingSeek?.isCompleted == false) {
      platform.pendingSeek!.complete();
    }
    for (final stream in platform.events.values) {
      await stream.close();
    }
    VideoPlayerPlatform.instance = previous;
    auth.dispose();
    downloads.dispose();
  });
  Widget host(Widget child, {HgDownloadManager? manager}) => MultiProvider(
    providers: [
      Provider<HgApi>.value(value: api),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider<HgDownloadManager>.value(
        value: manager ?? downloads,
      ),
    ],
    child: MaterialApp(theme: buildHgTheme(Brightness.light), home: child),
  );

  for (final size in [const Size(320, 700), const Size(844, 390)]) {
    testWidgets(
      'episode sheet keeps selection reachable and cells tappable at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? selected;
        await tester.pumpWidget(
          host(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selected = await showEpisodesSheet(
                      context,
                      detail: _detail(
                        numbers: List.generate(45, (i) => 101 + i),
                      ),
                      currentEpisode: 135,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('131-145'), findsOneWidget);
        expect(find.text('135').hitTestable(), findsOneWidget);
        final cell = find
            .ancestor(of: find.text('135'), matching: find.byType(HgInkWell))
            .first;
        final bounds = tester.getSize(cell);
        expect(bounds.width, greaterThanOrEqualTo(44));
        expect(bounds.height, greaterThanOrEqualTo(44));
        await tester.tap(find.text('135'));
        await tester.pumpAndSettle();
        expect(selected, 135);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selecting a distant episode skips intermediate playback and then auto plays next',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      HgLocalHistory.resetQueueForTesting();
      await tester.pumpWidget(host(const ShortVideoPage(videoIds: [1])));
      await _frames(tester);
      expect(platform.episodes[platform.active], 1);
      await tester.tap(find.textContaining('当前第 1 集').first);
      await _frames(tester);
      await tester.tap(find.text('31-60'));
      await _frames(tester, 3);
      await tester.ensureVisible(find.text('31'));
      await tester.tap(find.text('31'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await _frames(tester);
      expect(platform.episodes[platform.active], 31);
      expect(api.requests.where((e) => e > 2 && e < 30), isEmpty);
      expect((await HgLocalHistory.find(1))!.lastEpisode, 31);
      platform.events[platform.active]!.add(
        VideoEvent(eventType: VideoEventType.completed),
      );
      await _frames(tester);
      expect(platform.episodes[platform.active], 32);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _frames(tester, 2);
    },
  );

  testWidgets(
    'a pending horizontal seek never resumes an episode after it has been swiped away',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      HgLocalHistory.resetQueueForTesting();
      await tester.pumpWidget(host(const ShortVideoPage(videoIds: [1])));
      await _frames(tester);
      final first = platform.active;
      platform.pendingSeek = Completer<void>();
      await tester.dragFrom(const Offset(100, 330), const Offset(140, 0));
      await _frames(tester, 2);
      await tester.dragFrom(const Offset(170, 420), const Offset(0, -650));
      await _frames(tester);
      expect(platform.episodes[platform.active], 2);
      platform.pendingSeek!.complete();
      await _frames(tester, 2);
      expect(platform.playing[first], isFalse);
      expect(platform.episodes[platform.active], 2);
      expect((await HgLocalHistory.find(1))!.lastEpisode, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _frames(tester, 2);
    },
  );

  testWidgets(
    'late progress from a departed episode cannot overwrite the new episode history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      HgLocalHistory.resetQueueForTesting();
      await tester.pumpWidget(host(const ShortVideoPage(videoIds: [1])));
      await _frames(tester);
      platform.positions[platform.active] = const Duration(seconds: 42);
      await _frames(tester, 8);
      await tester.dragFrom(const Offset(170, 420), const Offset(0, -650));
      await _frames(tester);
      final history = (await HgLocalHistory.find(1))!;
      expect(history.lastEpisode, 2);
      expect(history.positionMs, 0);
      await tester.dragFrom(const Offset(170, 230), const Offset(0, 650));
      await _frames(tester);
      expect(platform.episodes[platform.active], 1);
      expect(platform.positions[platform.active], const Duration(seconds: 42));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _frames(tester, 2);
    },
  );

  for (final state in ['下载中', '已缓存']) {
    testWidgets('detail exposes $state and opens the existing download task', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      HgLocalHistory.resetQueueForTesting();
      final manager = _CachedDownloads(
        api,
        prefs,
        HgDownloadTask(
          videoId: 1,
          title: '缓存回归测试',
          cover: '',
          state: state,
          totalEpisodes: 1,
          episodes: state == '已缓存'
              ? const {
                  1: HgDownloadedEpisode(
                    number: 1,
                    directory: '',
                    manifestPath: '',
                    bytes: 100,
                    updatedAt: '',
                  ),
                }
              : const {},
        ),
      );
      await tester.pumpWidget(
        host(const DramaDetailPage(videoId: 1), manager: manager),
      );
      await _frames(tester);
      final action = find.text(state == '下载中' ? '正在缓存' : '已缓存');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await _frames(tester);
      expect(find.byType(DownloadsPage), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _frames(tester, 2);
      manager.dispose();
    });
  }

  testWidgets(
    'download page continues the locally recorded episode and position',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      HgLocalHistory.resetQueueForTesting();
      await HgLocalHistory.save(
        videoId: 1,
        title: '缓存回归测试',
        cover: '',
        episode: 5,
        totalEpisodes: 90,
        positionMs: 42000,
        durationMs: 100000,
      );
      final manager = _CachedDownloads(
        api,
        prefs,
        const HgDownloadTask(
          videoId: 1,
          title: '缓存回归测试',
          cover: '',
          totalEpisodes: 90,
          episodes: {
            8: HgDownloadedEpisode(
              number: 8,
              directory: '',
              manifestPath: '',
              bytes: 100,
              updatedAt: '',
            ),
          },
        ),
      );
      await tester.pumpWidget(host(const DownloadsPage(), manager: manager));
      await tester.tap(find.text('缓存回归测试'));
      await _frames(tester);
      final page = tester.widget<ShortVideoPage>(find.byType(ShortVideoPage));
      expect(page.initialEpisode, isNull);
      expect(platform.episodes[platform.active], 5);
      expect(platform.positions[platform.active], const Duration(seconds: 42));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _frames(tester, 2);
      manager.dispose();
    },
  );
}
