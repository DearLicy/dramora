abstract final class HgAppMetadata {
  static const String version = '1.4.0';
  static const String buildNumber = '5';
  static const String versionLabel = 'v1.4.0 (5)';
  static const String releaseTitle = '原生体验与续播版';
  static const List<String> releaseNotes = [
    '个人页右上角恢复设置入口，消息与设置分层展示，头像抽屉只保留账号操作。',
    '剧场页缩短为顶部全部/短剧/漫剧切换与内容网格，移除搜索、介绍和最近更新区块。',
    '榜单页改为精选第一名大卡与紧凑排名列表，专题页改为大图精选和双列卡片。',
    '追剧、历史、喜欢、详情、榜单和专题统一读取本机播放进度，可从上次秒数继续。',
    '播放器切集和退出时保存当前集数、播放位置与时长，邻近集继续自动预加载。',
    '播放器支持拖动进度条快进，并完善长按上滑锁定、下滑解除二倍速提示。',
    '详情页三点菜单、设置页版本历史和全站加载骨架动画已完成。',
  ];

  static const List<HgReleaseRecord> releaseHistory = [
    HgReleaseRecord(
      version: 'v1.4.0',
      buildNumber: '5',
      date: '2026-11-16',
      title: '原生体验与续播版',
      features: [
        '追剧、历史、喜欢、详情、榜单和专题统一读取本机播放进度，可继续上次集数与播放位置。',
        '播放器新增可拖动进度条，支持点击定位、跟手预览时间和松手跳转。',
        '长按播放器两侧可临时二倍速，上滑锁定，锁定后继续长按两侧下滑解除。',
        '详情页右上角三点菜单新增分享、刷新详情、从头播放和清除本剧记录。',
        '设置页新增独立更新记录页，按版本展示新增功能、体验优化和问题修复。',
      ],
      improvements: [
        '剧场页改为顶部全部、短剧、漫剧切换，缩短页面并移除重复说明区。',
        '榜单页改为重点作品大卡与完整排名列表，专题页改为精选大图与双列卡片。',
        '标签页改为分类切换和紧凑标签网格，标签详情页同步精简。',
        '个人页右上角固定为设置入口，消息入口保留在设置左侧，头像抽屉移除重复设置项。',
        '首页、剧场、榜单、专题、标签等页面无缓存时统一展示微光骨架动画。',
      ],
      fixes: [
        '修复追剧入口和历史入口显示的播放集数不一致。',
        '修复续播只记录集数、不记录具体播放位置的问题。',
        '修复详情页播放按钮总是从第 1 集开始的问题。',
      ],
    ),
    HgReleaseRecord(
      version: 'v1.3.0',
      buildNumber: '4',
      date: '',
      title: '第三方客户端与内容中心版',
      features: [
        '首页按精选推荐、最近上新、热播短剧、专题推荐重新组织，并支持查看更多。',
        '支持多个自定义数据源与本机网络自动发现官方最新可用线路。',
        '观看历史改为本机保存，不再依赖官方历史接口。',
      ],
      improvements: [
        '搜索、短剧、漫剧、题材标签、榜单和专题数据在启动阶段预加载。',
        '设置页支持外观选择、缓存管理与数据源管理。',
        '吃瓜页面选中图标和首页快捷卡改为自绘图形，减少不同环境的字体差异。',
      ],
      fixes: ['修复个人页重复入口与观看历史不同步问题。', '修复部分环境中图标字体缺失导致选中状态不可见。'],
    ),
  ];
}

class HgReleaseRecord {
  const HgReleaseRecord({
    required this.version,
    required this.buildNumber,
    required this.date,
    required this.title,
    required this.features,
    required this.improvements,
    required this.fixes,
  });

  final String version;
  final String buildNumber;
  final String date;
  final String title;
  final List<String> features;
  final List<String> improvements;
  final List<String> fixes;

  String get versionLabel => '$version ($buildNumber)';
}
