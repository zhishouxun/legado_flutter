import '../entities/book_entity.dart';
import '../entities/chapter_entity.dart';
import '../entities/book_source_entity.dart';
import '../repositories/book_repository.dart';
import '../repositories/book_source_repository.dart';

/// 获取章节列表用例
///
/// 业务逻辑：
/// 1. 根据书籍的origin获取对应的书源
/// 2. 使用书源获取章节列表
/// 3. 章节列表会自动缓存到本地
class GetChapterListUseCase {
  final BookRepository bookRepository;
  final BookSourceRepository bookSourceRepository;

  GetChapterListUseCase({
    required this.bookRepository,
    required this.bookSourceRepository,
  });

  /// 执行获取章节列表
  ///
  /// @param book 书籍实体
  /// @param forceRefresh 是否强制刷新(跳过本地缓存)
  /// @return 章节列表
  /// @throws Exception 当书源不存在或网络请求失败时
  Future<List<ChapterEntity>> execute(
    BookEntity book, {
    bool forceRefresh = false,
  }) async {
    // 获取书源
    final source = await bookSourceRepository.getBookSourceByUrl(book.origin);
    if (source == null) {
      throw Exception('书源不存在: ${book.origin}');
    }

    // Repository会处理本地缓存逻辑
    // 如果需要强制刷新,可以先清空本地缓存(TODO: 添加清空缓存方法)
    final chapters = await bookRepository.getChapterList(book, source);

    return chapters;
  }

  /// 获取指定范围的章节
  ///
  /// @param book 书籍实体
  /// @param startIndex 起始索引(包含)
  /// @param endIndex 结束索引(包含)
  /// @return 章节列表
  Future<List<ChapterEntity>> executeRange(
    BookEntity book,
    int startIndex,
    int endIndex,
  ) async {
    final allChapters = await execute(book);

    if (startIndex < 0 ||
        endIndex >= allChapters.length ||
        startIndex > endIndex) {
      return [];
    }

    return allChapters.sublist(startIndex, endIndex + 1);
  }

  /// 获取当前阅读章节及前后若干章节
  ///
  /// @param book 书籍实体
  /// @param currentIndex 当前章节索引
  /// @param beforeCount 前面章节数量
  /// @param afterCount 后面章节数量
  /// @return 章节列表
  Future<List<ChapterEntity>> executeAround(
    BookEntity book,
    int currentIndex, {
    int beforeCount = 1,
    int afterCount = 2,
  }) async {
    final allChapters = await execute(book);

    final start = (currentIndex - beforeCount).clamp(0, allChapters.length - 1);
    final end = (currentIndex + afterCount).clamp(0, allChapters.length - 1);

    return allChapters.sublist(start, end + 1);
  }
}
