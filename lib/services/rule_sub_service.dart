import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/rule_sub.dart';
import '../utils/app_log.dart';

/// 规则订阅服务
/// 参考项目：io.legado.app.data.dao.RuleSubDao
class RuleSubService extends BaseService {
  static final RuleSubService instance = RuleSubService._init();
  final AppDatabase _db = AppDatabase.instance;

  RuleSubService._init();

  /// 获取所有规则订阅
  Future<List<RuleSub>> getAllRuleSubs() async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'ruleSubs',
        orderBy: 'customOrder ASC',
      );
      return result.map((row) => RuleSub.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取规则订阅列表失败', error: e);
      return [];
    }
  }

  /// 根据类型获取规则订阅
  Future<List<RuleSub>> getRuleSubsByType(int type) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'ruleSubs',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'customOrder ASC',
      );
      return result.map((row) => RuleSub.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('根据类型获取规则订阅失败: $type', error: e);
      return [];
    }
  }

  /// 根据ID获取规则订阅
  Future<RuleSub?> getRuleSub(int id) async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      final result = await db.query(
        'ruleSubs',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return RuleSub.fromJson(_convertDbToJson(result.first));
    } catch (e) {
      AppLog.instance.put('获取规则订阅失败: $id', error: e);
      return null;
    }
  }

  /// 保存或更新规则订阅
  Future<bool> saveRuleSub(RuleSub ruleSub) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.insert(
        'ruleSubs',
        ruleSub.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('保存规则订阅失败: ${ruleSub.name}', error: e);
      return false;
    }
  }

  /// 删除规则订阅
  Future<bool> deleteRuleSub(int id) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete(
        'ruleSubs',
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除规则订阅失败: $id', error: e);
      return false;
    }
  }

  /// 更新规则订阅
  Future<bool> updateRuleSub(RuleSub ruleSub) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.update(
        'ruleSubs',
        ruleSub.toJson(),
        where: 'id = ?',
        whereArgs: [ruleSub.id],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('更新规则订阅失败: ${ruleSub.name}', error: e);
      return false;
    }
  }

  /// 更新最后更新时间
  Future<bool> updateLastUpdateTime(int id) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.update(
        'ruleSubs',
        {'update': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('更新规则订阅最后更新时间失败: $id', error: e);
      return false;
    }
  }

  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbRow) {
    return Map<String, dynamic>.from(dbRow);
  }
}

