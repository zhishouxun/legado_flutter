/// 页面范围模型 (参考Gemini文档)
/// 表示一页在章节内容中的字符索引范围
class PageRange {
  /// 字符起始索引(包含)
  final int start;

  /// 字符结束索引(不包含)
  final int end;

  /// 页面索引
  final int pageIndex;

  /// 页面高度(用于渲染)
  final double height;

  const PageRange({
    required this.start,
    required this.end,
    required this.pageIndex,
    this.height = 0.0,
  });

  /// 字符数量
  int get charCount => end - start;

  /// 判断字符索引是否在此页面范围内
  bool contains(int charIndex) {
    return charIndex >= start && charIndex < end;
  }

  /// 获取页面内容
  String getContent(String fullContent) {
    if (start < 0 || end > fullContent.length) {
      return '';
    }
    return fullContent.substring(start, end);
  }

  /// 复制并修改部分字段
  PageRange copyWith({
    int? start,
    int? end,
    int? pageIndex,
    double? height,
  }) {
    return PageRange(
      start: start ?? this.start,
      end: end ?? this.end,
      pageIndex: pageIndex ?? this.pageIndex,
      height: height ?? this.height,
    );
  }

  @override
  String toString() {
    return 'PageRange(start: $start, end: $end, pageIndex: $pageIndex, charCount: $charCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PageRange &&
        other.start == start &&
        other.end == end &&
        other.pageIndex == pageIndex;
  }

  @override
  int get hashCode => Object.hash(start, end, pageIndex);
}
