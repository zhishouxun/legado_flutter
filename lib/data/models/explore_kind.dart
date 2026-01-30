/// 发现分类模型
class ExploreKind {
  final String title;
  final String? url;

  ExploreKind({
    required this.title,
    this.url,
  });

  factory ExploreKind.fromJson(Map<String, dynamic> json) {
    return ExploreKind(
      title: json['title'] ?? '',
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
    };
  }
}

