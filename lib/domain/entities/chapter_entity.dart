/// Domain层的章节实体 - 纯净的业务对象，不依赖任何第三方库
/// 参考：Clean Architecture - Entity Layer
class ChapterEntity {
  final String url; // 章节地址
  final String bookUrl; // 所属书籍URL
  final String title; // 章节标题
  final bool isVolume; // 是否是卷名
  final String baseUrl; // 用来拼接相对URL
  final int index; // 章节序号
  final bool isVip; // 是否VIP
  final bool isPay; // 是否已购买
  final String? resourceUrl; // 音频真实URL
  final String? tag; // 更新时间或其他附加信息
  final String? wordCount; // 本章节字数
  final int? start; // 章节起始位置
  final int? end; // 章节终止位置
  final String? startFragmentId; // EPUB书籍当前章节fragmentId
  final String? endFragmentId; // EPUB书籍下一章节fragmentId
  final String? variable; // 变量

  const ChapterEntity({
    required this.url,
    required this.bookUrl,
    required this.title,
    required this.isVolume,
    required this.baseUrl,
    required this.index,
    required this.isVip,
    required this.isPay,
    this.resourceUrl,
    this.tag,
    this.wordCount,
    this.start,
    this.end,
    this.startFragmentId,
    this.endFragmentId,
    this.variable,
  });

  /// 获取章节的唯一标识符
  String get primaryKey => bookUrl + url;

  /// 复制并修改部分字段
  ChapterEntity copyWith({
    String? url,
    String? bookUrl,
    String? title,
    bool? isVolume,
    String? baseUrl,
    int? index,
    bool? isVip,
    bool? isPay,
    String? resourceUrl,
    String? tag,
    String? wordCount,
    int? start,
    int? end,
    String? startFragmentId,
    String? endFragmentId,
    String? variable,
  }) {
    return ChapterEntity(
      url: url ?? this.url,
      bookUrl: bookUrl ?? this.bookUrl,
      title: title ?? this.title,
      isVolume: isVolume ?? this.isVolume,
      baseUrl: baseUrl ?? this.baseUrl,
      index: index ?? this.index,
      isVip: isVip ?? this.isVip,
      isPay: isPay ?? this.isPay,
      resourceUrl: resourceUrl ?? this.resourceUrl,
      tag: tag ?? this.tag,
      wordCount: wordCount ?? this.wordCount,
      start: start ?? this.start,
      end: end ?? this.end,
      startFragmentId: startFragmentId ?? this.startFragmentId,
      endFragmentId: endFragmentId ?? this.endFragmentId,
      variable: variable ?? this.variable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChapterEntity &&
        other.url == url &&
        other.bookUrl == bookUrl;
  }

  @override
  int get hashCode => url.hashCode ^ bookUrl.hashCode;
}
