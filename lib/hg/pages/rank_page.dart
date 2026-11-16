import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hg_api.dart';
import '../models/hg_models.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';
import '../widgets/hg_components.dart';
import '../widgets/secure_cover.dart';
import 'short_video_page.dart';

class RankPage extends StatefulWidget {
  const RankPage({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  static const tabs = [
    ('hot', '热播榜', '按全站热度排序'),
    ('recommend', '推荐榜', '大家正在追的短剧'),
    ('potential', '潜力榜', '正在上升的新剧'),
  ];

  String _kind = 'hot';
  List<HgRankItem> _items = const [];
  final Map<String, List<HgRankItem>> _cache = {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final kind = _kind;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<HgApi>().rank(kind);
      if (mounted) {
        setState(() {
          _cache[kind] = items;
          if (_kind == kind) _items = items;
        });
      }
    } catch (error) {
      if (mounted && _kind == kind) setState(() => _error = error);
    } finally {
      if (mounted && _kind == kind) setState(() => _loading = false);
    }
  }

  Future<void> _select(String kind) async {
    if (_kind == kind) return;
    final cached = _cache[kind];
    setState(() {
      _kind = kind;
      _items = cached ?? const [];
      _loading = cached == null;
      _error = null;
    });
    if (cached == null) await _load();
  }

  void _open(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShortVideoPage(
          videoIds: _items.map((item) => item.videoId).toList(growable: false),
          startIndex: index,
          title: tabs.firstWhere((item) => item.$1 == _kind).$2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final meta = tabs.firstWhere((item) => item.$1 == _kind);
    return ColoredBox(
      color: HgColors.paper,
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
                padding: EdgeInsets.fromLTRB(18, top + 14, 18, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.showBack) ...[
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '榜单',
                            style: TextStyle(
                              color: HgColors.ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meta.$3,
                            style: const TextStyle(
                              color: Color(0xFF85858A),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _RankTabs(tabs: tabs, kind: _kind, onSelected: _select),
              ),
            ),
            if (_loading && _items.isEmpty)
              const SliverToBoxAdapter(
                child: HgLoading(variant: HgLoadingVariant.list),
              )
            else if (_error != null && _items.isEmpty)
              SliverToBoxAdapter(
                child: HgErrorState(error: _error!, onRetry: _load),
              )
            else if (_items.isEmpty)
              const SliverToBoxAdapter(
                child: HgEmptyState(
                  icon: Icons.leaderboard_outlined,
                  title: '榜单暂时为空',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _RankHero(item: _items.first, onTap: () => _open(0)),
                ),
              ),
              if (_items.length > 1) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, 24, 18, 12),
                    child: Text(
                      '本期完整榜单',
                      style: TextStyle(
                        color: HgColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  sliver: SliverList.separated(
                    itemCount: _items.length - 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final itemIndex = index + 1;
                      return _RankRow(
                        item: _items[itemIndex],
                        onTap: () => _open(itemIndex),
                      );
                    },
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankTabs extends StatelessWidget {
  const _RankTabs({
    required this.tabs,
    required this.kind,
    required this.onSelected,
  });

  final List<(String, String, String)> tabs;
  final String kind;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEBE8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: tabs
            .map((tab) {
              final selected = tab.$1 == kind;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(tab.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? HgColors.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF717176),
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                      child: Text(tab.$2),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _RankHero extends StatelessWidget {
  const _RankHero({required this.item, required this.onTap});

  final HgRankItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HgColors.ink,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 224,
          child: Stack(
            fit: StackFit.expand,
            children: [
              HgCoverImage(url: item.cover, title: item.title),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF5000000),
                      Color(0xA8000000),
                      Color(0x05000000),
                    ],
                    stops: [0, 0.58, 1],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HgColors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TOP 01',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 106,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        height: 1.16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rankMeta(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD45C),
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          item.score.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${item.metricLabel} ${formatCount(item.metricValue)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 10,
                child: Text(
                  '01',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.22),
                    fontSize: 74,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.item, required this.onTap});

  final HgRankItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 102,
          child: Row(
            children: [
              SizedBox(
                width: 62,
                child: Center(
                  child: Text(
                    item.rank.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: item.rank <= 3
                          ? HgColors.orange
                          : const Color(0xFFB0AFB1),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 66,
                  height: 84,
                  child: HgCoverImage(url: item.cover, title: item.title),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: 14,
                    top: 12,
                    bottom: 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HgColors.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _rankMeta(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF929297),
                          fontSize: 10.5,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFD8A749),
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.score.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${item.metricLabel} ${formatCount(item.metricValue)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF85858A),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _rankMeta(HgRankItem item) {
  final episode = item.episodeCount > 0
      ? (item.isFinished
            ? '全 ${item.episodeCount} 集'
            : '更新至 ${item.episodeCount} 集')
      : '';
  return [
    item.categoryName,
    if (item.tags.isNotEmpty) item.tags.first,
    episode,
  ].where((value) => value.isNotEmpty).join(' · ');
}
