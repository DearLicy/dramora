import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 接收灵动岛、锁屏实时活动或系统 Scheme 打开的果幕链接。
abstract final class HgDeepLinkService {
  static const _channel = MethodChannel('com.guomu.huangguo/deeplink');
  static Future<void> Function(Uri uri)? _handler;

  static Future<void> initialize({
    required Future<void> Function(Uri uri) onLink,
  }) async {
    _handler = onLink;
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'link') return;
      final value = call.arguments?.toString() ?? '';
      final uri = Uri.tryParse(value);
      if (uri != null) await _handler?.call(uri);
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      final uri = Uri.tryParse(initial ?? '');
      if (uri != null && uri.scheme == 'guomu') {
        await _handler?.call(uri);
      }
    } catch (_) {
      // 原生插件不可用时不影响普通启动。
    }
  }
}
