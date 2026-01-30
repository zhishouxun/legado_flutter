import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/search_book.dart';
import '../utils/app_log.dart';

/// 搜索结果缓存服务
/// 参考项目：io.legado.app.data.dao.SearchBookDao
class SearchBookService extends BaseService {
  static final SearchBookService instance = SearchBookService._init();
  final AppDatabase _db = AppDatabase.instance;

  SearchBookService._init();

  /// 获取搜索结果
  Future<SearchBook?> getSearchBook(String bookUrl) async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      final result = await db.query(
        'searchBooks',
        where: 'bookUrl = ?',
        whereArgs: [bookUrl],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return SearchBook.fromJson(_convertDbToJson(result.first));
    } catch (e) {
      AppLog.instance.put('获取搜索结果失败: $bookUrl', error: e);
      return null;
    }
  }

  /// 根据书名和作者获取第一个搜索结果
  Future<SearchBook?> getFirstByNameAuthor(String name, String author) async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      final result = await db.rawQuery('''
        SELECT t1.*, t2.customOrder as originOrder
        FROM searchBooks as t1
        INNER JOIN book_sources as t2 ON t1.origin = t2.bookSourceUrl
        WHERE t1.name = ? AND t1.author = ?
        AND t2.enabled = 1
        ORDER BY t2.customOrder
        LIMIT 1
      ''', [name, author]);

      if (result.isEmpty) return null;
      return SearchBook.fromJson(_convertDbToJson(result.first));
    } catch (e) {
      AppLog.instance.put('根据书名作者获取搜索结果失败: $name/$author', error: e);
      return null;
    }
  }

  /// 根据分组切换书源
  Future<List<SearchBook>> changeSourceByGroup(
    String name,
    String author,
    String sourceGroup,
  ) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.rawQuery('''
        SELECT t1.name, t1.author, t1.origin, t1.originName, t1.coverUrl, 
               t1.bookUrl, t1.type, t1.time, t1.intro, t1.kind, 
               t1.latestChapterTitle, t1.tocUrl, t1.variable, t1.wordCount, 
               t2.customOrder as originOrder, t1.chapterWordCountText, 
               t1.respondTime, t1.chapterWordCount
        FROM searchBooks as t1
        INNER JOIN book_sources as t2 ON t1.origin = t2.bookSourceUrl
        WHERE t1.name = ? AND t1.author LIKE ?
        AND t2.enabled = 1 AND t2.bookSourceGroup LIKE ?
        ORDER BY t2.customOrder
      ''', [name, '%$author%', '%$sourceGroup%']);

      return result.map((row) => SearchBook.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('根据分组切换书源失败: $name/$author/$sourceGroup', error: e);
      return [];
    }
  }

  /// 搜索切换书源
  Future<List<SearchBook>> changeSourceSearch(
    String name,
    String author,
    String key,
    String sourceGroup,
  ) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.rawQuery('''
        SELECT t1.name, t1.author, t1.origin, t1.originName, t1.coverUrl, 
               t1.bookUrl, t1.type, t1.time, t1.intro, t1.kind, 
               t1.latestChapterTitle, t1.tocUrl, t1.variable, t1.wordCount, 
               t2.customOrder as originOrder, t1.chapterWordCountText, 
               t1.respondTime, t1.chapterWordCount
        FROM searchBooks as t1
        INNER JOIN book_sources as t2 ON t1.origin = t2.bookSourceUrl
        WHERE t1.name = ? AND t1.author LIKE ?
        AND t2.bookSourceGroup LIKE ?
        AND (t1.originName LIKE ? OR t1.latestChapterTitle LIKE ?)
        AND t2.enabled = 1
        ORDER BY t2.customOrder
      ''', [name, '%$author%', '%$sourceGroup%', '%$key%', '%$key%']);

      return result.map((row) => SearchBook.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('搜索切换书源失败: $name/$author/$key/$sourceGroup', error: e);
      return [];
    }
  }

  /// 获取有封面的启用书源结果
  Future<List<SearchBook>> getEnableHasCover(String name, String author) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.rawQuery('''
        SELECT t1.name, t1.author, t1.origin, t1.originName, t1.coverUrl, 
               t1.bookUrl, t1.type, t1.time, t1.intro, t1.kind, 
               t1.latestChapterTitle, t1.tocUrl, t1.variable, t1.wordCount, 
               t2.customOrder as originOrder, t1.chapterWordCountText, 
               t1.respondTime, t1.chapterWordCount
        FROM searchBooks as t1
        INNER JOIN book_sources as t2 ON t1.origin = t2.bookSourceUrl
        WHERE t1.name = ? AND t1.author = ?
        AND t1.coverUrl IS NOT NULL AND t1.coverUrl <> ''
        AND t2.enabled = 1
        ORDER BY t2.customOrder
      ''', [name, author]);

      return result.map((row) => SearchBook.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取有封面的搜索结果失败: $name/$author', error: e);
      return [];
    }
  }

  /// 保存或更新搜索结果
  Future<bool> saveSearchBook(SearchBook searchBook) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.insert(
        'searchBooks',
        searchBook.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('保存搜索结果失败: ${searchBook.bookUrl}', error: e);
      return false;
    }
  }

  /// 批量保存搜索结果
  Future<int> saveSearchBooks(List<SearchBook> searchBooks) async {
    final db = await _db.database;
    if (db == null) return 0;

    if (searchBooks.isEmpty) return 0;

    try {
      final batch = db.batch();
      for (final searchBook in searchBooks) {
        batch.insert(
          'searchBooks',
          searchBook.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: false);
      return searchBooks.length;
    } catch (e) {
      AppLog.instance.put('批量保存搜索结果失败', error: e);
      return 0;
    }
  }

  /// 清除指定书籍的搜索结果
  Future<bool> clearSearchBooks(String name, String author) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete(
        'searchBooks',
        where: 'name = ? AND author = ?',
        whereArgs: [name, author],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('清除搜索结果失败: $name/$author', error: e);
      return false;
    }
  }

  /// 清除过期的搜索结果（默认保留7天）
  Future<bool> clearExpiredSearchBooks({int days = 7}) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      final expireTime = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
      await db.delete(
        'searchBooks',
        where: 'time < ?',
        whereArgs: [expireTime],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('清除过期搜索结果失败', error: e);
      return false;
    }
  }

  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbRow) {
    return Map<String, dynamic>.from(dbRow);
  }
}

