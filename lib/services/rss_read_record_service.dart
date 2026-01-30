import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/rss_read_record.dart';
import '../utils/app_log.dart';

/// RSS阅读记录服务
/// 参考项目：io.legado.app.data.dao.RssReadRecordDao
class RssReadRecordService extends BaseService {
  static final RssReadRecordService instance = RssReadRecordService._init();
  final AppDatabase _db = AppDatabase.instance;

  RssReadRecordService._init();

  /// 插入阅读记录
  Future<bool> insertRecord(RssReadRecord record) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.insert(
        'rssReadRecords',
        record.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('插入RSS阅读记录失败: ${record.record}', error: e);
      return false;
    }
  }

  /// 记录RSS文章已读
  Future<bool> markAsRead(String origin, String link, {String? title}) async {
    final record = RssReadRecord(
      record: RssReadRecord.createRecord(origin, link),
      title: title,
      readTime: DateTime.now().millisecondsSinceEpoch,
      read: true,
    );
    return await insertRecord(record);
  }

  /// 检查RSS文章是否已读
  Future<bool> isRead(String origin, String link) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      final record = RssReadRecord.createRecord(origin, link);
      final result = await db.query(
        'rssReadRecords',
        where: 'record = ?',
        whereArgs: [record],
        limit: 1,
      );

      if (result.isEmpty) return false;
      final readRecord = RssReadRecord.fromJson(_convertDbToJson(result.first));
      return readRecord.read;
    } catch (e) {
      AppLog.instance.put('检查RSS阅读记录失败: $origin/$link', error: e);
      return false;
    }
  }

  /// 获取所有阅读记录
  Future<List<RssReadRecord>> getRecords({int limit = 100}) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'rssReadRecords',
        orderBy: 'readTime DESC',
        limit: limit,
      );
      return result.map((row) => RssReadRecord.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取RSS阅读记录失败', error: e);
      return [];
    }
  }

  /// 获取阅读记录数量
  Future<int> getRecordCount() async {
    final db = await _db.database;
    if (db == null) return 0;

    try {
      final result = await db.rawQuery('SELECT COUNT(1) as count FROM rssReadRecords');
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      AppLog.instance.put('获取RSS阅读记录数量失败', error: e);
      return 0;
    }
  }

  /// 清空所有阅读记录
  Future<bool> clearAllRecords() async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete('rssReadRecords');
      return true;
    } catch (e) {
      AppLog.instance.put('清空RSS阅读记录失败', error: e);
      return false;
    }
  }

  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbRow) {
    return Map<String, dynamic>.from(dbRow);
  }
}

