import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/api/hg_source_pool.dart';

class _TestRouter implements HgSourceRouter {
  _TestRouter(this.sources);

  final List<String> sources;

  @override
  String get baseUrl => sources.first;

  @override
  List<String> get rankedSources => sources;

  @override
  Future<void> recordFailure(String baseUrl) async {}

  @override
  Future<void> recordSuccess(
    String baseUrl,
    Duration latency, {
    required bool promote,
  }) async {}
}

typedef _Reply = ({int statusCode, Map<String, dynamic> body});

class _AuthServer {
  _AuthServer(this.server, this.replies) {
    server.listen(_handle);
  }

  final HttpServer server;
  final _Reply Function(String source, String apiPath, int call) replies;
  final Map<String, int> _calls = {};

  String get origin => 'http://127.0.0.1:${server.port}';

  Future<void> _handle(HttpRequest request) async {
    final envelope = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
    final source = request.uri.pathSegments.first;
    final apiPath = envelope['path']?.toString() ?? '';
    final key = '$source:$apiPath';
    final call = (_calls[key] ?? 0) + 1;
    _calls[key] = call;
    final reply = replies(source, apiPath, call);
    request.response.statusCode = reply.statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(reply.body));
    await request.response.close();
  }

  Future<void> close() => server.close(force: true);
}

Map<String, dynamic> _unauthorized() => {'status': 0, 'msg': 'invalid token'};

Map<String, dynamic> _me() => {
  'status': 1,
  'data': {'id': 338861, 'username': 'DearLicy', 'nickname': 'DearLicy'},
};

void main() {
  test('a transient 401 does not clear a token that /me confirms', () async {
    late _AuthServer endpoint;
    endpoint = _AuthServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      (source, path, call) {
        if (path.startsWith('/api/users/me/collects')) {
          return (statusCode: 401, body: _unauthorized());
        }
        if (path == '/api/account/me') {
          return (statusCode: 200, body: _me());
        }
        return (statusCode: 404, body: {'status': 0});
      },
    );
    addTearDown(endpoint.close);
    var expiredCalls = 0;
    final api =
        HgApi(
            dio: Dio(),
            sourceRouter: _TestRouter([
              endpoint.origin,
              '${endpoint.origin}/b',
            ]),
          )
          ..token = 'valid-token'
          ..onAuthenticationExpired = () => expiredCalls++;

    await expectLater(
      api.myCollects(),
      throwsA(
        isA<HgLoginRequiredException>().having(
          (error) => error.confirmed,
          'confirmed',
          isFalse,
        ),
      ),
    );
    expect(expiredCalls, 0);
  });

  test(
    'one rejecting source plus one valid source preserves the session',
    () async {
      late _AuthServer endpoint;
      endpoint = _AuthServer(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        (source, path, call) {
          if (path.startsWith('/api/users/me/collects')) {
            return (statusCode: 401, body: _unauthorized());
          }
          if (path == '/api/account/me') {
            return source == 'a'
                ? (statusCode: 401, body: _unauthorized())
                : (statusCode: 200, body: _me());
          }
          return (statusCode: 404, body: {'status': 0});
        },
      );
      addTearDown(endpoint.close);
      var expiredCalls = 0;
      final api =
          HgApi(
              dio: Dio(),
              sourceRouter: _TestRouter([
                '${endpoint.origin}/a',
                '${endpoint.origin}/b',
              ]),
            )
            ..token = 'valid-token'
            ..onAuthenticationExpired = () => expiredCalls++;

      await expectLater(
        api.myCollects(),
        throwsA(
          isA<HgLoginRequiredException>().having(
            (error) => error.confirmed,
            'confirmed',
            isFalse,
          ),
        ),
      );
      expect(expiredCalls, 0);
    },
  );

  test('two sources rejecting /me confirm an expired token once', () async {
    late _AuthServer endpoint;
    endpoint = _AuthServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      (source, path, call) {
        if (path.startsWith('/api/users/me/collects')) {
          return (statusCode: 401, body: _unauthorized());
        }
        if (path == '/api/account/me') {
          return (statusCode: 401, body: _unauthorized());
        }
        return (statusCode: 404, body: {'status': 0});
      },
    );
    addTearDown(endpoint.close);
    var expiredCalls = 0;
    final api =
        HgApi(
            dio: Dio(),
            sourceRouter: _TestRouter([
              '${endpoint.origin}/a',
              '${endpoint.origin}/b',
            ]),
          )
          ..token = 'expired-token'
          ..onAuthenticationExpired = () => expiredCalls++;

    await expectLater(
      api.myCollects(),
      throwsA(
        isA<HgLoginRequiredException>().having(
          (error) => error.confirmed,
          'confirmed',
          isTrue,
        ),
      ),
    );
    expect(expiredCalls, 1);
  });

  test(
    '403 is a permission error and never clears the login session',
    () async {
      late _AuthServer endpoint;
      endpoint = _AuthServer(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        (source, path, call) => (statusCode: 403, body: {'status': 0}),
      );
      addTearDown(endpoint.close);
      var expiredCalls = 0;
      final api =
          HgApi(dio: Dio(), sourceRouter: _TestRouter([endpoint.origin]))
            ..token = 'valid-token'
            ..onAuthenticationExpired = () => expiredCalls++;

      await expectLater(
        api.myCollects(),
        throwsA(
          isA<HgApiException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having(
                (error) => error is HgLoginRequiredException,
                'loginRequired',
                isFalse,
              ),
        ),
      );
      expect(expiredCalls, 0);
    },
  );
}
