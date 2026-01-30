import '../models/book.dart';
import '../models/book_chapter.dart';

/// 书籍本地数据源接口 - Data层的数据访问抽象
/// 负责与本地存储(数据库)交互
abstract class BookLocalDataSource {
  /// 根据URL获取书籍
  Future<Book?> getBookByUrl(String bookUrl);

  /// 获取所有书籍
  Future<List<Book>> getAllBooks();

  /// 获取书架中的书籍(通过group字段判断)
  Future<List<Book>> getShelfBooks();

  /// 根据分组ID获取书籍
  Future<List<Book>> getBooksByGroup(int groupId);

  /// 保存书籍
  Future<void> saveBook(Book book);

  /// 删除书籍
  Future<void> deleteBook(String bookUrl);

  /// 更新书籍
  Future<void> updateBook(Book book);

  /// 更新阅读进度
  Future<void> updateReadProgress(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
  );

  /// 获取书籍的章节列表
  Future<List<BookChapter>> getChapterList(String bookUrl);

  /// 保存章节列表
  Future<void> saveChapters(List<BookChapter> chapters);

  /// 获取章节内容(从缓存)
  Future<String?> getChapterContent(String bookUrl, String chapterUrl);

  /// 保存章节内容(到缓存)
  Future<void> saveChapterContent(
    String bookUrl,
    String chapterUrl,
    String content,
  );
}
