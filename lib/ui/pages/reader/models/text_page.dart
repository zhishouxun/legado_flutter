/// 文本页面类（参考项目：TextPage.kt）
/// 表示章节中的一个页面
class TextPage {
  int index = 0;
  String text = '';
  String title = '';
  int chapterIndex = 0;
  int chapterSize = 0;
  
  /// 页面在章节中的字符位置（起始位置）
  int chapterPosition = 0;
  
  /// 页面字符数量
  int get charSize => text.length;
  
  /// 页面高度
  double height = 0.0;
  
  /// 是否已完成排版
  bool isCompleted = false;
  
  /// 是否是消息页面（错误提示等）
  bool isMsgPage = false;
  
  /// 搜索结果显示（字符索引列表）
  final Set<int> _searchResult = {};
  Set<int> get searchResult => _searchResult;
  
  TextPage({
    this.index = 0,
    this.text = '',
    this.title = '',
    this.chapterIndex = 0,
    this.chapterSize = 0,
    this.chapterPosition = 0,
    this.height = 0.0,
    this.isCompleted = false,
    this.isMsgPage = false,
  });

  /// 判断指定字符位置是否在本页中
  bool containPos(int chapterPos) {
    final startPos = chapterPosition;
    final endPos = startPos + charSize;
    return chapterPos >= startPos && chapterPos < endPos;
  }

  /// 添加搜索结果
  void addSearchResult(int charIndex) {
    _searchResult.add(charIndex);
  }

  /// 清除搜索结果
  void clearSearchResult() {
    _searchResult.clear();
  }

  /// 判断是否有搜索结果
  bool hasSearchResult() {
    return _searchResult.isNotEmpty;
  }
}

