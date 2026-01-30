import 'package:json_annotation/json_annotation.dart';
import 'rss_article.dart';

/// RSS收藏数据模型
/// 参考项目：RssStar.kt
@JsonSerializable()
class RssStar {
  /// 来源（RSS源URL）
  @JsonKey(name: 'origin')
  final String origin;

  /// 链接（主键的一部分）
  @JsonKey(name: 'link')
  final String link;

  /// 分类
  @JsonKey(name: 'sort')
  String sort;

  /// 标题
  @JsonKey(name: 'title')
  String title;

  /// 收藏时间
  @JsonKey(name: 'starTime')
  int starTime;

  /// 发布日期
  @JsonKey(name: 'pubDate')
  String? pubDate;

  /// 描述
  @JsonKey(name: 'description')
  String? description;

  /// 正文内容
  @JsonKey(name: 'content')
  String? content;

  /// 图片URL
  @JsonKey(name: 'image')
  String? image;

  /// 分组
  @JsonKey(name: 'group')
  String group;

  /// 变量（JSON字符串）
  @JsonKey(name: 'variable')
  String? variable;

  RssStar({
    required this.origin,
    required this.link,
    this.sort = '',
    this.title = '',
    this.starTime = 0,
    this.pubDate,
    this.description,
    this.content,
    this.image,
    this.group = '默认分组',
    this.variable,
  });

  /// 从JSON创建
  factory RssStar.fromJson(Map<String, dynamic> json) {
    return RssStar(
      origin: json['origin'] as String? ?? '',
      link: json['link'] as String? ?? '',
      sort: json['sort'] as String? ?? '',
      title: json['title'] as String? ?? '',
      starTime: json['starTime'] as int? ?? 0,
      pubDate: json['pubDate'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      image: json['image'] as String?,
      group: json['group'] as String? ?? '默认分组',
      variable: json['variable'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'link': link,
      'sort': sort,
      'title': title,
      'starTime': starTime,
      'pubDate': pubDate,
      'description': description,
      'content': content,
      'image': image,
      'group': group,
      'variable': variable,
    };
  }

  /// 从RssArticle创建RssStar
  factory RssStar.fromRssArticle(RssArticle article, {String? group}) {
    return RssStar(
      origin: article.origin,
      link: article.link,
      sort: article.sort,
      title: article.title,
      starTime: DateTime.now().millisecondsSinceEpoch,
      pubDate: article.pubDate,
      description: article.description,
      content: article.content,
      image: article.image,
      group: group ?? article.group,
      variable: article.variable,
    );
  }

  /// 转换为RssArticle
  RssArticle toRssArticle() {
    return RssArticle(
      origin: origin,
      link: link,
      sort: sort,
      title: title,
      pubDate: pubDate,
      description: description,
      content: content,
      image: image,
      group: group,
      variable: variable,
    );
  }

  /// 复制
  RssStar copyWith({
    String? origin,
    String? link,
    String? sort,
    String? title,
    int? starTime,
    String? pubDate,
    String? description,
    String? content,
    String? image,
    String? group,
    String? variable,
  }) {
    return RssStar(
      origin: origin ?? this.origin,
      link: link ?? this.link,
      sort: sort ?? this.sort,
      title: title ?? this.title,
      starTime: starTime ?? this.starTime,
      pubDate: pubDate ?? this.pubDate,
      description: description ?? this.description,
      content: content ?? this.content,
      image: image ?? this.image,
      group: group ?? this.group,
      variable: variable ?? this.variable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RssStar && other.origin == origin && other.link == link;
  }

  @override
  int get hashCode => origin.hashCode ^ link.hashCode;
}

