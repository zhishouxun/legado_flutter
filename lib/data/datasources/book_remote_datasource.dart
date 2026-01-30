import '../models/search_book.dart';
import '../models/book.dart';
import '../models/book_chapter.dart';
import '../models/book_source.dart';

/// 书籍远程数据源接口 - Data层的网络访问抽象
/// 负责通过书源规则解析网页数据
abstract class BookRemoteDataSource {
  /// 搜索书籍
  /// @param keyword 搜索关键词
  /// @param source 书源
  /// @return Stream形式的搜索结果流
  Stream<SearchBook> searchBooks(String keyword, BookSource source);

  /// 获取书籍详情信息
  /// @param book 书籍对象
  /// @param source 书源
  Future<Book> getBookInfo(Book book, BookSource source);

  /// 获取书籍章节列表
  /// @param book 书籍对象
  /// @param source 书源
  Future<List<BookChapter>> getChapterList(Book book, BookSource source);

  /// 获取章节内容
  /// @param chapter 章节对象
  /// @param source 书源
  Future<String> getChapterContent(BookChapter chapter, BookSource source);
}
