/// Domain层的书籍实体 - 纯净的业务对象，不依赖任何第三方库
/// 参考：Clean Architecture - Entity Layer
class BookEntity {
  final String bookUrl; // 详情页URL，唯一标识
  final String tocUrl; // 目录页URL
  final String origin; // 书源URL
  final String originName; // 书源名称
  final String name; // 书籍名称
  final String author; // 作者名称
  final String? kind; // 分类信息(书源获取)
  final String? customTag; // 分类信息(用户修改)
  final String? coverUrl; // 封面URL(书源获取)
  final String? customCoverUrl; // 封面URL(用户修改)
  final String? intro; // 简介(书源获取)
  final String? customIntro; // 简介(用户修改)
  final String? charset; // 自定义字符集
  final int type; // 书籍类型
  final int group; // 自定义分组索引号
  final String? latestChapterTitle; // 最新章节标题
  final int latestChapterTime; // 最新章节时间
  final int lastCheckTime; // 最近更新检查时间
  final int lastCheckCount; // 最近新章节数量
  final int totalChapterNum; // 章节总数
  final String? durChapterTitle; // 当前章节名称
  final int durChapterIndex; // 当前章节索引
  final int durChapterPos; // 当前阅读位置
  final int durChapterTime; // 最近阅读时间
  final String? wordCount; // 字数
  final bool canUpdate; // 是否可更新
  final int order; // 手动排序
  final int originOrder; // 书源排序
  final String? variable; // 自定义变量
  final int syncTime; // 同步时间

  const BookEntity({
    required this.bookUrl,
    required this.tocUrl,
    required this.origin,
    required this.originName,
    required this.name,
    required this.author,
    this.kind,
    this.customTag,
    this.coverUrl,
    this.customCoverUrl,
    this.intro,
    this.customIntro,
    this.charset,
    required this.type,
    required this.group,
    this.latestChapterTitle,
    required this.latestChapterTime,
    required this.lastCheckTime,
    required this.lastCheckCount,
    required this.totalChapterNum,
    this.durChapterTitle,
    required this.durChapterIndex,
    required this.durChapterPos,
    required this.durChapterTime,
    this.wordCount,
    required this.canUpdate,
    required this.order,
    required this.originOrder,
    this.variable,
    required this.syncTime,
  });

  /// 获取显示封面
  String? get displayCover => customCoverUrl ?? coverUrl;

  /// 获取显示简介
  String? get displayIntro => customIntro ?? intro;

  /// 是否本地书籍
  bool get isLocal => origin == 'local';

  /// 是否已更新
  bool get hasUpdate => lastCheckCount > 0;

  /// 复制并修改部分字段
  BookEntity copyWith({
    String? bookUrl,
    String? tocUrl,
    String? origin,
    String? originName,
    String? name,
    String? author,
    String? kind,
    String? customTag,
    String? coverUrl,
    String? customCoverUrl,
    String? intro,
    String? customIntro,
    String? charset,
    int? type,
    int? group,
    String? latestChapterTitle,
    int? latestChapterTime,
    int? lastCheckTime,
    int? lastCheckCount,
    int? totalChapterNum,
    String? durChapterTitle,
    int? durChapterIndex,
    int? durChapterPos,
    int? durChapterTime,
    String? wordCount,
    bool? canUpdate,
    int? order,
    int? originOrder,
    String? variable,
    int? syncTime,
  }) {
    return BookEntity(
      bookUrl: bookUrl ?? this.bookUrl,
      tocUrl: tocUrl ?? this.tocUrl,
      origin: origin ?? this.origin,
      originName: originName ?? this.originName,
      name: name ?? this.name,
      author: author ?? this.author,
      kind: kind ?? this.kind,
      customTag: customTag ?? this.customTag,
      coverUrl: coverUrl ?? this.coverUrl,
      customCoverUrl: customCoverUrl ?? this.customCoverUrl,
      intro: intro ?? this.intro,
      customIntro: customIntro ?? this.customIntro,
      charset: charset ?? this.charset,
      type: type ?? this.type,
      group: group ?? this.group,
      latestChapterTitle: latestChapterTitle ?? this.latestChapterTitle,
      latestChapterTime: latestChapterTime ?? this.latestChapterTime,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      lastCheckCount: lastCheckCount ?? this.lastCheckCount,
      totalChapterNum: totalChapterNum ?? this.totalChapterNum,
      durChapterTitle: durChapterTitle ?? this.durChapterTitle,
      durChapterIndex: durChapterIndex ?? this.durChapterIndex,
      durChapterPos: durChapterPos ?? this.durChapterPos,
      durChapterTime: durChapterTime ?? this.durChapterTime,
      wordCount: wordCount ?? this.wordCount,
      canUpdate: canUpdate ?? this.canUpdate,
      order: order ?? this.order,
      originOrder: originOrder ?? this.originOrder,
      variable: variable ?? this.variable,
      syncTime: syncTime ?? this.syncTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookEntity && other.bookUrl == bookUrl;
  }

  @override
  int get hashCode => bookUrl.hashCode;
}
