import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/base/base_service.dart';
import '../../data/database/app_database.dart';
import '../../data/models/book_source.dart';
import '../../utils/eighteen_plus_filter.dart';

/// 书源管理服务
class BookSourceService extends BaseService {
  static final BookSourceService instance = BookSourceService._init();
  final AppDatabase _db = AppDatabase.instance;

  BookSourceService._init();

  /// 获取所有书源
  Future<List<BookSource>> getAllBookSources({bool enabledOnly = false}) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <BookSource>[];
        final result = await db.query(
          'book_sources',
          where: enabledOnly ? 'enabled = 1' : null,
          orderBy: 'customOrder ASC, bookSourceName ASC',
        );
        return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
      },
      operationName: '获取所有书源',
      logError: true,
      defaultValue: <BookSource>[],
    );
  }

  /// 获取启用的书源
  Future<List<BookSource>> getEnabledBookSources() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <BookSource>[];
        final result = await db.query(
          'book_sources',
          where: 'enabled = 1',
          orderBy: 'customOrder ASC, bookSourceName ASC',
        );
        return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
      },
      operationName: '获取启用的书源',
      logError: true,
      defaultValue: <BookSource>[],
    );
  }

  /// 获取禁用的书源
  Future<List<BookSource>> getDisabledBookSources() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <BookSource>[];
        final result = await db.query(
          'book_sources',
          where: 'enabled = 0',
          orderBy: 'customOrder ASC, bookSourceName ASC',
        );
        return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
      },
      operationName: '获取禁用的书源',
      logError: true,
      defaultValue: <BookSource>[],
    );
  }

  /// 获取需要登录的书源
  Future<List<BookSource>> getLoginBookSources() async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: 'loginUrl IS NOT NULL AND loginUrl != ""',
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 获取无分组的书源
  Future<List<BookSource>> getNoGroupBookSources() async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: 'bookSourceGroup IS NULL OR bookSourceGroup = ""',
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 获取启用发现的书源（有发现URL的）
  Future<List<BookSource>> getEnabledExploreBookSources() async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: 'enabledExplore = 1 AND exploreUrl IS NOT NULL AND exploreUrl != ""',
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 搜索发现书源
  Future<List<BookSource>> searchExploreBookSources(String keyword) async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: 'enabledExplore = 1 AND exploreUrl IS NOT NULL AND exploreUrl != "" AND (bookSourceName LIKE ? OR bookSourceGroup LIKE ?)',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 根据分组获取发现书源
  Future<List<BookSource>> getExploreBookSourcesByGroup(String group) async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: 'enabledExplore = 1 AND exploreUrl IS NOT NULL AND exploreUrl != "" AND (bookSourceGroup = ? OR bookSourceGroup LIKE ? OR bookSourceGroup LIKE ? OR bookSourceGroup LIKE ?)',
      whereArgs: [group, '$group,%', '%,$group', '%,$group,%'],
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 获取发现书源的所有分组
  Future<List<String>> getExploreGroups() async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.rawQuery(
      'SELECT DISTINCT bookSourceGroup FROM book_sources WHERE enabledExplore = 1 AND exploreUrl IS NOT NULL AND exploreUrl != "" AND bookSourceGroup IS NOT NULL AND bookSourceGroup != "" ORDER BY bookSourceGroup',
    );
    return result.map((row) => row['bookSourceGroup'] as String).toList();
  }

  /// 获取禁用发现的书源
  Future<List<BookSource>> getDisabledExploreBookSources() async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: 'enabledExplore = 0',
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 根据分组搜索书源
  Future<List<BookSource>> searchBookSourcesByGroup(String group) async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: 'bookSourceGroup LIKE ?',
      whereArgs: ['%$group%'],
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 搜索书源
  Future<List<BookSource>> searchBookSources(String keyword) async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: 'bookSourceName LIKE ? OR bookSourceUrl LIKE ? OR bookSourceGroup LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 根据分组获取书源
  Future<List<BookSource>> getBookSourcesByGroup(String? group) async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'book_sources',
      where: group == null ? 'bookSourceGroup IS NULL' : 'bookSourceGroup = ?',
      whereArgs: group == null ? null : [group],
      orderBy: 'customOrder ASC, bookSourceName ASC',
    );
    return result.map((json) => BookSource.fromJson(_convertDbToJson(json))).toList();
  }

  /// 获取所有分组
  Future<List<String>> getAllGroups() async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.rawQuery(
      'SELECT DISTINCT bookSourceGroup FROM book_sources WHERE bookSourceGroup IS NOT NULL ORDER BY bookSourceGroup',
    );
    return result.map((row) => row['bookSourceGroup'] as String).toList();
  }

  /// 获取最小排序值
  Future<int> getMinOrder() async {
    final db = await _db.database;
    if (db == null) return 0;
    final result = await db.rawQuery(
      'SELECT MIN(customOrder) as minOrder FROM book_sources',
    );
    if (result.isEmpty || result[0]['minOrder'] == null) {
      return 0;
    }
    return result[0]['minOrder'] as int;
  }

  /// 根据URL获取书源
  Future<BookSource?> getBookSourceByUrl(String url) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return null;
        final result = await db.query(
          'book_sources',
          where: 'bookSourceUrl = ?',
          whereArgs: [url],
          limit: 1,
        );
        if (result.isEmpty) return null;
        return BookSource.fromJson(_convertDbToJson(result.first));
      },
      operationName: '根据URL获取书源',
      logError: true,
      defaultValue: null,
    );
  }

  /// 添加书源
  Future<void> addBookSource(BookSource bookSource) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.insert(
      'book_sources',
      _convertJsonToDb(bookSource.toJson()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新书源
  Future<void> updateBookSource(BookSource bookSource) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.update(
      'book_sources',
      _convertJsonToDb(bookSource.toJson()),
      where: 'bookSourceUrl = ?',
      whereArgs: [bookSource.bookSourceUrl],
    );
  }

  /// 删除书源
  Future<void> deleteBookSource(String url) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.delete(
      'book_sources',
      where: 'bookSourceUrl = ?',
      whereArgs: [url],
    );
  }

  /// 批量导入书源
  /// 返回：{导入数量, 被过滤的18+网站数量}
  Future<Map<String, int>> importBookSources(List<BookSource> bookSources) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    
    // 过滤 18+ 网站
    final result = await EighteenPlusFilter.instance.filter18Plus<BookSource>(
      items: bookSources,
      getUrl: (source) => source.bookSourceUrl,
      getName: (source) => source.bookSourceName,
    );
    
    final filtered = result['filtered'] as List<BookSource>;
    final blocked = result['blocked'] as List<BookSource>;
    
    // 导入过滤后的书源
    int count = 0;
    if (filtered.isNotEmpty) {
      final batch = db.batch();
      
      for (final bookSource in filtered) {
        batch.insert(
          'book_sources',
          _convertJsonToDb(bookSource.toJson()),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
      
      await batch.commit(noResult: true);
    }
    
    return {
      'imported': count,
      'blocked': blocked.length,
    };
  }

  /// 启用/禁用书源
  Future<void> setBookSourceEnabled(String url, bool enabled) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.update(
      'book_sources',
      {'enabled': enabled ? 1 : 0},
      where: 'bookSourceUrl = ?',
      whereArgs: [url],
    );
  }

  /// 批量启用/禁用书源
  Future<void> batchSetEnabled(List<String> urls, bool enabled) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    
    final batch = db.batch();
    for (final url in urls) {
      batch.update(
        'book_sources',
        {'enabled': enabled ? 1 : 0},
        where: 'bookSourceUrl = ?',
        whereArgs: [url],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 批量删除书源
  Future<void> batchDeleteBookSources(List<String> urls) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    
    final batch = db.batch();
    for (final url in urls) {
      batch.delete(
        'book_sources',
        where: 'bookSourceUrl = ?',
        whereArgs: [url],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 批量设置书源分组
  Future<void> batchSetGroup(List<String> urls, String? groupName) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    
    final batch = db.batch();
    for (final url in urls) {
      batch.update(
        'book_sources',
        {'bookSourceGroup': groupName},
        where: 'bookSourceUrl = ?',
        whereArgs: [url],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 转换数据库格式到JSON格式
  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbData) {
    final json = Map<String, dynamic>.from(dbData);
    
    // 转换布尔值
    json['enabled'] = dbData['enabled'] == 1;
    json['enabledExplore'] = dbData['enabledExplore'] == 1;
    json['enabledCookieJar'] = dbData['enabledCookieJar'] == 1;
    
    // 解析JSON字符串字段
    if (dbData['ruleExplore'] != null) {
      try {
        json['ruleExplore'] = jsonDecode(dbData['ruleExplore']);
      } catch (e) {
        json['ruleExplore'] = null;
      }
    }
    if (dbData['ruleSearch'] != null) {
      try {
        json['ruleSearch'] = jsonDecode(dbData['ruleSearch']);
      } catch (e) {
        json['ruleSearch'] = null;
      }
    }
    if (dbData['ruleBookInfo'] != null) {
      try {
        json['ruleBookInfo'] = jsonDecode(dbData['ruleBookInfo']);
      } catch (e) {
        json['ruleBookInfo'] = null;
      }
    }
    if (dbData['ruleToc'] != null) {
      try {
        json['ruleToc'] = jsonDecode(dbData['ruleToc']);
      } catch (e) {
        json['ruleToc'] = null;
      }
    }
    if (dbData['ruleContent'] != null) {
      try {
        json['ruleContent'] = jsonDecode(dbData['ruleContent']);
      } catch (e) {
        json['ruleContent'] = null;
      }
    }
    
    return json;
  }

  /// 转换JSON格式到数据库格式
  Map<String, dynamic> _convertJsonToDb(Map<String, dynamic> json) {
    final dbData = Map<String, dynamic>.from(json);
    
    // 转换布尔值
    dbData['enabled'] = json['enabled'] == true ? 1 : 0;
    dbData['enabledExplore'] = json['enabledExplore'] == true ? 1 : 0;
    dbData['enabledCookieJar'] = json['enabledCookieJar'] == true ? 1 : 0;
    
    // 序列化JSON对象字段
    if (json['ruleExplore'] != null) {
      dbData['ruleExplore'] = jsonEncode(json['ruleExplore']);
    }
    if (json['ruleSearch'] != null) {
      dbData['ruleSearch'] = jsonEncode(json['ruleSearch']);
    }
    if (json['ruleBookInfo'] != null) {
      dbData['ruleBookInfo'] = jsonEncode(json['ruleBookInfo']);
    }
    if (json['ruleToc'] != null) {
      dbData['ruleToc'] = jsonEncode(json['ruleToc']);
    }
    if (json['ruleContent'] != null) {
      dbData['ruleContent'] = jsonEncode(json['ruleContent']);
    }
    
    return dbData;
  }
}

