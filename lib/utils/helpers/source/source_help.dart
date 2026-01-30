import '../../../data/models/interfaces/base_source.dart';
import '../../../data/models/book_source.dart';
import '../../../data/models/rss_source.dart';
import '../../../core/constants/app_status.dart';
import '../../../services/source/book_source_service.dart';
import '../../../services/rss_service.dart';
import '../../../utils/eighteen_plus_filter.dart';
import '../../../utils/app_log.dart';
import '../../../utils/coroutine/coroutine.dart';
import '../../../utils/helpers/book_help.dart';
import '../../../data/database/app_database.dart';

/// 源帮助类
/// 参考项目：io.legado.app.help.source.SourceHelp
class SourceHelp {
  SourceHelp._();

  /// 获取源（根据 key）
  /// 参考项目：SourceHelp.getSource(key: String?)
  static Future<BaseSource?> getSource(String? key) async {
    if (key == null || key.isEmpty) return null;

    // 先尝试从书源服务获取
    try {
      final bookSource = await BookSourceService.instance.getBookSourceByUrl(key);
      if (bookSource != null) return bookSource as BaseSource;
    } catch (e) {
      // 忽略错误
    }

    // 再尝试从 RSS 服务获取
    try {
      final rssSource = await RssService.instance.getRssSourceByUrl(key);
      if (rssSource != null) return rssSource as BaseSource;
    } catch (e) {
      // 忽略错误
    }

    return null;
  }

  /// 获取源（根据 key 和类型）
  /// 参考项目：SourceHelp.getSource(key: String?, type: Int)
  static Future<BaseSource?> getSourceByType(String? key, int type) async {
    if (key == null || key.isEmpty) return null;

    switch (type) {
      case AppStatus.sourceTypeBook:
        final bookSource = await BookSourceService.instance.getBookSourceByUrl(key);
        return bookSource as BaseSource?;
      case AppStatus.sourceTypeRss:
        final rssSource = await RssService.instance.getRssSourceByUrl(key);
        return rssSource as BaseSource?;
      default:
        return null;
    }
  }

  /// 删除源
  /// 参考项目：SourceHelp.deleteSource(key: String, type: Int)
  static Future<void> deleteSource(String key, int type) async {
    switch (type) {
      case AppStatus.sourceTypeBook:
        await deleteBookSource(key);
        break;
      case AppStatus.sourceTypeRss:
        await deleteRssSource(key);
        break;
    }
  }

  /// 删除书源（内部方法）
  /// 参考项目：SourceHelp.deleteBookSourceInternal(key: String)
  static Future<void> _deleteBookSourceInternal(String key) async {
    try {
      // 删除书源
      await BookSourceService.instance.deleteBookSource(key);
      
      // 清除源变量缓存
      await BookHelp.clearCacheForSource(key);
    } catch (e) {
      AppLog.instance.put('删除书源失败: $key', error: e);
    }
  }

  /// 删除书源
  /// 参考项目：SourceHelp.deleteBookSource(key: String)
  static Future<void> deleteBookSource(String key) async {
    await _deleteBookSourceInternal(key);
    // 清除源变量缓存
    await BookHelp.clearInvalidCache();
  }

  /// 批量删除书源
  /// 参考项目：SourceHelp.deleteBookSources(sources: List<BookSource>)
  static Future<void> deleteBookSources(List<BookSource> sources) async {
    final db = await AppDatabase.instance.database;
    if (db == null) return;

    try {
      await db.transaction((txn) async {
        for (final source in sources) {
          await _deleteBookSourceInternal(source.bookSourceUrl);
        }
      });
      // 清除源变量缓存
      await BookHelp.clearInvalidCache();
    } catch (e) {
      AppLog.instance.put('批量删除书源失败', error: e);
    }
  }

  /// 删除 RSS 源（内部方法）
  /// 参考项目：SourceHelp.deleteRssSourceInternal(key: String)
  static Future<void> _deleteRssSourceInternal(String key) async {
    try {
      // 删除 RSS 源
      await RssService.instance.deleteRssSource(key);
      
      // 清除源变量缓存
      await BookHelp.clearCacheForSource(key);
    } catch (e) {
      AppLog.instance.put('删除RSS源失败: $key', error: e);
    }
  }

  /// 删除 RSS 源
  /// 参考项目：SourceHelp.deleteRssSource(key: String)
  static Future<void> deleteRssSource(String key) async {
    await _deleteRssSourceInternal(key);
    // 清除源变量缓存
    await BookHelp.clearInvalidCache();
  }

