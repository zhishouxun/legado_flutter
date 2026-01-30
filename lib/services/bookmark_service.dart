import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/bookmark.dart';

/// 书签服务
class BookmarkService extends BaseService {
  static final BookmarkService instance = BookmarkService._init();
  BookmarkService._init();

  final AppDatabase _db = AppDatabase.instance;

  /// 添加书签
  Future<void> addBookmark(Bookmark bookmark) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return;

        await db.insert(
          'bookmarks',
          bookmark.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
      operationName: '添加书签',
      logError: true,
    );
  }

  /// 删除书签
  Future<void> deleteBookmark(int time) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return;

        await db.delete(
          'bookmarks',
          where: 'time = ?',
          whereArgs: [time],
        );
      },
      operationName: '删除书签',
      logError: true,
    );
  }

  /// 获取所有书签
  Future<List<Bookmark>> getAllBookmarks() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <Bookmark>[];

        final maps = await db.query(
          'bookmarks',
          orderBy: 'time DESC',
        );

        return maps.map((map) => Bookmark.fromMap(map)).toList();
      },
      operationName: '获取所有书签',
      logError: true,
      defaultValue: <Bookmark>[],
    );
  }

  /// 根据书籍获取书签
  Future<List<Bookmark>> getBookmarksByBook(String bookName, String bookAuthor) async {
    final db = await _db.database;
    if (db == null) return [];

    final maps = await db.query(
      'bookmarks',
      where: 'bookName = ? AND bookAuthor = ?',
      whereArgs: [bookName, bookAuthor],
      orderBy: 'time DESC',
    );

    return maps.map((map) => Bookmark.fromMap(map)).toList();
  }

  /// 搜索书签（根据书籍名称和作者）
  /// 参考项目：BookmarkDao.flowSearch
  Future<List<Bookmark>> searchBookmarksByBook(
    String bookName,
    String bookAuthor,
    String searchKey,
  ) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <Bookmark>[];

        final maps = await db.query(
          'bookmarks',
          where: 'bookName = ? AND bookAuthor = ? AND (chapterName LIKE ? OR bookText LIKE ? OR content LIKE ?)',
          whereArgs: [
            bookName,
            bookAuthor,
            '%$searchKey%',
            '%$searchKey%',
            '%$searchKey%',
          ],
          orderBy: 'time DESC',
        );

        return maps.map((map) => Bookmark.fromMap(map)).toList();
      },
      operationName: '搜索书签',
      logError: true,
      defaultValue: <Bookmark>[],
    );
  }

  /// 搜索所有书签
  Future<List<Bookmark>> searchAllBookmarks(String searchKey) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <Bookmark>[];

        final maps = await db.query(
          'bookmarks',
          where: 'bookName LIKE ? OR bookAuthor LIKE ? OR chapterName LIKE ? OR bookText LIKE ? OR content LIKE ?',
          whereArgs: [
            '%$searchKey%',
            '%$searchKey%',
            '%$searchKey%',
            '%$searchKey%',
            '%$searchKey%',
          ],
          orderBy: 'time DESC',
        );

        return maps.map((map) => Bookmark.fromMap(map)).toList();
      },
      operationName: '搜索所有书签',
      logError: true,
      defaultValue: <Bookmark>[],
    );
  }

  /// 清空所有书签
  Future<void> clearAllBookmarks() async {
    final db = await _db.database;
    if (db == null) return;

    await db.delete('bookmarks');
  }
}

