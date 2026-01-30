import '../repositories/book_repository.dart';

/// 从书架删除书籍用例
///
/// 业务逻辑：
/// 1. 从本地数据库删除书籍
/// 2. 同时删除相关的章节缓存、阅读记录等
class RemoveBookFromShelfUseCase {
  final BookRepository bookRepository;

  RemoveBookFromShelfUseCase({
    required this.bookRepository,
  });

  /// 执行删除书籍
  ///
  /// @param bookUrl 书籍URL
  /// @return void
  Future<void> execute(String bookUrl) async {
    await bookRepository.deleteBook(bookUrl);
  }

  /// 批量删除书籍
  ///
  /// @param bookUrls 书籍URL列表
  /// @return 成功删除的数量
  Future<int> executeBatch(List<String> bookUrls) async {
    int successCount = 0;

    for (final bookUrl in bookUrls) {
      try {
        await execute(bookUrl);
        successCount++;
      } catch (e) {
        // 单本书籍删除失败不影响其他书籍
        continue;
      }
    }

    return successCount;
  }
}
