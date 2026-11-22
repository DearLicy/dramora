import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/auth/app_controllers.dart';
import 'package:guomu/hg/models/hg_models.dart';
import 'package:guomu/hg/pages/comments_sheet.dart';
import 'package:guomu/hg/theme/hg_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CommentsApi extends HgApi {
  _CommentsApi() : super(baseUrl: 'https://example.test');

  @override
  Future<HgCommentPage> comments(
    int videoId,
    int episode, {
    int page = 1,
    int size = 20,
  }) async => HgCommentPage(
    items: const [
      HgComment(
        id: 1,
        userId: 7,
        nickname: '追剧用户',
        text: '这一集节奏很好，评论区也要保持顺手。',
        time: '刚刚',
        likeCount: 12,
        replyCount: 2,
        ipRegion: '上海',
      ),
    ],
    pagination: const HgPagination(page: 1, pages: 1, total: 1),
  );
}

void main() {
  testWidgets('comments sheet keeps rounded composer and actions tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _CommentsApi();
    final auth = AuthController(api, prefs);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HgApi>.value(value: api),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: MaterialApp(
          theme: buildHgTheme(Brightness.light),
          home: const Scaffold(
            body: CommentsSheet(
              videoId: 1,
              episode: 1,
              title: '界面回归短剧',
              totalComments: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('追剧用户'), findsOneWidget);
    expect(find.text('登录后参与评论'), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-comment-like-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-comment-replies-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('hg-comment-send')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
