import '../../data/models/book.dart';
import '../../utils/app_log.dart';

/// 阅读器控制器
/// 用于全局控制阅读器状态（章节切换等）
/// 参考项目：ReadBook.moveToPrevChapter / ReadBook.moveToNextChapter
class ReaderController {
  static final ReaderController instance = ReaderController._init();
  ReaderController._init();

  /// 当前阅读的书籍
  Book? _currentBook;
  
  /// 章节切换回调
  Function(String bookUrl, bool isNext)? onChapterChanged;
  
  /// 设置当前阅读的书籍
  void setCurrentBook(Book? book) {
    _currentBook = book;
    if (book != null) {
      AppLog.instance.put('设置当前阅读书籍: ${book.name}');
    }
  }
  
  /// 获取当前阅读的书籍
  Book? getCurrentBook() => _currentBook;
  
  /// 切换到上一章
  /// 参考项目：ReadBook.moveToPrevChapter()
  Future<bool> moveToPrevChapter() async {
    if (_currentBook == null) {
      AppLog.instance.put('没有当前阅读的书籍，无法切换章节');
      return false;
    }
    
    try {
      if (onChapterChanged != null) {
        onChapterChanged!(_currentBook!.bookUrl, false);
        AppLog.instance.put('切换到上一章: ${_currentBook!.name}');
        return true;
      } else {
        AppLog.instance.put('章节切换回调未设置');
        return false;
      }
    } catch (e) {
      AppLog.instance.put('切换上一章失败: $e', error: e);
      return false;
    }
  }
  
  /// 切换到下一章
  /// 参考项目：ReadBook.moveToNextChapter()
  Future<bool> moveToNextChapter() async {
    if (_currentBook == null) {
      AppLog.instance.put('没有当前阅读的书籍，无法切换章节');
      return false;
    }
    
    try {
      if (onChapterChanged != null) {
        onChapterChanged!(_currentBook!.bookUrl, true);
        AppLog.instance.put('切换到下一章: ${_currentBook!.name}');
        return true;
      } else {
        AppLog.instance.put('章节切换回调未设置');
        return false;
      }
    } catch (e) {
      AppLog.instance.put('切换下一章失败: $e', error: e);
      return false;
    }
  }
  
  /// 清除当前阅读的书籍
  void clearCurrentBook() {
    _currentBook = null;
    AppLog.instance.put('清除当前阅读书籍');
  }
}

