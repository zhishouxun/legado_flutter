/// 章节评论实体
/// 参考项目：io.legado.app.data.entities.BookChapterReview
class BookChapterReview {
  /// 书籍ID
  final int bookId;

  /// 章节ID
  final int chapterId;

  /// 评论摘要URL
  final String summaryUrl;

  BookChapterReview({
    required this.bookId,
    required this.chapterId,
    required this.summaryUrl,
  });

  /// 从JSON创建
  factory BookChapterReview.fromJson(Map<String, dynamic> json) {
    return BookChapterReview(
      bookId: json['bookId'] as int? ?? 0,
      chapterId: json['chapterId'] as int? ?? 0,
      summaryUrl: json['summaryUrl'] as String? ?? '',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'chapterId': chapterId,
      'summaryUrl': summaryUrl,
    };
  }

  /// 从数据库Map创建
  factory BookChapterReview.fromMap(Map<String, dynamic> map) {
    return BookChapterReview(
      bookId: map['bookId'] as int? ?? 0,
      chapterId: map['chapterId'] as int? ?? 0,
      summaryUrl: map['summaryUrl'] as String? ?? '',
    );
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'chapterId': chapterId,
      'summaryUrl': summaryUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookChapterReview &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId &&
          chapterId == other.chapterId;

  @override
  int get hashCode => bookId.hashCode ^ chapterId.hashCode;

  @override
  String toString() {
    return 'BookChapterReview{bookId: $bookId, chapterId: $chapterId, summaryUrl: $summaryUrl}';
  }
}

