import 'package:legado_flutter/data/models/book.dart';

/// 搜索结果书籍数据模型
/// 参考项目：io.legado.app.data.entities.SearchBook
class SearchBook {
  /// 书籍URL（主键）
  final String bookUrl;

  /// 书源URL
  String origin;

  /// 书源名称
  String originName;

  /// 书籍类型
  int type;

  /// 书籍名称
  String name;

  /// 作者名称
  String author;

  /// 分类信息
  String? kind;

  /// 封面URL
  String? coverUrl;

  /// 简介
  String? intro;

  /// 字数
  String? wordCount;

  /// 最新章节标题
  String? latestChapterTitle;

  /// 目录页URL
  String tocUrl;

  /// 搜索时间
  int time;

  /// 变量（JSON字符串）
  String? variable;

  /// 原始排序
  int originOrder;

  /// 章节字数文本
  String? chapterWordCountText;

  /// 章节字数
  int chapterWordCount;

  /// 响应时间
  int respondTime;

  SearchBook({
    required this.bookUrl,
    this.origin = '',
    this.originName = '',
    this.type = 0,
    this.name = '',
    this.author = '',
    this.kind,
    this.coverUrl,
    this.intro,
    this.wordCount,
    this.latestChapterTitle,
    this.tocUrl = '',
    int? time,
    this.variable,
    this.originOrder = 0,
    this.chapterWordCountText,
    this.chapterWordCount = -1,
    this.respondTime = -1,
  }) : time = time ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory SearchBook.fromJson(Map<String, dynamic> json) {
    return SearchBook(
      bookUrl: json['bookUrl'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      originName: json['originName'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      kind: json['kind'] as String?,
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      wordCount: json['wordCount'] as String?,
      latestChapterTitle: json['latestChapterTitle'] as String?,
      tocUrl: json['tocUrl'] as String? ?? '',
      time: json['time'] as int?,
      variable: json['variable'] as String?,
      originOrder: json['originOrder'] as int? ?? 0,
      chapterWordCountText: json['chapterWordCountText'] as String?,
      chapterWordCount: json['chapterWordCount'] as int? ?? -1,
      respondTime: json['respondTime'] as int? ?? -1,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'bookUrl': bookUrl,
      'origin': origin,
      'originName': originName,
      'type': type,
      'name': name,
      'author': author,
      'kind': kind,
      'coverUrl': coverUrl,
      'intro': intro,
      'wordCount': wordCount,
      'latestChapterTitle': latestChapterTitle,
      'tocUrl': tocUrl,
      'time': time,
      'variable': variable,
      'originOrder': originOrder,
      'chapterWordCountText': chapterWordCountText,
      'chapterWordCount': chapterWordCount,
      'respondTime': respondTime,
    };
  }

  /// 转换为Book对象
  Book toBook() {
    return Book(
      bookUrl: bookUrl,
      tocUrl: tocUrl,
      origin: origin,
      originName: originName,
      name: name,
      author: author,
      kind: kind,
      coverUrl: coverUrl,
      intro: intro,
      type: type,
      wordCount: wordCount,
      latestChapterTitle: latestChapterTitle,
      variable: variable,
      originOrder: originOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchBook && other.bookUrl == bookUrl;
  }

  @override
  int get hashCode => bookUrl.hashCode;
}

