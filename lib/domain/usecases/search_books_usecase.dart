import '../entities/book_entity.dart';
import '../entities/book_source_entity.dart';
import '../repositories/book_repository.dart';
import '../repositories/book_source_repository.dart';

/// 搜索书籍用例
///
/// 业务逻辑：
/// 1. 获取启用的书源列表
/// 2. 使用这些书源进行并发搜索
/// 3. 实时返回搜索结果流
class SearchBooksUseCase {
  final BookRepository bookRepository;
  final BookSourceRepository bookSourceRepository;

  SearchBooksUseCase({
    required this.bookRepository,
    required this.bookSourceRepository,
  });

  /// 执行搜索
  ///
  /// @param keyword 搜索关键词
  /// @param sources 指定书源列表(可选,为空则使用所有启用的书源)
  /// @return 搜索结果流,每批书源搜索完成后推送一次结果
  Stream<List<BookEntity>> execute(
    String keyword, {
    List<BookSourceEntity>? sources,
  }) async* {
    // 如果没有指定书源,则获取所有启用的书源
    final effectiveSources =
        sources ?? await bookSourceRepository.getEnabledBookSources();

    if (effectiveSources.isEmpty) {
      yield [];
      return;
    }

    // 使用Repository的搜索方法
    yield* bookRepository.searchBooks(keyword, sources: effectiveSources);
  }

  /// 搜索并去重
  ///
  /// 根据书名和作者进行去重,保留第一个出现的结果
  Stream<List<BookEntity>> executeWithDeduplication(
    String keyword, {
    List<BookSourceEntity>? sources,
  }) async* {
    final seen = <String>{};

    await for (final books in execute(keyword, sources: sources)) {
      final deduplicated = <BookEntity>[];

      for (final book in books) {
        final key = '${book.name}_${book.author}';
        if (!seen.contains(key)) {
          seen.add(key);
          deduplicated.add(book);
        }
      }

      yield deduplicated;
    }
  }
}
