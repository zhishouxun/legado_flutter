import '../entities/chapter_entity.dart';
import '../entities/book_source_entity.dart';
import '../repositories/book_repository.dart';
import '../repositories/book_source_repository.dart';

/// 获取章节内容用例
///
/// 业务逻辑：
/// 1. 根据章节的书源获取对应的BookSource
/// 2. 使用书源获取章节内容
/// 3. 内容会自动缓存到本地
class GetChapterContentUseCase {
  final BookRepository bookRepository;
  final BookSourceRepository bookSourceRepository;

  GetChapterContentUseCase({
    required this.bookRepository,
    required this.bookSourceRepository,
  });

  /// 执行获取章节内容
  ///
  /// @param chapter 章节实体
  /// @param sourceUrl 书源URL
  /// @return 章节内容文本
  /// @throws Exception 当书源不存在或网络请求失败时
  Future<String> execute(
    ChapterEntity chapter,
    String sourceUrl,
  ) async {
    // 获取书源
    final source = await bookSourceRepository.getBookSourceByUrl(sourceUrl);
    if (source == null) {
      throw Exception('书源不存在: $sourceUrl');
    }

    // Repository会处理本地缓存逻辑
    final content = await bookRepository.getChapterContent(chapter, source);

    return content;
  }

  /// 批量预加载章节内容
  ///
  /// 用于预加载当前章节前后的章节,提升阅读体验
  ///
  /// @param chapters 章节列表
  /// @param sourceUrl 书源URL
  /// @return 成功预加载的章节数量
  Future<int> preloadChapters(
    List<ChapterEntity> chapters,
    String sourceUrl,
  ) async {
    int successCount = 0;

    for (final chapter in chapters) {
      try {
        await execute(chapter, sourceUrl);
        successCount++;
      } catch (e) {
        // 单个章节加载失败不影响其他章节
        continue;
      }
    }

    return successCount;
  }

  /// 预加载当前章节及后续章节
  ///
  /// @param currentChapter 当前章节
  /// @param allChapters 所有章节列表
  /// @param sourceUrl 书源URL
  /// @param preloadCount 预加载数量(默认3章)
  /// @return 成功预加载的章节数量
  Future<int> preloadNext(
    ChapterEntity currentChapter,
    List<ChapterEntity> allChapters,
    String sourceUrl, {
    int preloadCount = 3,
  }) async {
    // 找到当前章节的索引
    final currentIndex =
        allChapters.indexWhere((c) => c.url == currentChapter.url);
    if (currentIndex == -1) return 0;

    // 获取后续章节
    final nextChapters =
        allChapters.skip(currentIndex + 1).take(preloadCount).toList();

    return await preloadChapters(nextChapters, sourceUrl);
  }
}
