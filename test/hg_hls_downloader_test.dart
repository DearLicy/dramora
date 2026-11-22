import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/utils/hg_hls_downloader_native.dart';

void main() {
  test('downloads and rewrites a local HLS playlist', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    server.listen((request) async {
      requests.add(request.uri.path);
      if (request.uri.path == '/index.m3u8') {
        request.response.headers.contentType = ContentType.parse(
          'application/vnd.apple.mpegurl',
        );
        request.response.write('''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-KEY:METHOD=AES-128,URI="/key.key"
#EXTINF:2.0,
/segment1.ts
#EXTINF:2.0,
/segment2.ts
#EXT-X-ENDLIST
''');
      } else if (request.uri.path == '/key.key') {
        request.response.contentLength = 16;
        request.response.add(List<int>.filled(16, 7));
      } else if (request.uri.path == '/segment1.ts') {
        request.response.contentLength = 128;
        request.response.add(List<int>.filled(128, 1));
      } else if (request.uri.path == '/segment2.ts') {
        request.response.contentLength = 256;
        request.response.add(List<int>.filled(256, 2));
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    final root = Directory('.tmp/hls-download-test');
    if (await root.exists()) await root.delete(recursive: true);
    try {
      final progress = <HgDownloadProgressSnapshot>[];
      final output = await HgHlsDownloader.download(
        dio: Dio(),
        playlistUrl: 'http://127.0.0.1:${server.port}/index.m3u8',
        directory: root,
        parallelSegments: 2,
        onProgress: progress.add,
      );
      final manifest = await File(output.manifestPath).readAsString();
      expect(manifest, contains('URI="key_0.key"'));
      expect(manifest, contains('seg_00000.ts'));
      expect(await File('${output.directory}/key_0.key').length(), 16);
      expect(await File('${output.directory}/seg_00000.ts').length(), 128);
      expect(await File('${output.directory}/seg_00001.ts').length(), 256);
      expect(
        requests,
        containsAll([
          '/index.m3u8',
          '/key.key',
          '/segment1.ts',
          '/segment2.ts',
        ]),
      );
      expect(progress.last.totalBytes, 400);
      expect(progress.last.receivedBytes, 400);
      expect(progress.last.completedSegments, 2);
      expect(progress.last.totalSegments, 2);
      expect(progress.last.fraction, 1);
    } finally {
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
      final parent = Directory('.tmp');
      if (await parent.exists() && await parent.list().isEmpty) {
        await parent.delete();
      }
    }
  });
}
