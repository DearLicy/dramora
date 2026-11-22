import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/auth/app_controllers.dart';
import 'package:guomu/hg/models/hg_models.dart';
import 'package:guomu/hg/pages/short_video_page.dart';
import 'package:guomu/hg/services/hg_wake_lock_service.dart';
import 'package:guomu/hg/theme/hg_theme.dart';
import 'package:guomu/hg/utils/hg_download_manager.dart';
import 'package:guomu/hg/utils/hg_local_history.dart';
import 'package:guomu/hg/utils/hg_player_display_native.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final playing = <int, bool>{};
  final positions = <int, Duration>{};
  final seeks = <Duration>[];
  final speeds = <double>[];
  bool failSeek = false;
  Completer<void>? seekPending;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = events.length + 1;
    events[id] = StreamController<VideoEvent>()
      ..add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 120),
          size: const Size(1920, 1080),
        ),
      );
    playing[id] = false;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async => playing[playerId] = false;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    speeds.add(speed);
  }

  @override
  Future<void> play(int playerId) async => playing[playerId] = true;
  @override
  Future<void> pause(int playerId) async => playing[playerId] = false;
  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add(position);
    await seekPending?.future;
    if (failSeek) throw PlatformException(code: 'seek_failed');
    positions[playerId] = position;
  }

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Color(0xff252525));
}

class _PlayerApi extends HgApi {
  _PlayerApi() : super(baseUrl: 'https://example.test');
  @override
  Future<HgVideoDetail> video(int id) async => HgVideoDetail.fromJson({
    'id': id,
    'title': '播放器交互测试',
    'cover': '',
    'total_episodes': 3,
    'episodes': [
      for (var i = 1; i <= 3; i++) {'ep_num': i},
    ],
  });
  @override
  Future<HgPlayInfo> playback(int videoId, int episode) async => HgPlayInfo(
    videoId: videoId,
    episode: episode,
    videoUrl: 'https://example.test/$episode.m3u8',
  );
  @override
  Future<void> prefetchPlaybackAround(
    HgVideoDetail detail,
    int currentEpisode,
  ) async {}
  @override
  Future<HgCommentPage> comments(
    int videoId,
    int episode, {
    int page = 1,
    int size = 20,
  }) async => const HgCommentPage(items: [], pagination: HgPagination());
}

class _Downloads extends HgDownloadManager {
  _Downloads(super.api, super.prefs);
  @override
  Future<String?> localPlaylist(int videoId, int episode) async => null;
}

