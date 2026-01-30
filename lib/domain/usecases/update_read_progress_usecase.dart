import '../repositories/book_repository.dart';

/// 更新阅读进度用例
///
/// 业务逻辑：
/// 1. 更新书籍的当前章节索引
/// 2. 更新书籍的阅读位置
/// 3. 更新最后阅读时间
class UpdateReadProgressUseCase {
  final BookRepository bookRepository;

  UpdateReadProgressUseCase({
    required this.bookRepository,
  });

  /// 执行更新阅读进度
  ///
  /// @param bookUrl 书籍URL
  /// @param chapterIndex 章节索引
  /// @param chapterPos 章节内阅读位置
  /// @return void
  Future<void> execute(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
  ) async {
    await bookRepository.updateReadProgress(
      bookUrl,
      chapterIndex,
      chapterPos,
    );
  }

  /// 更新进度到下一章
  ///
  /// @param bookUrl 书籍URL
  /// @param currentChapterIndex 当前章节索引
  /// @return void
  Future<void> moveToNextChapter(
    String bookUrl,
    int currentChapterIndex,
  ) async {
    await execute(bookUrl, currentChapterIndex + 1, 0);
  }

  /// 更新进度到上一章
  ///
  /// @param bookUrl 书籍URL
  /// @param currentChapterIndex 当前章节索引
  /// @return void
  Future<void> moveToPreviousChapter(
    String bookUrl,
    int currentChapterIndex,
  ) async {
    if (currentChapterIndex > 0) {
      await execute(bookUrl, currentChapterIndex - 1, 0);
    }
  }

  /// 更新进度到指定章节开头
  ///
  /// @param bookUrl 书籍URL
  /// @param chapterIndex 章节索引
  /// @return void
  Future<void> moveToChapter(
    String bookUrl,
    int chapterIndex,
  ) async {
    await execute(bookUrl, chapterIndex, 0);
  }
}