  /// 批量删除 RSS 源
  /// 参考项目：SourceHelp.deleteRssSources(sources: List<RssSource>)
  static Future<void> deleteRssSources(List<RssSource> sources) async {
    final db = await AppDatabase.instance.database;
    if (db == null) return;

    try {
      await db.transaction((txn) async {
        for (final source in sources) {
          await _deleteRssSourceInternal(source.sourceUrl);
        }
      });
      // 清除源变量缓存
      await BookHelp.clearInvalidCache();
    } catch (e) {
      AppLog.instance.put('批量删除RSS源失败', error: e);
    }
  }

  /// 启用/禁用源
  /// 参考项目：SourceHelp.enableSource(key: String, type: Int, enable: Boolean)
  static Future<void> enableSource(String key, int type, bool enable) async {
    switch (type) {
      case AppStatus.sourceTypeBook:
        await BookSourceService.instance.setBookSourceEnabled(key, enable);
        break;
      case AppStatus.sourceTypeRss:
        await RssService.instance.updateRssSourceEnabled(key, enable);
        break;
    }
  }

  /// 插入书源（带18+过滤）
  /// 参考项目：SourceHelp.insertBookSource(vararg bookSources: BookSource)
  static Future<int> insertBookSources(List<BookSource> bookSources) async {
    // 过滤18+网址
    final filtered = await EighteenPlusFilter.instance.filter18Plus<BookSource>(
      items: bookSources,
      getUrl: (source) => source.bookSourceUrl,
      getName: (source) => source.bookSourceName,
    );

    // 插入非18+的书源
    int insertedCount = 0;
    for (final source in filtered['filtered'] ?? []) {
      try {
        await BookSourceService.instance.addBookSource(source);
        insertedCount++;
      } catch (e) {
        AppLog.instance.put('插入书源失败: ${source.bookSourceName}', error: e);
      }
    }

    // 异步调整排序序号
    Coroutine.async(() async {
      await adjustSortNumber();
    }).start();

    return insertedCount;
  }

  /// 插入 RSS 源（带18+过滤）
  /// 参考项目：SourceHelp.insertRssSource(vararg rssSources: RssSource)
  static Future<int> insertRssSources(List<RssSource> rssSources) async {
    // 过滤18+网址
    final filtered = await EighteenPlusFilter.instance.filter18Plus<RssSource>(
      items: rssSources,
      getUrl: (source) => source.sourceUrl,
      getName: (source) => source.sourceName,
    );

    // 插入非18+的RSS源
    int insertedCount = 0;
    for (final source in filtered['filtered'] ?? []) {
      try {
        await RssService.instance.addOrUpdateRssSource(source);
        insertedCount++;
      } catch (e) {
        AppLog.instance.put('插入RSS源失败: ${source.sourceName}', error: e);
      }
    }

    return insertedCount;
  }

  /// 调整排序序号
  /// 参考项目：SourceHelp.adjustSortNumber()
  static Future<void> adjustSortNumber() async {
    try {
      final db = await AppDatabase.instance.database;
      if (db == null) return;

      // 检查是否需要调整
      final maxOrderResult = await db.rawQuery(
        'SELECT MAX(customOrder) as maxOrder FROM book_sources',
      );
      final minOrderResult = await db.rawQuery(
        'SELECT MIN(customOrder) as minOrder FROM book_sources',
      );
      final duplicateResult = await db.rawQuery(
        'SELECT customOrder, COUNT(*) as count FROM book_sources GROUP BY customOrder HAVING count > 1',
      );

      final maxOrder = maxOrderResult.first['maxOrder'] as int? ?? 0;
      final minOrder = minOrderResult.first['minOrder'] as int? ?? 0;
      final hasDuplicate = duplicateResult.isNotEmpty;

      if (maxOrder > 99999 || minOrder < -99999 || hasDuplicate) {
        // 需要调整排序序号
        final sources = await BookSourceService.instance.getAllBookSources();
        await db.transaction((txn) async {
          for (int i = 0; i < sources.length; i++) {
            await txn.update(
              'book_sources',
              {'customOrder': i},
              where: 'bookSourceUrl = ?',
              whereArgs: [sources[i].bookSourceUrl],
            );
          }
        });
        AppLog.instance.put('已调整书源排序序号: ${sources.length} 个');
      }
    } catch (e) {
      AppLog.instance.put('调整排序序号失败', error: e);
    }
  }
}