void main() {
  late _VideoPlatform platform;
  late VideoPlayerPlatform previous;
  final systemCalls = <MethodCall>[];
  final wakeLockCalls = <bool>[];

  setUp(() async {
    previous = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    systemCalls.clear();
    wakeLockCalls.clear();
    await HgWakeLockService.resetForTesting();
    HgWakeLockService.toggleForTesting = ({required bool enable}) async {
      wakeLockCalls.add(enable);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          systemCalls.add(call);
          return null;
        });
  });
  tearDown(() async {
    for (final stream in platform.events.values) {
      await stream.close();
    }
    VideoPlayerPlatform.instance = previous;
    await HgWakeLockService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> mount(
    WidgetTester tester, {
    bool landscape = false,
    bool accessible = false,
  }) async {
    tester.view.physicalSize = landscape
        ? const Size(844, 390)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _PlayerApi();
    HgLocalHistory.resetQueueForTesting();
    HgPlayerDisplay.resetQueueForTesting();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HgApi>.value(value: api),
          ChangeNotifierProvider(create: (_) => AuthController(api, prefs)),
          ChangeNotifierProvider<HgDownloadManager>(
            create: (_) => _Downloads(api, prefs),
          ),
        ],
        child: MaterialApp(
          theme: buildHgTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(accessibleNavigation: accessible),
            child: child!,
          ),
          home: const ShortVideoPage(videoIds: [1]),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(platform.playing[1], isTrue);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> tapSurface(WidgetTester tester) =>
      tester.tapAt(const Offset(290, 150));
  Finder getSurface() => find.byKey(const ValueKey('hg-player-surface')).first;

  testWidgets('clear screen tap restores controls without pausing', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.bySemanticsLabel('清屏观看'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(platform.playing[1], isTrue);
    await tapSurface(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.bySemanticsLabel('清屏观看'), findsOneWidget);
    expect(platform.playing[1], isTrue);
    await tapSurface(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(platform.playing[1], isFalse);
    await tester.tap(find.byKey(const ValueKey('hg-playback-play-button')));
    await tester.pump();
    expect(platform.playing[1], isTrue);
  });

  testWidgets('double tap right seeks forward ten seconds', (tester) async {
    await mount(tester);
    final right = Offset(320, 300);
    await tester.tapAt(right);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(right);
    await tester.pump();
    await tester.pump();
    expect(platform.seeks, isNotEmpty);
    expect(platform.seeks.last, const Duration(seconds: 10));
    expect(find.text('+10 秒'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('speed sheet selects a playback speed', (tester) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('hg-speed-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('播放速度'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hg-speed-0.75x')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('0.75x'), findsOneWidget);
    expect(platform.speeds, contains(0.75));
  });

  testWidgets('portrait controls auto-hide while playing and restore on tap', (
    tester,
  ) async {
    await mount(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(find.bySemanticsLabel('清屏观看').hitTestable(), findsNothing);
    expect(find.byKey(const ValueKey('hg-hidden-progress')), findsOneWidget);
    expect(platform.playing[1], isTrue);

    await tapSurface(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('清屏观看').hitTestable(), findsOneWidget);
    expect(platform.playing[1], isTrue);
  });

  testWidgets('landscape taps toggle controls; play button controls playback', (
    tester,
  ) async {
    await mount(tester, landscape: true);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.bySemanticsLabel('选集').hitTestable(), findsNothing);
    expect(platform.playing[1], isTrue);
    await tapSurface(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.bySemanticsLabel('选集'), findsOneWidget);
    expect(platform.playing[1], isTrue);
    await tester.tap(find.byKey(const ValueKey('hg-landscape-play-button')));
    await tester.pump(const Duration(seconds: 4));
    expect(platform.playing[1], isFalse);
    expect(find.bySemanticsLabel('选集'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hg-landscape-play-button')));
    await tester.pump();
    expect(platform.playing[1], isTrue);
  });

  testWidgets(
    'landscape controls stay visible while using accessibility navigation',
    (tester) async {
      await mount(tester, landscape: true, accessible: true);
      await tester.pump(const Duration(seconds: 5));
      expect(find.bySemanticsLabel('选集'), findsOneWidget);
    },
  );

  testWidgets('landscape controls do not disappear under a held finger', (
    tester,
  ) async {
    await mount(tester, landscape: true);
    final gesture = await tester.startGesture(const Offset(290, 150));
    await tester.pump(const Duration(seconds: 4));
    expect(find.bySemanticsLabel('选集').hitTestable(), findsOneWidget);
    await gesture.up();
    await tester.pump();
  });

  testWidgets(
    'comment sheet closes back to available controls before they auto-hide again',
    (tester) async {
      await mount(tester, landscape: true);
      await tester.tap(find.bySemanticsLabel('评论'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('还没有评论'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('选集').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.bySemanticsLabel('选集').hitTestable(), findsNothing);
    },
  );

  testWidgets(
    'back in landscape requests portrait rather than leaving player',
    (tester) async {
      await mount(tester, landscape: true);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(getSurface(), findsOneWidget);
      expect(platform.playing[1], isTrue);
      expect(
        systemCalls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        ['DeviceOrientation.portraitUp'],
      );
    },
  );

  for (final landscape in [false, true]) {
    testWidgets(
      'slider seek pauses and resumes after completion (landscape=$landscape)',
      (tester) async {
        await mount(tester, landscape: landscape);
        platform.seekPending = Completer<void>();
        final slider = tester.widget<Slider>(find.byType(Slider).first);
        slider.onChangeStart!(0.5);
        await tester.pump();
        expect(platform.playing[1], isFalse);
        if (landscape) {
          expect(
            find.byKey(const ValueKey('hg-landscape-play-button')),
            findsNothing,
          );
        }
        slider.onChanged!(0.6);
        slider.onChangeEnd!(0.6);
        await tester.pump();
        expect(platform.playing[1], isFalse);
        expect(platform.seeks.last, const Duration(seconds: 72));
        platform.seekPending!.complete();
        await tester.pump();
        await tester.pump();
        expect(platform.playing[1], isTrue);
        if (landscape) {
          expect(
            find.byKey(const ValueKey('hg-landscape-play-button')),
            findsOneWidget,
          );
        }
        expect(tester.widget<Slider>(find.byType(Slider).first).value, 0.6);
      },
    );
  }

  testWidgets('failed horizontal seek restores prior playing intent', (
    tester,
  ) async {
    await mount(tester);
    platform.failSeek = true;
    await tester.dragFrom(const Offset(120, 250), const Offset(130, 0));
    await tester.pump();
    await tester.pump();
    expect(platform.seeks, isNotEmpty);
    expect(platform.playing[1], isTrue);
    expect(find.text('暂时无法跳转，请重试'), findsOneWidget);
  });

  testWidgets('seeking a paused video keeps it paused', (tester) async {
    await mount(tester);
    await tapSurface(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(platform.playing[1], isFalse);
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    slider.onChangeStart!(0.3);
    await tester.pump();
    slider.onChangeEnd!(0.3);
    await tester.pump();
    await tester.pump();
    expect(platform.playing[1], isFalse);
  });

  testWidgets(
    'finishing a seek after switching episodes never resumes the departed episode',
    (tester) async {
      await mount(tester);
      platform.seekPending = Completer<void>();
      final slider = tester.widget<Slider>(find.byType(Slider).first);
      slider.onChangeStart!(0.4);
      await tester.pump();
      slider.onChangeEnd!(0.4);
      await tester.pump();
      await tester.dragFrom(const Offset(220, 350), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 350));
      expect(platform.playing[1], isFalse);
      platform.seekPending!.complete();
      await tester.pump();
      await tester.pump();
      expect(platform.playing[1], isFalse);
      expect(platform.playing.values.where((value) => value).length, 1);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  test('wake lock applies only the latest requested state', () async {
    await HgWakeLockService.update(playing: false, applicationActive: true);
    await HgWakeLockService.update(playing: true, applicationActive: true);
    await HgWakeLockService.update(playing: true, applicationActive: true);
    await HgWakeLockService.update(playing: false, applicationActive: true);
    expect(wakeLockCalls, [false, true, false]);
  });

  testWidgets('screen stays awake only while visible episode is playing', (
    tester,
  ) async {
    await mount(tester);
    expect(HgWakeLockService.requested, isTrue);
    expect(wakeLockCalls.last, isTrue);

    await tapSurface(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(platform.playing[1], isFalse);
    expect(HgWakeLockService.requested, isFalse);
    expect(wakeLockCalls.last, isFalse);

    await tester.tap(find.byKey(const ValueKey('hg-playback-play-button')));
    await tester.pump();
    expect(platform.playing[1], isTrue);
    expect(HgWakeLockService.requested, isTrue);
    expect(wakeLockCalls.last, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(HgWakeLockService.requested, isFalse);
    expect(wakeLockCalls.last, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(HgWakeLockService.requested, isTrue);
    expect(wakeLockCalls.last, isTrue);
  });
}
