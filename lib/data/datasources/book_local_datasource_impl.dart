import '../models/book.dart';
import '../models/book_chapter.dart';
import '../../services/book/book_service.dart';
import '../../services/reader/cache_service.dart';
import '../../data/database/app_database.dart';
import 'book_local_datasource.dart';

/// BookLocalDataSource 的实现类
/// 封装现有的 BookService 和 CacheService,使其符合 DataSource 接口
class BookLocalDataSourceImpl implements BookLocalDataSource {
  final BookService _bookService;
  final CacheService _cacheService;

  BookLocalDataSourceImpl({
    BookService? bookService,
    CacheService? cacheService,
  })  : _bookService = bookService ?? BookService.instance,
        _cacheService = cacheService ?? CacheService.instance;

  @override
  Future<Book?> getBookByUrl(String bookUrl) async {
    return await _bookService.getBookByUrl(bookUrl);
  }

  @override
  Future<List<Book>> getAllBooks() async {
    return await _bookService.getBookshelfBooks();
  }

  @override
  Future<List<Book>> getShelfBooks() async {
    // 书架书籍通常是所有已保存的书籍
    return await _bookService.getBookshelfBooks();
  }

  @override
  Future<List<Book>> getBooksByGroup(int groupId) async {
    return await _bookService.getBooksByGroup(groupId);
  }

  @override
  Future<void> saveBook(Book book) async {
    await _bookService.saveBook(book);
  }

  @override
  Future<void> deleteBook(String bookUrl) async {
    await _bookService.deleteBook(bookUrl);
  }

  @override
  Future<void> updateBook(Book book) async {
    await _bookService.updateBook(book);
  }

  @override
  Future<void> updateReadProgress(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
  ) async {
    // 获取当前章节标题
    final chapters = await getChapterList(bookUrl);
    String? chapterTitle;
    if (chapterIndex >= 0 && chapterIndex < chapters.length) {
      chapterTitle = chapters[chapterIndex].title;
    }

    await _bookService.updateReadingProgress(
      bookUrl,
      chapterIndex,
      chapterPos,
      chapterTitle,
    );
  }

  @override
  Future<List<BookChapter>> getChapterList(String bookUrl) async {
    // 直接操作数据库获取章节列表
    final db = await AppDatabase.instance.database;
    if (db == null) return [];

    final result = await db.query(
      'chapters',
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
      orderBy: '"index" ASC',
    );

    return result.map((map) => BookChapter.fromJson(map)).toList();
  }

  @override
  Future<void> saveChapters(List<BookChapter> chapters) async {
    await _bookService.saveChapters(chapters);
  }

  @override
  Future<String?> getChapterContent(String bookUrl, String chapterUrl) async {
    // 简化实现:直接调用CacheService的hasChapterCache
    // 由于复杂性,这里返回null,由Repository层处理缓存逻辑
    // TODO: 实现更复杂的缓存读取逻辑
    return null;
  }

  @override
  Future<void> saveChapterContent(
    String bookUrl,
    String chapterUrl,
    String content,
  ) async {
    // 需要Book和BookChapter对象
    final book = await getBookByUrl(bookUrl);
    if (book == null) return;

    final chapters = await getChapterList(bookUrl);
    final chapter = chapters.firstWhere(
      (c) => c.url == chapterUrl,
      orElse: () => BookChapter(url: chapterUrl, bookUrl: bookUrl),
    );

    await _cacheService.saveChapterContent(book, chapter, content);
  }
}
