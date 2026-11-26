import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/api/hg_source_pool.dart';

void main() {
  group('HgSourcePool', () {
    test(
      'selects the fastest healthy source after parallel probe results',
      () async {
        final pool = HgSourcePool(
          sources: const ['https://slow.example', 'https://fast.example'],
          activeSource: 'https://slow.example',
        );

        await pool.recordSuccess(
          'https://slow.example',
          const Duration(milliseconds: 420),
          promote: false,
        );
        await pool.recordSuccess(
          'https://fast.example',
          const Duration(milliseconds: 45),
          promote: false,
        );

        expect(pool.selectBestAvailable(), 'https://fast.example');
        expect(pool.baseUrl, 'https://fast.example');
        expect(pool.rankedSources.first, 'https://fast.example');
      },
    );

    test(
      'cooldown and automatic-selection preference survive serialization',
      () async {
        final pool = HgSourcePool(
          sources: const ['https://one.example', 'https://two.example'],
          activeSource: 'https://one.example',
          automaticSelection: false,
        );
        await pool.recordFailure('https://one.example');
        await pool.recordSuccess(
          'https://two.example',
          const Duration(milliseconds: 80),
          promote: false,
        );

        final restored = HgSourcePool.fromJson(pool.toJson());

        expect(restored.automaticSelection, isFalse);
        expect(
          restored.healthFor('https://one.example')!.isCoolingDown,
          isTrue,
        );
        expect(restored.selectBestAvailable(), 'https://two.example');
        expect(restored.baseUrl, 'https://one.example');
      },
    );
  });

  group('HgApi source failover', () {
    late HttpServer failingServer;
    late HttpServer healthyServer;
    var failingRequests = 0;
    var healthyRequests = 0;

    setUp(() async {
      failingRequests = 0;
      healthyRequests = 0;
      failingServer = await _server((request) async {
        failingRequests++;
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"status":0}');
        await request.response.close();
      });
      healthyServer = await _server((request) async {
        healthyRequests++;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'status': 1,
            'data': {
              'items': [
                {'word': '真实数据'},
              ],
            },
          }),
        );
        await request.response.close();
      });
    });

    tearDown(() async {
      await failingServer.close(force: true);
      await healthyServer.close(force: true);
    });

    test('retries a read on the next healthy source and promotes it', () async {
      final first = _sourceUrl(failingServer);
      final second = _sourceUrl(healthyServer);
      final pool = HgSourcePool(sources: [first, second], activeSource: first);
      final api = HgApi(
        baseUrl: first,
        sourceRouter: pool,
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 1),
            receiveTimeout: const Duration(seconds: 1),
          ),
        ),
      );

      expect(await api.hotSearchWords(), ['真实数据']);
      expect(failingRequests, 1);
      expect(healthyRequests, 1);
      expect(pool.baseUrl, second);
    });

    test('does not retry a write against another source', () async {
      final first = _sourceUrl(failingServer);
      final second = _sourceUrl(healthyServer);
      final pool = HgSourcePool(sources: [first, second], activeSource: first);
      final api = HgApi(
        baseUrl: first,
        sourceRouter: pool,
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 1),
            receiveTimeout: const Duration(seconds: 1),
          ),
        ),
      );

      await expectLater(
        api.login('user', 'password'),
        throwsA(isA<HgApiException>()),
      );
      expect(failingRequests, 1);
      expect(healthyRequests, 0);
    });

    test(
      'native reads use the real route instead of the retired edge envelope',
      () async {
        final seen = <String>[];
        final server = await _server((request) async {
          seen.add('${request.method} ${request.uri.path}');
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'status': 1,
              'data': {
                'items': [
                  {'word': '直连接口'},
                ],
              },
            }),
          );
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        final api = HgApi(baseUrl: _sourceUrl(server), dio: Dio());
        expect(await api.hotSearchWords(), ['直连接口']);
        expect(seen, ['GET /api/search/hot']);
      },
    );

    test('source probe checks the current public home route', () async {
      final seen = <String>[];
      final server = await _server((request) async {
        seen.add('${request.method} ${request.uri.path}');
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'status': 1,
            'data': {'banners': [], 'latest': []},
          }),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final probe = await HgApi.probeSource(_sourceUrl(server));
      expect(probe.available, isTrue);
      expect(seen, ['GET /api/home']);
    });
  });
}

Future<HttpServer> _server(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

String _sourceUrl(HttpServer server) => 'http://127.0.0.1:${server.port}';
