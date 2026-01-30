import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/book.dart';
import '../data/models/book_chapter.dart';
import '../data/models/book_group.dart';
import '../services/book/book_service.dart';
import '../services/book_group_service.dart';

/// 书架书籍列表Provider
final bookshelfBooksProvider = FutureProvider<List<Book>>((ref) async {
  final service = BookService.instance;
  return await service.getBookshelfBooks();
});

/// 书籍搜索Provider
final bookSearchProvider = FutureProvider.family<List<Book>, String>((ref, keyword) async {
  final service = BookService.instance;
  return await service.searchBooks(keyword);
});

/// 书籍详情Provider
final bookInfoProvider = FutureProvider.family<Book?, Book>((ref, book) async {
  final service = BookService.instance;
  return await service.getBookInfo(book);
});

/// 章节列表Provider
final chapterListProvider = FutureProvider.family<List<BookChapter>, Book>((ref, book) async {
  final service = BookService.instance;
  return await service.getChapterList(book);
});

/// 刷新书架列表的Provider
final refreshBookshelfProvider = FutureProvider.family<List<Book>, void>((ref, _) async {
  final service = BookService.instance;
  return await service.getBookshelfBooks();
});

/// 书籍分组列表Provider
final bookGroupsProvider = FutureProvider<List<BookGroup>>((ref) async {
  final service = BookGroupService.instance;
  // 确保服务已初始化
  if (!service.isInitialized) {
    await service.init();
  }
  // 初始化默认分组
  await service.initDefaultGroups();
  return await service.getAllGroups(showOnly: true);
});

/// 根据分组获取书籍的Provider
final booksByGroupProvider = FutureProvider.family<List<Book>, int>((ref, groupId) async {
  final service = BookService.instance;
  if (groupId == BookGroup.idAll) {
    return await service.getBookshelfBooks();
  }
  return await service.getBooksByGroup(groupId);
});

/// 书籍操作Provider
final bookOperationsProvider = Provider((ref) => BookOperations());

/// 书籍操作类
class BookOperations {
  final BookService _service = BookService.instance;

  /// 添加书籍到书架
  Future<void> addBook(Book book, WidgetRef ref) async {
    await _service.saveBook(book);
    ref.invalidate(refreshBookshelfProvider);
  }

  /// 从书架删除书籍
  Future<void> removeBook(String bookUrl, WidgetRef ref) async {
    await _service.deleteBook(bookUrl);
    ref.invalidate(refreshBookshelfProvider);
  }

  /// 更新阅读进度
  Future<void> updateProgress(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
    String? chapterTitle,
    WidgetRef ref,
  ) async {
    await _service.updateReadingProgress(bookUrl, chapterIndex, chapterPos, chapterTitle);
    ref.invalidate(refreshBookshelfProvider);
  }
}

