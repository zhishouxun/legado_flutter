import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/rss_source.dart';
import '../data/models/rss_article.dart';
import '../data/models/rss_star.dart';
import '../utils/app_log.dart';
import '../utils/default_data.dart';
import 'rss/rss_parser_service.dart';

/// RSS服务 - 管理RSS源和文章
class RssService extends BaseService {
  static final RssService instance = RssService._init();
  final AppDatabase _db = AppDatabase.instance;

  RssService._init();

  /// 转换数据库行到JSON
  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> row) {
    final json = <String, dynamic>{};
    for (final entry in row.entries) {
      json[entry.key] = entry.value;
    }
    return json;
  }

  // ========== RSS源管理 ==========

  /// 获取所有RSS源
  Future<List<RssSource>> getAllRssSources({bool enabledOnly = false}) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <RssSource>[];
        
        final result = await db.query(
          'rssSources',
          where: enabledOnly ? 'enabled = ?' : null,
          whereArgs: enabledOnly ? [1] : null,
          orderBy: 'customOrder ASC, sourceName ASC',
        );
        
        return result.map((row) => RssSource.fromJson(_convertDbToJson(row))).toList();
      },
      operationName: '获取所有RSS源',
      logError: true,
      defaultValue: <RssSource>[],
    );
  }

  /// 获取启用的RSS源
  Future<List<RssSource>> getEnabledRssSources() async {
    return await getAllRssSources(enabledOnly: true);
  }

  /// 根据URL获取RSS源
  Future<RssSource?> getRssSourceByUrl(String sourceUrl) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return null;
        
        final result = await db.query(
          'rssSources',
          where: 'sourceUrl = ?',
          whereArgs: [sourceUrl],
          limit: 1,
        );
        
        if (result.isEmpty) return null;
        return RssSource.fromJson(_convertDbToJson(result.first));
      },
      operationName: '根据URL获取RSS源',
      logError: true,
      defaultValue: null,
    );
  }

  /// 添加或更新RSS源
  Future<bool> addOrUpdateRssSource(RssSource source) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return false;
        
        final json = source.toJson();
        await db.insert(
          'rssSources',
          json,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      },
      operationName: '添加或更新RSS源',
      logError: true,
      defaultValue: false,
    );
  }

  /// 删除RSS源
  Future<bool> deleteRssSource(String sourceUrl) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return false;
        
        await db.delete(
          'rssSources',
          where: 'sourceUrl = ?',
          whereArgs: [sourceUrl],
        );
        // 同时删除该源的所有文章
        await db.delete(
          'rssArticles',
          where: 'origin = ?',
          whereArgs: [sourceUrl],
        );
        return true;
      },
      operationName: '删除RSS源',
      logError: true,
      defaultValue: false,
    );
  }

  /// 更新RSS源启用状态
  Future<bool> updateRssSourceEnabled(String sourceUrl, bool enabled) async {
    final db = await _db.database;
    if (db == null) return false;
    
    try {
      await db.update(
        'rssSources',
        {'enabled': enabled ? 1 : 0},
        where: 'sourceUrl = ?',
        whereArgs: [sourceUrl],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('更新RSS源状态失败', error: e);
      return false;
    }
  }

  /// 获取所有分组
  Future<List<String>> getAllGroups() async {
    final db = await _db.database;
    if (db == null) return [];
    
    try {
      final result = await db.rawQuery(
        'SELECT DISTINCT sourceGroup FROM rssSources WHERE sourceGroup IS NOT NULL AND sourceGroup != ""',
      );
      return result.map((row) => row['sourceGroup'] as String).toList()..sort();
    } catch (e) {
      return [];
    }
  }

  // ========== RSS文章管理 ==========

  /// 获取RSS文章列表
  Future<List<RssArticle>> getRssArticles({
    String? origin,
    String? group,
    bool? read,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _db.database;
    if (db == null) return [];
    
    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];
    
    if (origin != null) {
      whereConditions.add('origin = ?');
      whereArgs.add(origin);
    }
    if (group != null) {
      whereConditions.add('"group" = ?');
      whereArgs.add(group);
    }
    if (read != null) {
      whereConditions.add('read = ?');
      whereArgs.add(read ? 1 : 0);
    }
    
    final where = whereConditions.isNotEmpty 
        ? whereConditions.join(' AND ')
        : null;
    
    final result = await db.query(
      'rssArticles',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '"order" DESC, pubDate DESC',
      limit: limit,
      offset: offset,
    );
    
    return result.map((row) => RssArticle.fromJson(_convertDbToJson(row))).toList();
  }

  /// 添加或更新RSS文章
  Future<bool> addOrUpdateRssArticle(RssArticle article) async {
    final db = await _db.database;
    if (db == null) return false;
    
    try {
      final json = article.toJson();
      await db.insert(
        'rssArticles',
        json,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('添加RSS文章失败', error: e);
      return false;
    }
  }

  /// 批量添加或更新RSS文章
  Future<int> addOrUpdateRssArticles(List<RssArticle> articles) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    if (articles.isEmpty) return 0;
    
    try {
      final batch = db.batch();
      for (final article in articles) {
        final json = article.toJson();
        batch.insert(
          'rssArticles',
          json,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: false);
      return articles.length;
    } catch (e) {
      AppLog.instance.put('批量添加RSS文章失败', error: e);
      return 0;
    }
  }

  /// 标记文章为已读
  Future<bool> markArticleAsRead(String origin, String link, bool read) async {
    final db = await _db.database;
    if (db == null) return false;
    
    try {
      await db.update(
        'rssArticles',
        {'read': read ? 1 : 0},
        where: 'origin = ? AND link = ?',
        whereArgs: [origin, link],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('标记文章已读失败', error: e);
      return false;
    }
  }

  /// 删除文章
  Future<bool> deleteRssArticle(String origin, String link) async {
    final db = await _db.database;
    if (db == null) return false;
    
    try {
      await db.delete(
        'rssArticles',
        where: 'origin = ? AND link = ?',
        whereArgs: [origin, link],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除RSS文章失败', error: e);
      return false;
    }
  }

  /// 删除源的所有文章
  Future<bool> deleteRssArticlesByOrigin(String origin) async {
    final db = await _db.database;
    if (db == null) return false;
    
    try {
      await db.delete(
        'rssArticles',
        where: 'origin = ?',
        whereArgs: [origin],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除RSS源文章失败', error: e);
      return false;
    }
  }

  /// 获取未读文章数量
  Future<int> getUnreadArticleCount({String? origin}) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    try {
      final where = origin != null 
          ? 'read = 0 AND origin = ?'
          : 'read = 0';
      final whereArgs = origin != null ? [origin] : null;
      
      final result = await db.query(
        'rssArticles',
        columns: ['COUNT(*) as count'],
        where: where,
        whereArgs: whereArgs,
      );
      
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ========== RSS收藏管理 ==========

  /// 添加或更新RSS收藏
  Future<bool> addOrUpdateRssStar(RssStar star) async {
    final db = await _db.database;
    if (db == null) return false;
    
    try {
      final json = star.toJson();
      await db.insert(
        'rssStars',
        json,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('添加RSS收藏失败', error: e);
      return false;
    }
  }

  /// 从RSS文章添加收藏
  Future<bool> addStarFromArticle(RssArticle article, {String? group}) async {
    final star = RssStar.fromRssArticle(article, group: group);
    return await addOrUpdateRssStar(star);
  }

  /// 删除RSS收藏
  Future<bool> deleteRssStar(String origin, String link) async {
    final db = await _db.database;
    if (db == null) return false;
    
    try {
      await db.delete(
        'rssStars',
        where: 'origin = ? AND link = ?',
        whereArgs: [origin, link],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除RSS收藏失败', error: e);
      return false;
    }
  }

  /// 检查是否已收藏
  Future<bool> isStarred(String origin, String link) async {
    final db = await _db.database;
    if (db == null) return false;
    
    try {
      final result = await db.query(
        'rssStars',
        columns: ['COUNT(*) as count'],
        where: 'origin = ? AND link = ?',
        whereArgs: [origin, link],
      );
      return (Sqflite.firstIntValue(result) ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }

  /// 获取RSS收藏列表
  Future<List<RssStar>> getRssStars({
    String? group,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _db.database;
    if (db == null) return [];
    
    final where = group != null ? '"group" = ?' : null;
    final whereArgs = group != null ? [group] : null;
    
    try {
      final result = await db.query(
        'rssStars',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'starTime DESC',
        limit: limit,
        offset: offset,
      );
      
      return result.map((row) => RssStar.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取RSS收藏列表失败', error: e);
      return [];
    }
  }

  /// 获取所有收藏分组
  Future<List<String>> getStarGroups() async {
    final db = await _db.database;
    if (db == null) return [];
    
    try {
      final result = await db.rawQuery(
        'SELECT DISTINCT "group" FROM rssStars WHERE "group" IS NOT NULL AND "group" != "" ORDER BY "group"',
      );
      return result.map((row) => row['group'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取指定分组的收藏数量
  Future<int> getStarCountByGroup(String? group) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    try {
      final where = group != null ? '"group" = ?' : null;
      final whereArgs = group != null ? [group] : null;
      
      final result = await db.query(
        'rssStars',
        columns: ['COUNT(*) as count'],
        where: where,
        whereArgs: whereArgs,
      );
      
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ========== RSS文章刷新 ==========

  /// 刷新RSS源的文章列表
  /// 参考项目：Rss.getArticlesAwait
  Future<int> refreshRssArticles(RssSource source, {String? sortName, String? sortUrl}) async {
    try {
      // 获取文章列表
      final articles = await RssParserService.instance.getArticles(
        source: source,
        sortName: sortName,
        sortUrl: sortUrl ?? source.sourceUrl,
        page: 1,
      );

      if (articles.isEmpty) {
        return 0;
      }

      // 批量保存文章
      final count = await addOrUpdateRssArticles(articles);

      // 更新RSS源的最后更新时间
      final db = await _db.database;
      if (db != null) {
        await db.update(
          'rssSources',
          {'lastUpdateTime': DateTime.now().millisecondsSinceEpoch},
          where: 'sourceUrl = ?',
          whereArgs: [source.sourceUrl],
        );
      }

      return count;
    } catch (e) {
      AppLog.instance.put('刷新RSS文章失败: ${source.sourceName}', error: e);
      rethrow;
    }
  }

  /// 导入默认RSS源
  /// 参考项目：DefaultData.importDefaultRssSources()
  Future<void> importDefaultRssSources() async {
    final db = await _db.database;
    if (db == null) return;

    try {
      // 删除默认RSS源（sourceGroup like 'legado'）
      await db.delete('rssSources', where: "sourceGroup LIKE 'legado'");

      // 从 assets/defaultData/rssSources.json 加载默认配置
      final defaultRssSources = await DefaultData.instance.rssSources;
      
      if (defaultRssSources.isNotEmpty) {
        final batch = db.batch();
        for (final source in defaultRssSources) {
          batch.insert(
            'rssSources',
            source.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        AppLog.instance.put('导入默认RSS源成功: ${defaultRssSources.length} 条');
      }
    } catch (e) {
      AppLog.instance.put('导入默认RSS源失败', error: e);
    }
  }
}

