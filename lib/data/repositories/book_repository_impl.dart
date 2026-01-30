import '../../domain/entities/book_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/book_source_entity.dart';
import '../../domain/repositories/book_repository.dart';
import '../datasources/book_local_datasource.dart';
import '../datasources/book_remote_datasource.dart';
import '../mappers/entity_mapper.dart';
import '../models/search_book.dart';

/// BookRepository 的实现类
/// 参考：Clean Architecture - Repository Implementation
class BookRepositoryImpl implements BookRepository {
  final BookLocalDataSource localDataSource;
  final BookRemoteDataSource remoteDataSource;

  BookRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<BookEntity?> getBookByUrl(String bookUrl) async {
    final model = await localDataSource.getBookByUrl(bookUrl);
    return model != null ? EntityMapper.bookToEntity(model) : null;
  }

  @override
  Future<List<BookEntity>> getAllBooks() async {
    final models = await localDataSource.getAllBooks();
    return EntityMapper.booksToEntities(models);
  }

  @override
  Future<List<BookEntity>> getShelfBooks() async {
    final models = await localDataSource.getShelfBooks();
    return EntityMapper.booksToEntities(models);
  }

  @override
  Future<List<BookEntity>> getBooksByGroup(int groupId) async {
    final models = await localDataSource.getBooksByGroup(groupId);
    return EntityMapper.booksToEntities(models);
  }

  @override
  Stream<List<BookEntity>> searchBooks(
    String keyword, {
    List<BookSourceEntity>? sources,
  }) async* {
    // 如果未指定书源,需要从本地数据源获取启用的书源
    // 这里简化处理,实际应该注入BookSourceRepository
    if (sources == null || sources.isEmpty) {
      yield [];
      return;
    }

    // 批量搜索,每批10个书源
    const batchSize = 10;
    final allResults = <BookEntity>[];

    for (var i = 0; i < sources.length; i += batchSize) {
      final batch = sources.skip(i).take(batchSize).toList();

      // 并发搜索当前批次的所有书源
      final futures = batch.map((sourceEntity) async {
        try {
          final sourceModel = EntityMapper.bookSourceFromEntity(sourceEntity);
          final searchStream =
              remoteDataSource.searchBooks(keyword, sourceModel);

          final results = <BookEntity>[];
          await for (final searchBook in searchStream) {
            // SearchBook 转为 Book Entity
            results.add(_searchBookToEntity(searchBook, sourceEntity));
          }
          return results;
        } catch (e) {
          // 单个书源搜索失败不影响其他书源
          return <BookEntity>[];
        }
      });

      // 等待当前批次完成
      final batchResults = await Future.wait(futures);

      // 合并结果
      for (final results in batchResults) {
        allResults.addAll(results);
      }

      // 每批搜索完成后立即返回结果
      if (allResults.isNotEmpty) {
        yield List.from(allResults);
      }
    }

    // 最后返回完整结果
    yield allResults;
  }

  @override
  Future<BookEntity> getBookInfo(
      BookEntity book, BookSourceEntity source) async {
    final bookModel = EntityMapper.bookFromEntity(book);
    final sourceModel = EntityMapper.bookSourceFromEntity(source);

    final updatedBook =
        await remoteDataSource.getBookInfo(bookModel, sourceModel);
    return EntityMapper.bookToEntity(updatedBook);
  }

  @override
  Future<List<ChapterEntity>> getChapterList(
    BookEntity book,
    BookSourceEntity source,
  ) async {
    // 先尝试从本地获取
    final localChapters = await localDataSource.getChapterList(book.bookUrl);
    if (localChapters.isNotEmpty) {
      return EntityMapper.chaptersToEntities(localChapters);
    }

    // 本地没有则从远程获取
    final bookModel = EntityMapper.bookFromEntity(book);
    final sourceModel = EntityMapper.bookSourceFromEntity(source);

    final chapters =
        await remoteDataSource.getChapterList(bookModel, sourceModel);

    // 保存到本地
    if (chapters.isNotEmpty) {
      await localDataSource.saveChapters(chapters);
    }

    return EntityMapper.chaptersToEntities(chapters);
  }

