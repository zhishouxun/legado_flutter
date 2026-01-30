import '../entities/book_entity.dart';
import '../repositories/book_repository.dart';

/// 添加书籍到书架用例
///
/// 业务逻辑：
/// 1. 保存书籍到本地数据库
/// 2. 设置书籍为"在书架"状态
/// 3. 可选：设置分组
class AddBookToShelfUseCase {
  final BookRepository bookRepository;

  AddBookToShelfUseCase({
    required this.bookRepository,
  });

  /// 执行添加书籍到书架
  ///
  /// @param book 书籍实体
  /// @param groupId 分组ID(可选)
  /// @return void
  Future<void> execute(
    BookEntity book, {
    int? groupId,
  }) async {
    // 设置书籍为在书架状态
    var bookToSave = book.copyWith(group: groupId ?? 1);

    // 保存到数据库
    await bookRepository.saveBook(bookToSave);
  }

  /// 批量添加书籍到书架
  ///
  /// @param books 书籍列表
  /// @param groupId 分组ID(可选)
  /// @return 成功添加的数量
  Future<int> executeBatch(
    List<BookEntity> books, {
    int? groupId,
  }) async {
    int successCount = 0;

    for (final book in books) {
      try {
        await execute(book, groupId: groupId);
        successCount++;
      } catch (e) {
        // 单本书籍添加失败不影响其他书籍
        continue;
      }
    }

    return successCount;
  }
}
