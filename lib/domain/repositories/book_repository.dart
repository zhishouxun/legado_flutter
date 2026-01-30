import '../entities/book_entity.dart';
import '../entities/chapter_entity.dart';
import '../entities/book_source_entity.dart';

/// 书籍仓库接口 - Domain层的抽象契约
/// 参考：Clean Architecture - Repository Interface
abstract class BookRepository {
  /// 根据URL获取书籍
  Future<BookEntity?> getBookByUrl(String bookUrl);

  /// 获取所有书籍
  Future<List<BookEntity>> getAllBooks();

  /// 获取书架中的书籍
  Future<List<BookEntity>> getShelfBooks();

  /// 根据分组ID获取书籍
  Future<List<BookEntity>> getBooksByGroup(int groupId);

  /// 搜索书籍
  /// @param keyword 搜索关键词
  /// @param sources 指定书源列表(为空则使用所有启用的书源)
  /// @return Stream形式的搜索结果流
  Stream<List<BookEntity>> searchBooks(
    String keyword, {
    List<BookSourceEntity>? sources,
  });

  /// 获取书籍详情信息
  /// @param book 书籍实体
  /// @param source 书源实体
  Future<BookEntity> getBookInfo(BookEntity book, BookSourceEntity source);

  /// 获取书籍章节列表
  /// @param book 书籍实体
  /// @param source 书源实体
  Future<List<ChapterEntity>> getChapterList(
    BookEntity book,
    BookSourceEntity source,
  );

  /// 获取章节内容
  /// @param chapter 章节实体
  /// @param source 书源实体
  Future<String> getChapterContent(
    ChapterEntity chapter,
    BookSourceEntity source,
  );

  /// 保存书籍
  Future<void> saveBook(BookEntity book);

  /// 删除书籍
  Future<void> deleteBook(String bookUrl);

  /// 更新书籍
  Future<void> updateBook(BookEntity book);

  /// 添加书籍到书架
  Future<void> addToShelf(BookEntity book);

  /// 从书架移除书籍
  Future<void> removeFromShelf(String bookUrl);

  /// 更新阅读进度
  Future<void> updateReadProgress(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
  );

  /// 检查书籍是否有更新
  /// @param book 书籍实体
  /// @param source 书源实体
  /// @return 新章节数量
  Future<int> checkBookUpdate(BookEntity book, BookSourceEntity source);

  /// 批量检查书架书籍更新
  Future<Map<String, int>> checkShelfBooksUpdate();
}
