import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/models/hg_download_models.dart';
import 'package:guomu/hg/models/hg_models.dart';
import 'package:guomu/hg/utils/hg_download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ResumeApi extends HgApi {
  _ResumeApi() : super(baseUrl: 'https://example.test');

  @override
  Future<HgVideoDetail> video(int id) async {
    return HgVideoDetail.fromJson({
      'id': id,
      'title': '恢复下载测试',
      'episode_count': 1,
      'episodes': [
        {'ep_num': 1},
      ],
    });
  }
}

class _ResumeDownloads extends HgDownloadManager {
  _ResumeDownloads(super.api, super.prefs);

  final List<int> resumed = [];

  @override
  Future<void> startDramaDownload(
    HgVideoDetail detail, {
    bool? autoUpdate,
    bool downloadNow = true,
  }) async {
    resumed.add(detail.id);
  }
}

void main() {
  test(
    'interrupted downloads are marked then resumed after app restore',
    () async {
      final task = const HgDownloadTask(
        videoId: 10586,
        title: '蜜桃臀',
        cover: '',
        totalEpisodes: 6,
        state: '下载中 · 第 1/6 集',
        progress: 0.1,
        receivedBytes: 20 * 1024 * 1024,
        totalBytes: 500 * 1024 * 1024,
        speedBytesPerSecond: 100 * 1024,
      );
      SharedPreferences.setMockInitialValues({
        'guomu.downloads.v1': jsonEncode([task.toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final manager = _ResumeDownloads(_ResumeApi(), prefs);
      addTearDown(manager.dispose);

      await manager.restore();

      expect(manager.tasks.single.state, '等待恢复');
      expect(manager.tasks.single.speedBytesPerSecond, 0);
      expect(manager.tasks.single.isDownloading, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect(manager.resumed, [10586]);
    },
  );
}
