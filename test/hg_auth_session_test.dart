import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/auth/app_controllers.dart';
import 'package:guomu/hg/models/hg_models.dart';
import 'package:guomu/hg/pages/login_sheet.dart';
import 'package:guomu/hg/theme/hg_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _staleUser = HgUser(
  id: 338861,
  username: 'DearLicy',
  nickname: 'DearLicy',
);

class _RejectedSessionApi extends HgApi {
  _RejectedSessionApi() : super(baseUrl: 'https://example.test');

  @override
  Future<void> collect(int videoId, bool on) async {
    onAuthenticationExpired?.call();
    throw const HgLoginRequiredException('登录状态已失效，请重新登录');
  }
}

class _RecoveryApi extends HgApi {
  _RecoveryApi() : super(baseUrl: 'https://example.test');

  HgUser _user = _staleUser;

  @override
  Future<({String token, HgUser user})> login(
    String username,
    String password,
  ) async {
    _user = HgUser(id: 338861, username: username, nickname: username);
    return (token: 'fresh-token', user: _user);
  }

  @override
  Future<HgUser> me() async => _user;

  @override
  Future<void> logout() async {}
}

Future<SharedPreferences> _stalePreferences() async {
  SharedPreferences.setMockInitialValues({
    'guomu.hg.token': 'expired-token',
    'guomu.hg.user': jsonEncode(_staleUser.toJson()),
  });
  return SharedPreferences.getInstance();
}

void main() {
  test(
    'login persists the token and cached user across controller restarts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = _RecoveryApi();
      final auth = AuthController(api, prefs);

      await auth.login('DearLicy', 'password');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.user?.id, 338861);
      expect(prefs.getString('guomu.hg.token'), 'fresh-token');
      expect(prefs.getString('guomu.hg.user'), isNotNull);
      auth.dispose();

      final restored = AuthController(api, prefs);
      addTearDown(restored.dispose);
      expect(restored.isLoggedIn, isTrue);
      expect(restored.user?.nickname, 'DearLicy');
      await restored.restore();
      expect(restored.user?.id, 338861);
    },
  );

  test('rejected request clears the stale token and cached user', () async {
    final prefs = await _stalePreferences();
    final api = _RejectedSessionApi();
    final auth = AuthController(api, prefs);
    addTearDown(auth.dispose);

    expect(auth.isLoggedIn, isTrue);
    expect(auth.user?.id, 338861);

    await expectLater(
      auth.toggleFavorite(10586),
      throwsA(isA<HgLoginRequiredException>()),
    );
    await auth.expireSession();

    expect(auth.isLoggedIn, isFalse);
    expect(auth.user, isNull);
    expect(prefs.getString('guomu.hg.token'), isNull);
    expect(prefs.getString('guomu.hg.user'), isNull);
  });

  testWidgets('an expired follow re-prompts login and retries once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await _stalePreferences();
    final api = _RecoveryApi();
    final auth = AuthController(api, prefs);
    addTearDown(auth.dispose);
    var attempts = 0;
    bool? result;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HgApi>.value(value: api),
          ChangeNotifierProvider<AuthController>.value(value: auth),
        ],
        child: MaterialApp(
          theme: buildHgTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const ValueKey('hg-auth-action'),
                  onPressed: () async {
                    result = await runAuthenticated(context, () async {
                      attempts++;
                      if (attempts == 1) {
                        throw const HgLoginRequiredException(
                          '登录状态已失效，请重新登录',
                          true,
                        );
                      }
                      return true;
                    });
                  },
                  child: const Text('追剧'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('hg-auth-action')));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.text('登录黄果'), findsOneWidget);
    expect(auth.isLoggedIn, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('hg-login-username')),
      'DearLicy',
    );
    await tester.enterText(
      find.byKey(const ValueKey('hg-login-password')),
      'password',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('hg-login-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hg-login-submit')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(result, isTrue);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.user?.nickname, 'DearLicy');
    expect(find.text('登录黄果'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
