import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/search_keyword.dart';
import '../utils/app_log.dart';

/// 搜索关键词服务
/// 参考项目：io.legado.app.data.dao.SearchKeywordDao
class SearchKeywordService extends BaseService {
  static final SearchKeywordService instance = SearchKeywordService._init();
  final AppDatabase _db = AppDatabase.instance;

  SearchKeywordService._init();

  /// 获取所有搜索关键词
  Future<List<SearchKeyword>> getAllKeywords() async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query('search_keywords');
      return result.map((row) => SearchKeyword.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取搜索关键词失败', error: e);
      return [];
    }
  }

  /// 按使用次数排序获取关键词
  Future<List<SearchKeyword>> getKeywordsByUsage({int limit = 20}) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'search_keywords',
        orderBy: 'usage DESC',
        limit: limit,
      );
      return result.map((row) => SearchKeyword.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('按使用次数获取搜索关键词失败', error: e);
      return [];
    }
  }

  /// 按时间排序获取关键词
  Future<List<SearchKeyword>> getKeywordsByTime({int limit = 20}) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'search_keywords',
        orderBy: 'lastUseTime DESC',
        limit: limit,
      );
      return result.map((row) => SearchKeyword.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('按时间获取搜索关键词失败', error: e);
      return [];
    }
  }

  /// 搜索关键词
  Future<List<SearchKeyword>> searchKeywords(String key, {int limit = 20}) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'search_keywords',
        where: 'word LIKE ?',
        whereArgs: ['%$key%'],
        orderBy: 'usage DESC',
        limit: limit,
      );
      return result.map((row) => SearchKeyword.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('搜索关键词失败', error: e);
      return [];
    }
  }

  /// 获取关键词
  Future<SearchKeyword?> getKeyword(String word) async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      final result = await db.query(
        'search_keywords',
        where: 'word = ?',
        whereArgs: [word],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return SearchKeyword.fromJson(_convertDbToJson(result.first));
    } catch (e) {
      AppLog.instance.put('获取关键词失败: $word', error: e);
      return null;
    }
  }

  /// 保存或更新搜索关键词
  Future<bool> saveKeyword(SearchKeyword keyword) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.insert(
        'search_keywords',
        keyword.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('保存搜索关键词失败: ${keyword.word}', error: e);
      return false;
    }
  }

  /// 增加关键词使用次数
  Future<bool> incrementKeywordUsage(String word) async {
    final existing = await getKeyword(word);
    if (existing != null) {
      return await saveKeyword(existing.copyWith(
        usage: existing.usage + 1,
        lastUseTime: DateTime.now().millisecondsSinceEpoch,
      ));
    } else {
      return await saveKeyword(SearchKeyword(
        word: word,
        usage: 1,
        lastUseTime: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  /// 删除关键词
  Future<bool> deleteKeyword(String word) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete(
        'search_keywords',
        where: 'word = ?',
        whereArgs: [word],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除搜索关键词失败: $word', error: e);
      return false;
    }
  }

  /// 清空所有关键词
  Future<bool> clearAllKeywords() async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete('search_keywords');
      return true;
    } catch (e) {
      AppLog.instance.put('清空搜索关键词失败', error: e);
      return false;
    }
  }

  /// 获取搜索历史（字符串列表，兼容旧接口）
  Future<List<String>> getSearchHistory() async {
    final keywords = await getKeywordsByTime(limit: 20);
    return keywords.map((k) => k.word).toList();
  }

  /// 保存搜索关键词（兼容旧接口）
  Future<void> saveSearchKeyword(String keyword) async {
    if (keyword.trim().isEmpty) return;
    await incrementKeywordUsage(keyword.trim());
  }

  /// 删除搜索历史（兼容旧接口）
  Future<void> deleteSearchHistory(String keyword) async {
    await deleteKeyword(keyword);
  }

  /// 清空搜索历史（兼容旧接口）
  Future<void> clearSearchHistory() async {
    await clearAllKeywords();
  }

  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbRow) {
    return Map<String, dynamic>.from(dbRow);
  }
}

