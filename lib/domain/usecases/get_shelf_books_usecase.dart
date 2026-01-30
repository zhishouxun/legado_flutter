import '../entities/book_entity.dart';
import '../repositories/book_repository.dart';

/// 获取书架书籍用例
///
/// 业务逻辑：
/// 1. 从本地数据库获取书架中的所有书籍
/// 2. 可选：按分组过滤
/// 3. 可选：按指定规则排序
class GetShelfBooksUseCase {
  final BookRepository bookRepository;

  GetShelfBooksUseCase({
    required this.bookRepository,
  });

  /// 执行获取书架书籍
  ///
  /// @return 书架书籍列表
  Future<List<BookEntity>> execute() async {
    return await bookRepository.getShelfBooks();
  }

  /// 根据分组获取书籍
  ///
  /// @param groupId 分组ID
  /// @return 书籍列表
  Future<List<BookEntity>> executeByGroup(int groupId) async {
    return await bookRepository.getBooksByGroup(groupId);
  }

  /// 获取最近阅读的书籍
  ///
  /// @param limit 数量限制
  /// @return 按最后阅读时间降序排列的书籍列表
  Future<List<BookEntity>> executeRecentlyRead({int limit = 10}) async {
    final allBooks = await execute();

    // 按最后阅读时间排序
    final sorted = List<BookEntity>.from(allBooks)
      ..sort((a, b) => b.durChapterTime.compareTo(a.durChapterTime));

    return sorted.take(limit).toList();
  }

  /// 获取最近更新的书籍
  ///
  /// @param limit 数量限制
  /// @return 按更新时间降序排列的书籍列表
  Future<List<BookEntity>> executeRecentlyUpdated({int limit = 10}) async {
    final allBooks = await execute();

    // 按更新时间排序
    final sorted = List<BookEntity>.from(allBooks)
      ..sort((a, b) => b.latestChapterTime.compareTo(a.latestChapterTime));

    return sorted.take(limit).toList();
  }
}
