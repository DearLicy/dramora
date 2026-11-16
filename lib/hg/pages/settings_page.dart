import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../app_metadata.dart';
import '../auth/app_controllers.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../utils/hg_media_cache.dart';
import '../widgets/secure_cover.dart';
import 'about_page.dart';
import 'login_sheet.dart';
import 'update_history_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _cacheBytes = 0;
  bool _clearingCache = false;
  String _cacheMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final contentBytes = await context.read<HgApi>().cacheSizeBytes();
    final mediaBytes = await HgMediaCache.sizeBytes();
    if (mounted) {
      setState(() => _cacheBytes = contentBytes + mediaBytes);
    }
  }

  Future<void> _clearCache() async {
    if (_clearingCache) return;
    final confirmed = await _showConfirmSheet(
      context,
      title: '清除缓存？',
      message: '会清除内容、封面和已预加载的视频分片，不会退出登录，也不会删除收藏、历史或资料。',
      confirmLabel: '清除缓存',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _clearingCache = true;
      _cacheMessage = '';
    });
    try {
      await context.read<HgApi>().clearContentCache();
      await HgMediaCache.clear();
      HgCoverRepository.instance.clear();
      if (mounted) {
        setState(() {
          _cacheBytes = 0;
          _cacheMessage = '缓存已清除';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _cacheMessage = cleanError(error));
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmSheet(
      context,
      title: '退出登录？',
      message: '退出后本机仍会保留离线缓存、追剧进度和观看历史。',
      confirmLabel: '退出登录',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<AuthController>().logout();
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _editSource() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const HgSourceEditorSheet(),
    );
    if (changed == true && mounted) {
      HgCoverRepository.instance.clear();
      await context.read<HgApi>().clearContentCache();
    }
  }

  void _openReleaseHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const UpdateHistoryPage()));
  }

  Future<void> _showThemeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => const _ThemeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final source = context.watch<SourceController>();
    final theme = context.watch<ThemeController>();
    final user = auth.user;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F6),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SettingsGroup(
            title: '账号',
            children: [
              if (auth.isLoggedIn && user != null)
                _SettingsRow(
                  leading: HgAvatar(
                    name: user.nickname,
                    url: user.avatar,
                    size: 42,
                    color: colorFromHex(user.avatarColor),
                  ),
                  title: user.nickname,
                  subtitle: 'ID：${user.id}',
                )
              else
                _SettingsRow(
                  leading: const _RowIcon(Icons.person_outline_rounded),
                  title: '登录黄果账号',
                  subtitle: '同步追剧、历史、点赞和消息',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLoginSheet(context),
                ),
              if (auth.isLoggedIn && user != null) ...[
                const _SettingsDivider(),
                _SettingsRow(
                  leading: const _RowIcon(
                    Icons.logout_rounded,
                    color: Color(0xFFC64F45),
                  ),
                  title: '退出登录',
                  titleColor: const Color(0xFFC64F45),
                  subtitle: '仅退出当前账号，不删除缓存',
                  onTap: _logout,
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '播放与缓存',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.cleaning_services_outlined),
                title: _clearingCache ? '正在清理…' : '清除缓存',
                subtitle: _cacheMessage.isNotEmpty
                    ? _cacheMessage
                    : _formatBytes(_cacheBytes),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _clearingCache ? null : _clearCache,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '外观',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.brightness_6_outlined),
                title: '显示模式',
                subtitle: switch (theme.mode) {
                  ThemeMode.light => '浅色',
                  ThemeMode.dark => '深色',
                  ThemeMode.system => '跟随系统',
                },
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showThemeSheet,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '内容源',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.dns_outlined),
                title: '内容源 · ${source.sources.length} 个',
                subtitle: source.baseUrl,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _editSource,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: '关于与更新',
            children: [
              _SettingsRow(
                leading: const _RowIcon(Icons.new_releases_outlined),
                title: '更新记录',
                subtitle:
                    '当前 ${HgAppMetadata.versionLabel} · ${HgAppMetadata.releaseTitle}',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openReleaseHistory,
              ),
              const _SettingsDivider(),
              _SettingsRow(
                leading: const _RowIcon(Icons.code_rounded),
                title: '关于果幕',
                subtitle: '版本信息、数据边界与技术说明',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutGuomuPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF77777C),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor ?? const Color(0xFF28282B),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF97979B),
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon, {this.color = const Color(0xFF343438)});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 59, color: Color(0xFFF1F1F2));
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final choices = [
      (ThemeMode.system, Icons.brightness_auto_rounded, '跟随系统', '跟随设备的浅色与深色设置'),
      (ThemeMode.light, Icons.light_mode_rounded, '浅色', '明亮、轻盈的日间阅读体验'),
      (ThemeMode.dark, Icons.dark_mode_rounded, '深色', '低亮度环境下更舒适的观看体验'),
    ];
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.52,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 9, 20, 18),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5E7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '显示模式',
              style: TextStyle(
                color: Color(0xFF202124),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              '选择适合当前环境的界面外观',
              style: TextStyle(color: Color(0xFF8B8B90), fontSize: 11.5),
            ),
            const SizedBox(height: 15),
            for (final choice in choices) ...[
              Material(
                color: const Color(0xFFF5F5F6),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () async {
                    await controller.setMode(choice.$1);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          choice.$2,
                          size: 21,
                          color: const Color(0xFF3A3A3C),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                choice.$3,
                                style: const TextStyle(
                                  color: Color(0xFF202124),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                choice.$4,
                                style: const TextStyle(
                                  color: Color(0xFF8B8B90),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (controller.mode == choice.$1)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: HgColors.orange,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (choice != choices.last) const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }
}

class HgReleaseNotesSheet extends StatelessWidget {
  const HgReleaseNotesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 9),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5E7),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: HgColors.ink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '果幕 ${HgAppMetadata.versionLabel}',
                          style: TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          HgAppMetadata.releaseTitle,
                          style: TextStyle(
                            color: Color(0xFF8B8B90),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                itemCount: HgAppMetadata.releaseNotes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 11),
                itemBuilder: (context, index) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        color: HgColors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        HgAppMetadata.releaseNotes[index],
                        style: const TextStyle(
                          color: Color(0xFF55555A),
                          fontSize: 12.5,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: HgColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('知道了'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HgSourceEditorSheet extends StatefulWidget {
  const HgSourceEditorSheet({super.key, this.recovery = false});

  final bool recovery;

  @override
  State<HgSourceEditorSheet> createState() => _SourceEditorSheetState();
}

class _SourceEditorSheetState extends State<HgSourceEditorSheet> {
  late final TextEditingController _controller;
  bool _adding = false;
  bool _refreshing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _adding) return;
    setState(() {
      _adding = true;
      _message = null;
    });
    try {
      final sourceController = context.read<SourceController>();
      final normalized = await sourceController.addSource(value);
      if (!mounted) return;
      context.read<HgApi>().setBaseUrl(normalized);
      _controller.clear();
      setState(() => _message = '已添加，点击地址即可切换');
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = cleanError(error));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _message = null;
    });
    try {
      final sourceController = context.read<SourceController>();
      await sourceController.startAutoDiscovery();
      if (!mounted) return;
      setState(() => _message = '已同步 ${sourceController.sources.length} 个数据源');
    } catch (error) {
      if (mounted) setState(() => _message = cleanError(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _select(String value) async {
    final sourceController = context.read<SourceController>();
    await sourceController.selectSource(value);
    if (!mounted) return;
    context.read<HgApi>().setBaseUrl(sourceController.baseUrl);
    HgCoverRepository.instance.clear();
    await context.read<HgApi>().clearContentCache();
    if (mounted) setState(() => _message = '已切换到 ${sourceController.baseUrl}');
  }

  Future<void> _remove(String value) async {
    final sourceController = context.read<SourceController>();
    await sourceController.removeSource(value);
    if (!mounted) return;
    context.read<HgApi>().setBaseUrl(sourceController.baseUrl);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final source = context.watch<SourceController>();
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.84,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '数据源',
                    style: TextStyle(
                      color: Color(0xFF202124),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${source.sources.length} 个',
                  style: const TextStyle(
                    color: Color(0xFF949499),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              widget.recovery
                  ? '当前地址都无法连接。请手动填写一个可用地址，或重新获取官方线路。'
                  : '客户端会通过本机网络从官方发布页和 GitHub 清单同步可用线路，也可以手动添加。',
              style: TextStyle(
                color: widget.recovery
                    ? const Color(0xFFC64F45)
                    : const Color(0xFF85858A),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(_refreshing ? '正在同步…' : '自动获取最新地址'),
            ),
            const SizedBox(height: 16),
            ...source.sources.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: item == source.baseUrl
                      ? const Color(0xFFF1F1F2)
                      : const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    onTap: () => _select(item),
                    borderRadius: BorderRadius.circular(13),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
                      child: Row(
                        children: [
                          Icon(
                            item == source.baseUrl
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: item == source.baseUrl
                                ? HgColors.orange
                                : const Color(0xFF9A9A9E),
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF343438),
                                fontSize: 12,
                                fontWeight: item == source.baseUrl
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: source.sources.length <= 1
                                ? null
                                : () => _remove(item),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: Color(0xFF9A9A9E),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: const InputDecoration(
                hintText: '手动填写 https://example.com',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 9),
            FilledButton(
              onPressed: _adding ? null : _add,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: HgColors.ink,
              ),
              child: Text(_adding ? '添加中…' : '添加数据源'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: const TextStyle(color: Color(0xFF77777C), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5E7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF202124),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF77777C),
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 47,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: danger
                      ? const Color(0xFFC64F45)
                      : HgColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '暂无缓存';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
