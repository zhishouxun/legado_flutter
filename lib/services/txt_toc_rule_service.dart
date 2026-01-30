import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/txt_toc_rule.dart';
import '../utils/default_data.dart';

/// TXT目录规则服务
class TxtTocRuleService extends BaseService {
  static final TxtTocRuleService instance = TxtTocRuleService._init();
  TxtTocRuleService._init();

  final AppDatabase _db = AppDatabase.instance;

  /// 获取所有规则
  Future<List<TxtTocRule>> getAllRules() async {
    final db = await _db.database;
    if (db == null) return [];
    
    final result = await db.query(
      'txtTocRules',
      orderBy: 'serialNumber ASC',
    );
    
    return result.map((json) => TxtTocRule.fromJson(_convertDbToJson(json))).toList();
  }

  /// 获取启用的规则
  Future<List<TxtTocRule>> getEnabledRules() async {
    final db = await _db.database;
    if (db == null) return [];
    
    final result = await db.query(
      'txtTocRules',
      where: 'enable = 1',
      orderBy: 'serialNumber ASC',
    );
    
    return result.map((json) => TxtTocRule.fromJson(_convertDbToJson(json))).toList();
  }

  /// 根据ID获取规则
  Future<TxtTocRule?> getRuleById(int id) async {
    final db = await _db.database;
    if (db == null) return null;
    
    final result = await db.query(
      'txtTocRules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return TxtTocRule.fromJson(_convertDbToJson(result.first));
  }

  /// 添加规则
  Future<int> addRule(TxtTocRule rule) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    // 获取最大序号
    final maxOrderResult = await db.rawQuery(
      'SELECT IFNULL(MAX(serialNumber), 0) as maxOrder FROM txtTocRules'
    );
    final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? 0;
    
    final ruleWithOrder = rule.copyWith(serialNumber: maxOrder + 1);
    
    return await db.insert(
      'txtTocRules',
      _convertJsonToDb(ruleWithOrder.toJson()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新规则
  Future<int> updateRule(TxtTocRule rule) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    return await db.update(
      'txtTocRules',
      _convertJsonToDb(rule.toJson()),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  /// 删除规则
  Future<int> deleteRule(int id) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    return await db.delete(
      'txtTocRules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 批量删除规则
  Future<int> deleteRules(List<int> ids) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    if (ids.isEmpty) return 0;
    
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.delete(
      'txtTocRules',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// 批量启用/禁用规则
  Future<int> batchSetEnabled(List<int> ids, bool enabled) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    if (ids.isEmpty) return 0;
    
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.update(
      'txtTocRules',
      {'enable': enabled ? 1 : 0},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// 更新排序
  Future<void> updateOrder(List<TxtTocRule> rules) async {
    final db = await _db.database;
    if (db == null) return;
    
    final batch = db.batch();
    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i].copyWith(serialNumber: i + 1);
      batch.update(
        'txtTocRules',
        _convertJsonToDb(rule.toJson()),
        where: 'id = ?',
        whereArgs: [rule.id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 获取最小序号
  Future<int> getMinOrder() async {
    final db = await _db.database;
    if (db == null) return 0;
    
    final result = await db.rawQuery(
      'SELECT IFNULL(MIN(serialNumber), 0) as minOrder FROM txtTocRules'
    );
    return (result.first['minOrder'] as int?) ?? 0;
  }

  /// 获取最大序号
  Future<int> getMaxOrder() async {
    final db = await _db.database;
    if (db == null) return 0;
    
    final result = await db.rawQuery(
      'SELECT IFNULL(MAX(serialNumber), 0) as maxOrder FROM txtTocRules'
    );
    return (result.first['maxOrder'] as int?) ?? 0;
  }

  /// 转换数据库JSON格式
  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbMap) {
    return {
      'id': dbMap['id'],
      'name': dbMap['name'],
      'rule': dbMap['rule'],
      'example': dbMap['example'],
      'serialNumber': dbMap['serialNumber'],
      'enable': dbMap['enable'],
    };
  }

  /// 转换JSON为数据库格式
  Map<String, dynamic> _convertJsonToDb(Map<String, dynamic> json) {
    return {
      'id': json['id'],
      'name': json['name'],
      'rule': json['rule'],
      'example': json['example'],
      'serialNumber': json['serialNumber'],
      'enable': json['enable'] == true || json['enable'] == 1 ? 1 : 0,
    };
  }

  /// 导入规则列表
  Future<int> importRules(List<TxtTocRule> rules) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    int count = 0;
    final batch = db.batch();
    
    for (final rule in rules) {
      // 检查是否已存在（根据ID或名称+规则）
      final existing = await db.query(
        'txtTocRules',
        where: 'id = ? OR (name = ? AND rule = ?)',
        whereArgs: [rule.id, rule.name, rule.rule],
        limit: 1,
      );
      
      if (existing.isEmpty) {
        // 获取最大序号
        final maxOrderResult = await db.rawQuery(
          'SELECT IFNULL(MAX(serialNumber), 0) as maxOrder FROM txtTocRules'
        );
        final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? 0;
        
        final ruleWithOrder = rule.copyWith(serialNumber: maxOrder + 1);
        batch.insert(
          'txtTocRules',
          _convertJsonToDb(ruleWithOrder.toJson()),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      } else {
        // 更新现有规则
        batch.update(
          'txtTocRules',
          _convertJsonToDb(rule.toJson()),
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    }
    
    await batch.commit(noResult: true);
    return count;
  }

  /// 导入默认规则
  Future<void> importDefaultRules() async {
    // 从 assets/defaultData/txtTocRule.json 加载默认规则
    final defaultRules = await DefaultData.instance.txtTocRules;
    
    // 先删除默认规则（id < 0）
    final db = await _db.database;
    if (db != null) {
      await db.delete('txtTocRules', where: 'id < 0');
    }
    
    await importRules(defaultRules);
  }
}

