import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/utils/hg_update_download_native.dart';
import 'package:guomu/hg/utils/hg_update_service.dart';
import 'package:pointycastle/digests/sha256.dart';

class _BinaryAdapter implements HttpClientAdapter {
  _BinaryAdapter(this.bytes, {this.gate});
  final List<int> bytes;
  final Completer<void>? gate;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (gate != null) await gate!.future;
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _url = 'https://api.github.com/repos/DearLicy/guomu/releases/assets/123';
HgReleaseAsset _asset({int size = 8, String digest = ''}) => HgReleaseAsset(
  name: 'Guomu-test.apk',
  downloadUrl: 'https://github.com/example.apk',
  size: size,
  apiUrl: _url,
  digest: digest,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory('.tmp/update-tests').create(recursive: true);
    directory = await directory.createTemp('download-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('release assets preserve the API binary URL and SHA256 digest', () {
    final asset = HgReleaseAsset.fromJson({
      'name': 'a.apk',
      'url': _url,
      'browser_download_url': 'https://github.com/a.apk',
      'size': 8,
      'digest': 'sha256:abcd',
    });
    expect(asset.binaryUrl, _url);
    expect(asset.digest, 'sha256:abcd');
  });

  test(
    'downloads through API with octet-stream and verifies length, ZIP header and digest',
    () async {
      final bytes = [0x50, 0x4b, 3, 4, 5, 6, 7, 8];
      final hash = SHA256Digest()
          .process(Uint8List.fromList(bytes))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final adapter = _BinaryAdapter(bytes);
      final dio = Dio()..httpClientAdapter = adapter;
      final progress = <int>[];
      final path = await HgUpdateDownload.download(
        _asset(digest: 'sha256:$hash'),
        client: dio,
        directory: directory,
        onProgress: (received, total) => progress.add(received),
      );
      expect(adapter.request!.uri.toString(), _url);
      expect(adapter.request!.headers['Accept'], 'application/octet-stream');
      expect(await File(path).readAsBytes(), bytes);
      expect(progress.last, 8);
      expect(directory.listSync().whereType<File>().map((f) => f.path), [path]);
    },
  );

  for (final entry in [
    (
      name: 'JSON instead of binary',
      bytes: utf8.encode('{"url":"not a binary"}'),
      size: 0,
      digest: '',
    ),
    (
      name: 'truncated binary',
      bytes: [0x50, 0x4b, 3, 4, 5, 6, 7, 8],
      size: 99,
      digest: '',
    ),
    (
      name: 'wrong checksum',
      bytes: [0x50, 0x4b, 3, 4, 5, 6, 7, 8],
      size: 8,
      digest: 'sha256:wrong',
    ),
  ]) {
    test('rejects ${entry.name} and deletes partial file', () async {
      final dio = Dio()..httpClientAdapter = _BinaryAdapter(entry.bytes);
      await expectLater(
        HgUpdateDownload.download(
          _asset(size: entry.size, digest: entry.digest),
          client: dio,
          directory: directory,
        ),
        throwsA(isA<HgUpdateException>()),
      );
      expect(directory.listSync(), isEmpty);
    });
  }

  test('cancellation removes partial download', () async {
    final gate = Completer<void>();
    final dio = Dio()
      ..httpClientAdapter = _BinaryAdapter([
        0x50,
        0x4b,
        3,
        4,
        5,
        6,
        7,
        8,
      ], gate: gate);
    final token = CancelToken();
    final pending = HgUpdateDownload.download(
      _asset(),
      client: dio,
      directory: directory,
      cancelToken: token,
    );
    final expectation = expectLater(
      pending,
      throwsA(
        isA<DioException>().having(
          (e) => CancelToken.isCancel(e),
          'cancelled',
          isTrue,
        ),
      ),
    );
    token.cancel();
    gate.complete();
    await expectation;
    expect(directory.listSync(), isEmpty);
  });

  test('installation invokes the native file provider path', () async {
    const channel = MethodChannel('com.guomu.huangguo/update');
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (value) async {
          call = value;
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await HgUpdateDownload.install('/cache/guomu-updates/app.apk');
    expect(call!.method, 'installApk');
    expect(call!.arguments, {'path': '/cache/guomu-updates/app.apk'});
  });

  test('signature migration can open the system uninstaller', () async {
    const channel = MethodChannel('com.guomu.huangguo/update');
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (value) async {
          call = value;
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await HgUpdateDownload.openUninstaller();
    expect(call!.method, 'openUninstaller');
  });
}
