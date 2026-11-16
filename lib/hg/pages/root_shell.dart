import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_metadata.dart';
import '../auth/app_controllers.dart';
import 'category_page.dart';
import 'home_page.dart';
import 'posts_page.dart';
import 'profile_page.dart';
import 'rank_page.dart';
import 'settings_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _releaseSeenKey = 'guomu.release.seen';

  static const _pages = [
    HomePage(),
    CategoryPage(),
    PostsPage(showBack: false),
    RankPage(),
    ProfilePage(),
  ];

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, '首页'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, '剧场'),
    (Icons.forum_outlined, Icons.forum_rounded, '吃瓜'),
    (Icons.emoji_events_outlined, Icons.emoji_events_rounded, '榜单'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  int _index = 0;
  final Set<int> _visited = {0};
  bool _sourceSheetShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowReleaseNotes();
    });
  }

  Future<void> _maybeShowReleaseNotes() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_releaseSeenKey) == HgAppMetadata.versionLabel) return;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const HgReleaseNotesSheet(),
    );
    await prefs.setString(_releaseSeenKey, HgAppMetadata.versionLabel);
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  Widget _body() {
    return IndexedStack(
      index: _index,
      children: List.generate(
        _pages.length,
        (index) =>
            _visited.contains(index) ? _pages[index] : const SizedBox.shrink(),
      ),
    );
  }

  Widget _appShell() {
    return Scaffold(
      body: _body(),
      bottomNavigationBar: _AppBottomBar(
        index: _index,
        items: _items,
        onSelected: _select,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = context.watch<SourceController>();
    if (source.needsManual && !source.isDiscovering && !_sourceSheetShown) {
      _sourceSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.42),
          builder: (_) => const HgSourceEditorSheet(recovery: true),
        );
      });
    }
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          if (!wide) return _appShell();
          final dark = Theme.of(context).brightness == Brightness.dark;
          return ColoredBox(
            color: dark ? const Color(0xFF050505) : const Color(0xFFE9E9EB),
            child: Center(
              child: Container(
                width: 560,
                height: constraints.maxHeight - 32,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 40,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: _appShell(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppBottomBar extends StatelessWidget {
  const _AppBottomBar({
    required this.index,
    required this.items,
    required this.onSelected,
  });

  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(items.length, (itemIndex) {
              final selected = itemIndex == index;
              final item = items[itemIndex];
              final color = selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.42);
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: item.$3,
                  child: InkWell(
                    onTap: () => onSelected(itemIndex),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.86,
                                  end: 1,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                          child: Icon(
                            selected ? item.$2 : item.$1,
                            key: ValueKey<bool>(selected),
                            size: 22,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
