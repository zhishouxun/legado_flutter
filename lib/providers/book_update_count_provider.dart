import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/book/book_service.dart';

/// 书籍更新数量Provider
/// 计算所有书籍的未读章节总数
class BookUpdateCountNotifier extends Notifier<int> {
  @override
  int build() {
    _loadUpdateCount();
    return 0;
  }

  /// 加载更新数量
  Future<void> _loadUpdateCount() async {
    try {
      final books = await BookService.instance.getBookshelfBooks();
      int totalCount = 0;
      
      for (final book in books) {
        // 计算未读章节数：总章节数 - 当前章节索引 - 1
        // 如果 totalChapterNum 为 0 或 durChapterIndex 无效，则使用 lastCheckCount
        if (book.totalChapterNum > 0 && book.durChapterIndex >= 0) {
          final unreadCount = book.totalChapterNum - book.durChapterIndex - 1;
          if (unreadCount > 0) {
            totalCount += unreadCount;
          }
        } else if (book.lastCheckCount > 0) {
          // 如果无法计算未读章节数，使用 lastCheckCount
          totalCount += book.lastCheckCount;
        }
      }
      
      state = totalCount;
    } catch (e) {
      // 如果加载失败，保持当前状态
      state = 0;
    }
  }

  /// 刷新更新数量
  Future<void> refresh() async {
    await _loadUpdateCount();
  }
}

/// 书籍更新数量Provider
final bookUpdateCountProvider = NotifierProvider<BookUpdateCountNotifier, int>(() {
  return BookUpdateCountNotifier();
});