  @override
  Future<String> getChapterContent(
    ChapterEntity chapter,
    BookSourceEntity source,
  ) async {
    // 先尝试从本地缓存获取
    final cachedContent = await localDataSource.getChapterContent(
      chapter.bookUrl,
      chapter.url,
    );
    if (cachedContent != null && cachedContent.isNotEmpty) {
      return cachedContent;
    }

    // 缓存没有则从远程获取
    final chapterModel = EntityMapper.chapterFromEntity(chapter);
    final sourceModel = EntityMapper.bookSourceFromEntity(source);

    final content =
        await remoteDataSource.getChapterContent(chapterModel, sourceModel);

    // 保存到缓存
    if (content.isNotEmpty) {
      await localDataSource.saveChapterContent(
        chapter.bookUrl,
        chapter.url,
        content,
      );
    }

    return content;
  }

  @override
  Future<void> saveBook(BookEntity book) async {
    final model = EntityMapper.bookFromEntity(book);
    await localDataSource.saveBook(model);
  }

  @override
  Future<void> deleteBook(String bookUrl) async {
    await localDataSource.deleteBook(bookUrl);
  }

  @override
  Future<void> updateBook(BookEntity book) async {
    final model = EntityMapper.bookFromEntity(book);
    await localDataSource.updateBook(model);
  }

  @override
  Future<void> addToShelf(BookEntity book) async {
    // 添加到书架通常是设置group字段为非0值
    final updatedBook = book.copyWith(group: 1);
    await updateBook(updatedBook);
  }

  @override
  Future<void> removeFromShelf(String bookUrl) async {
    final book = await getBookByUrl(bookUrl);
    if (book != null) {
      // 从书架移除是设置group为0
      final updatedBook = book.copyWith(group: 0);
      await updateBook(updatedBook);
    }
  }

  @override
  Future<void> updateReadProgress(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
  ) async {
    await localDataSource.updateReadProgress(bookUrl, chapterIndex, chapterPos);
  }

  @override
  Future<int> checkBookUpdate(BookEntity book, BookSourceEntity source) async {
    try {
      final sourceModel = EntityMapper.bookSourceFromEntity(source);
      final bookModel = EntityMapper.bookFromEntity(book);

      // 获取最新章节列表
      final latestChapters = await remoteDataSource.getChapterList(
        bookModel,
        sourceModel,
      );

      // 计算新章节数量
      final currentCount = book.totalChapterNum;
      final newCount = latestChapters.length;
      final updateCount = newCount > currentCount ? newCount - currentCount : 0;

      // 如果有更新,保存新章节并更新书籍信息
      if (updateCount > 0) {
        await localDataSource.saveChapters(latestChapters);

        final updatedBook = book.copyWith(
          totalChapterNum: newCount,
          lastCheckCount: updateCount,
          lastCheckTime: DateTime.now().millisecondsSinceEpoch,
          latestChapterTitle:
              latestChapters.isNotEmpty ? latestChapters.last.title : null,
        );
        await updateBook(updatedBook);
      }

      return updateCount;
    } catch (e) {
      // 更新检查失败返回0
      return 0;
    }
  }

  @override
  Future<Map<String, int>> checkShelfBooksUpdate() async {
    final shelfBooks = await getShelfBooks();
    final updateMap = <String, int>{};

    for (final book in shelfBooks) {
      // 跳过本地书籍
      if (book.isLocal) continue;

      // 需要根据origin获取对应的书源
      // 这里简化处理,实际应该注入BookSourceRepository
      // updateMap[book.bookUrl] = await checkBookUpdate(book, source);
    }

    return updateMap;
  }

  /// SearchBook 转为 BookEntity 的辅助方法
  BookEntity _searchBookToEntity(
      SearchBook searchBook, BookSourceEntity source) {
    return BookEntity(
      bookUrl: searchBook.bookUrl,
      tocUrl: searchBook.tocUrl,
      origin: source.bookSourceUrl,
      originName: source.bookSourceName,
      name: searchBook.name,
      author: searchBook.author,
      kind: searchBook.kind,
      coverUrl: searchBook.coverUrl,
      intro: searchBook.intro,
      type: searchBook.type,
      group: 0, // 搜索结果默认不在书架
      latestChapterTitle: searchBook.latestChapterTitle,
      latestChapterTime: 0,
      lastCheckTime: searchBook.time,
      lastCheckCount: 0,
      totalChapterNum: 0,
      durChapterIndex: 0,
      durChapterPos: 0,
      durChapterTime: 0,
      wordCount: searchBook.wordCount,
      canUpdate: true,
      order: 0,
      originOrder: searchBook.originOrder,
      variable: searchBook.variable,
      syncTime: 0,
    );
  }
}
