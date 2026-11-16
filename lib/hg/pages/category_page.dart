import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../widgets/hg_components.dart';
import 'detail_page.dart';

/// 剧场只保留内容和切换，不再重复首页的搜索、标题与说明卡片。
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  static const _tabs = ['全部', '短剧', '漫剧'];

  List<HgVideoCard> _videos = const [];
  final Map<int, List<HgVideoCard>> _cache = {};
  int _tabIndex = 0;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tabIndex = _tabIndex;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<HgApi>();
      final page = switch (tabIndex) {
        1 => await api.category('ai-duanju', size: 30, sort: 'new'),
        2 => await api.category('ai-manju', size: 30, sort: 'new'),
        _ => await api.feed(size: 30),
      };
      if (mounted) {
        setState(() {
          _cache[tabIndex] = page.items;
          if (_tabIndex == tabIndex) _videos = page.items;
        });
      }
    } catch (error) {
      if (mounted && _tabIndex == tabIndex) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && _tabIndex == tabIndex) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    final cached = _cache[index];
    setState(() {
      _tabIndex = index;
      _videos = cached ?? const [];
      _loading = cached == null;
      _error = null;
    });
    if (cached == null) _load();
  }

  void _openDetail(HgVideoCard video) {
    final ids = _videos.map((item) => item.id).toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DramaDetailPage(
          videoId: video.id,
          preloaded: video,
          feedIds: ids,
          feedIndex: ids.indexOf(video.id).clamp(0, ids.length - 1).toInt(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontal = width >= 700 ? 30.0 : 16.0;
        final columns = width >= 1000 ? 4 : 2;
        final gap = width >= 700 ? 16.0 : 12.0;
        final effectiveWidth = width.clamp(0, 1200).toDouble();
        final cellWidth =
            (effectiveWidth - horizontal * 2 - gap * (columns - 1)) / columns;
        final cardHeight = cellWidth / 0.68;
        return ColoredBox(
          color: HgColors.paper,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: RefreshIndicator(
                onRefresh: _load,
                color: HgColors.orange,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          top + 12,
                          horizontal,
                          10,
                        ),
                        child: _TheaterTabs(
                          tabs: _tabs,
                          index: _tabIndex,
                          onSelected: _selectTab,
                        ),
                      ),
                    ),
                    if (_loading && _videos.isEmpty)
                      const SliverToBoxAdapter(child: HgLoading())
                    else if (_error != null && _videos.isEmpty)
                      SliverToBoxAdapter(
                        child: HgErrorState(error: _error!, onRetry: _load),
                      )
                    else if (_videos.isEmpty)
                      const SliverToBoxAdapter(
                        child: HgEmptyState(
                          icon: Icons.movie_outlined,
                          title: '还没有可播放的短剧',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          10,
                          horizontal,
                          30,
                        ),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: gap,
                                mainAxisSpacing: 16,
                                mainAxisExtent: cardHeight,
                              ),
                          itemCount: _videos.length,
                          itemBuilder: (context, index) => HgVideoGridCard(
                            video: _videos[index],
                            onTap: () => _openDetail(_videos[index]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TheaterTabs extends StatelessWidget {
  const _TheaterTabs({
    required this.tabs,
    required this.index,
    required this.onSelected,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (itemIndex) {
        final selected = itemIndex == index;
        return Expanded(
          child: Semantics(
            selected: selected,
            button: true,
            label: tabs[itemIndex],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(itemIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: selected
                            ? HgColors.ink
                            : HgColors.ink.withValues(alpha: 0.38),
                        fontSize: selected ? 18 : 15,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: selected ? -0.35 : -0.1,
                      ),
                      child: Text(tabs[itemIndex]),
                    ),
                    const SizedBox(height: 7),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: selected ? 22 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: HgColors.ink,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
