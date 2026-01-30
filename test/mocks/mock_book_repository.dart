import 'package:legado_flutter/domain/entities/book_entity.dart';
import 'package:legado_flutter/domain/entities/chapter_entity.dart';
import 'package:legado_flutter/domain/entities/book_source_entity.dart';
import 'package:legado_flutter/domain/repositories/book_repository.dart';

/// Mock implementation of BookRepository for testing
class MockBookRepository implements BookRepository {
  // 可配置的返回值
  List<BookEntity> _shelfBooks = [];
  BookEntity? _bookByUrl;
  Stream<List<BookEntity>>? _searchBooksStream;
  BookEntity? _bookInfo;
  List<ChapterEntity> _chapterList = [];
  String _chapterContent = '';
  int _updateCount = 0;

  // 调用计数器
  int getShelfBooksCallCount = 0;
  int searchBooksCallCount = 0;
  int saveBookCallCount = 0;
  int deleteBookCallCount = 0;
  int updateReadProgressCallCount = 0;

  // 设置返回值的方法
  void setShelfBooks(List<BookEntity> books) => _shelfBooks = books;
  void setBookByUrl(BookEntity? book) => _bookByUrl = book;
  void setSearchBooksStream(Stream<List<BookEntity>> stream) =>
      _searchBooksStream = stream;
  void setBookInfo(BookEntity book) => _bookInfo = book;
  void setChapterList(List<ChapterEntity> chapters) => _chapterList = chapters;
  void setChapterContent(String content) => _chapterContent = content;
  void setUpdateCount(int count) => _updateCount = count;

  @override
  Future<BookEntity?> getBookByUrl(String bookUrl) async {
    return _bookByUrl;
  }

  @override
  Future<List<BookEntity>> getAllBooks() async {
    return _shelfBooks;
  }

  @override
  Future<List<BookEntity>> getShelfBooks() async {
    getShelfBooksCallCount++;
    return _shelfBooks;
  }

  @override
  Future<List<BookEntity>> getBooksByGroup(int groupId) async {
    return _shelfBooks.where((book) => book.group == groupId).toList();
  }

  @override
  Stream<List<BookEntity>> searchBooks(
    String keyword, {
    List<BookSourceEntity>? sources,
  }) {
    searchBooksCallCount++;
    return _searchBooksStream ?? Stream.value([]);
  }

  @override
  Future<BookEntity> getBookInfo(
      BookEntity book, BookSourceEntity source) async {
    return _bookInfo ?? book;
  }

  @override
  Future<List<ChapterEntity>> getChapterList(
    BookEntity book,
    BookSourceEntity source,
  ) async {
    return _chapterList;
  }

  @override
  Future<String> getChapterContent(
    ChapterEntity chapter,
    BookSourceEntity source,
  ) async {
    return _chapterContent;
  }

  @override
  Future<void> saveBook(BookEntity book) async {
    saveBookCallCount++;
    _shelfBooks.add(book);
  }

  @override
  Future<void> deleteBook(String bookUrl) async {
    deleteBookCallCount++;
    _shelfBooks.removeWhere((book) => book.bookUrl == bookUrl);
  }

  @override
  Future<void> updateBook(BookEntity book) async {
    final index = _shelfBooks.indexWhere((b) => b.bookUrl == book.bookUrl);
    if (index != -1) {
      _shelfBooks[index] = book;
    }
  }

  @override
  Future<void> addToShelf(BookEntity book) async {
    await saveBook(book);
  }

  @override
  Future<void> removeFromShelf(String bookUrl) async {
    await deleteBook(bookUrl);
  }

  @override
  Future<void> updateReadProgress(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
  ) async {
    updateReadProgressCallCount++;
  }

  @override
  Future<int> checkBookUpdate(BookEntity book, BookSourceEntity source) async {
    return _updateCount;
  }

  @override
  Future<Map<String, int>> checkShelfBooksUpdate() async {
    return {for (var book in _shelfBooks) book.bookUrl: _updateCount};
  }

  // 重置所有计数器
  void resetCounters() {
    getShelfBooksCallCount = 0;
    searchBooksCallCount = 0;
    saveBookCallCount = 0;
    deleteBookCallCount = 0;
    updateReadProgressCallCount = 0;
  }
}
