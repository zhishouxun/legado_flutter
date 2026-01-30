/// 搜索关键词数据模型
/// 参考项目：io.legado.app.data.entities.SearchKeyword
class SearchKeyword {
  /// 搜索关键词（主键）
  final String word;

  /// 使用次数
  int usage;

  /// 最后一次使用时间
  int lastUseTime;

  SearchKeyword({
    required this.word,
    this.usage = 1,
    int? lastUseTime,
  }) : lastUseTime = lastUseTime ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory SearchKeyword.fromJson(Map<String, dynamic> json) {
    return SearchKeyword(
      word: json['word'] as String? ?? '',
      usage: json['usage'] as int? ?? 1,
      lastUseTime: json['lastUseTime'] as int?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'usage': usage,
      'lastUseTime': lastUseTime,
    };
  }

  /// 复制
  SearchKeyword copyWith({
    String? word,
    int? usage,
    int? lastUseTime,
  }) {
    return SearchKeyword(
      word: word ?? this.word,
      usage: usage ?? this.usage,
      lastUseTime: lastUseTime ?? this.lastUseTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchKeyword && other.word == word;
  }

  @override
  int get hashCode => word.hashCode;
}

