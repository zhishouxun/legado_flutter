import 'package:json_annotation/json_annotation.dart';

/// RSS文章数据模型
@JsonSerializable()
class RssArticle {
  /// 来源（RSS源URL）
  @JsonKey(name: 'origin')
  final String origin;

  /// 分类
  @JsonKey(name: 'sort')
  String sort;

  /// 标题
  @JsonKey(name: 'title')
  String title;

  /// 排序值
  @JsonKey(name: 'order')
  int order;

  /// 链接（主键的一部分）
  @JsonKey(name: 'link')
  final String link;

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

  /// 是否已读
  @JsonKey(name: 'read')
  bool read;

  /// 变量（JSON字符串）
  @JsonKey(name: 'variable')
  String? variable;

  RssArticle({
    required this.origin,
    required this.link,
    this.sort = '',
    this.title = '',
    this.order = 0,
    this.pubDate,
    this.description,
    this.content,
    this.image,
    this.group = '默认分组',
    this.read = false,
    this.variable,
  });

  /// 从JSON创建
  factory RssArticle.fromJson(Map<String, dynamic> json) {
    return RssArticle(
      origin: json['origin'] as String? ?? '',
      link: json['link'] as String? ?? '',
      sort: json['sort'] as String? ?? '',
      title: json['title'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      pubDate: json['pubDate'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      image: json['image'] as String?,
      group: json['group'] as String? ?? '默认分组',
      read: json['read'] == true || json['read'] == 1,
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
      'order': order,
      'pubDate': pubDate,
      'description': description,
      'content': content,
      'image': image,
      'group': group,
      'read': read ? 1 : 0,
      'variable': variable,
    };
  }

  /// 复制
  RssArticle copyWith({
    String? origin,
    String? link,
    String? sort,
    String? title,
    int? order,
    String? pubDate,
    String? description,
    String? content,
    String? image,
    String? group,
    bool? read,
    String? variable,
  }) {
    return RssArticle(
      origin: origin ?? this.origin,
      link: link ?? this.link,
      sort: sort ?? this.sort,
      title: title ?? this.title,
      order: order ?? this.order,
      pubDate: pubDate ?? this.pubDate,
      description: description ?? this.description,
      content: content ?? this.content,
      image: image ?? this.image,
      group: group ?? this.group,
      read: read ?? this.read,
      variable: variable ?? this.variable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RssArticle && other.origin == origin && other.link == link;
  }

  @override
  int get hashCode => origin.hashCode ^ link.hashCode;
}

