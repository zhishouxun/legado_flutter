import '../entities/book_entity.dart';
import '../entities/book_source_entity.dart';
import '../repositories/book_repository.dart';
import '../repositories/book_source_repository.dart';

/// 获取书籍详情用例
///
/// 业务逻辑：
/// 1. 根据书籍的origin获取对应的书源
/// 2. 使用书源获取书籍的详细信息
/// 3. 可选：更新本地数据库中的书籍信息
class GetBookInfoUseCase {
  final BookRepository bookRepository;
  final BookSourceRepository bookSourceRepository;

  GetBookInfoUseCase({
    required this.bookRepository,
    required this.bookSourceRepository,
  });

  /// 执行获取书籍详情
  ///
  /// @param book 书籍实体
  /// @param saveToLocal 是否保存到本地数据库(默认false)
  /// @return 更新后的书籍实体
  /// @throws Exception 当书源不存在或网络请求失败时
  Future<BookEntity> execute(
    BookEntity book, {
    bool saveToLocal = false,
  }) async {
    // 获取书源
    final source = await bookSourceRepository.getBookSourceByUrl(book.origin);
    if (source == null) {
      throw Exception('书源不存在: ${book.origin}');
    }

    // 获取书籍详情
    final updatedBook = await bookRepository.getBookInfo(book, source);

    // 保存到本地
    if (saveToLocal) {
      await bookRepository.updateBook(updatedBook);
    }

    return updatedBook;
  }

  /// 批量获取书籍详情
  ///
  /// @param books 书籍列表
  /// @param saveToLocal 是否保存到本地
  /// @return 更新后的书籍列表
  Future<List<BookEntity>> executeBatch(
    List<BookEntity> books, {
    bool saveToLocal = false,
  }) async {
    final results = <BookEntity>[];

    for (final book in books) {
      try {
        final updated = await execute(book, saveToLocal: saveToLocal);
        results.add(updated);
      } catch (e) {
        // 单本书籍获取失败不影响其他书籍
        results.add(book);
      }
    }

    return results;
  }
}
