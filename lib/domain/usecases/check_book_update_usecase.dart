import '../entities/book_entity.dart';
import '../entities/book_source_entity.dart';
import '../repositories/book_repository.dart';
import '../repositories/book_source_repository.dart';

/// 检查书籍更新用例
///
/// 业务逻辑：
/// 1. 获取书籍对应的书源
/// 2. 检查书源上是否有新章节
/// 3. 返回新章节数量
class CheckBookUpdateUseCase {
  final BookRepository bookRepository;
  final BookSourceRepository bookSourceRepository;

  CheckBookUpdateUseCase({
    required this.bookRepository,
    required this.bookSourceRepository,
  });

  /// 检查单本书籍更新
  ///
  /// @param book 书籍实体
  /// @return 新章节数量
  Future<int> execute(BookEntity book) async {
    // 获取书源
    final source = await bookSourceRepository.getBookSourceByUrl(book.origin);
    if (source == null) {
      return 0;
    }

    // 检查更新
    return await bookRepository.checkBookUpdate(book, source);
  }

  /// 检查书架所有书籍更新
  ///
  /// @return Map<书籍URL, 新章节数量>
  Future<Map<String, int>> executeAll() async {
    return await bookRepository.checkShelfBooksUpdate();
  }

  /// 检查指定书籍列表的更新
  ///
  /// @param books 书籍列表
  /// @return Map<书籍URL, 新章节数量>
  Future<Map<String, int>> executeBatch(List<BookEntity> books) async {
    final updates = <String, int>{};

    for (final book in books) {
      try {
        final newCount = await execute(book);
        updates[book.bookUrl] = newCount;
      } catch (e) {
        // 单本书籍检查失败不影响其他书籍
        updates[book.bookUrl] = 0;
      }
    }

    return updates;
  }
}
