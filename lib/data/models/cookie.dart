/// Cookie数据模型
/// 参考项目：io.legado.app.data.entities.Cookie
class Cookie {
  /// URL（主键）
  final String url;

  /// Cookie字符串
  String cookie;

  Cookie({
    required this.url,
    this.cookie = '',
  });

  /// 从JSON创建
  factory Cookie.fromJson(Map<String, dynamic> json) {
    return Cookie(
      url: json['url'] as String? ?? '',
      cookie: json['cookie'] as String? ?? '',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'cookie': cookie,
    };
  }

  /// 复制
  Cookie copyWith({
    String? url,
    String? cookie,
  }) {
    return Cookie(
      url: url ?? this.url,
      cookie: cookie ?? this.cookie,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cookie && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

