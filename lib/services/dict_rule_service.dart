import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/dict_rule.dart';
import '../utils/default_data.dart';

/// 字典规则服务
class DictRuleService extends BaseService {
  static final DictRuleService instance = DictRuleService._init();
  DictRuleService._init();

  final AppDatabase _db = AppDatabase.instance;

  /// 获取所有规则
  Future<List<DictRule>> getAllRules() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <DictRule>[];
        
        final result = await db.query(
          'dictRules',
          orderBy: 'sortNumber ASC',
        );
        
        return result.map((json) => DictRule.fromJson(_convertDbToJson(json))).toList();
      },
      operationName: '获取所有字典规则',
      logError: true,
      defaultValue: <DictRule>[],
    );
  }

  /// 获取启用的规则
  Future<List<DictRule>> getEnabledRules() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <DictRule>[];
        
        final result = await db.query(
          'dictRules',
          where: 'enabled = 1',
          orderBy: 'sortNumber ASC',
        );
        
        return result.map((json) => DictRule.fromJson(_convertDbToJson(json))).toList();
      },
      operationName: '获取启用的字典规则',
      logError: true,
      defaultValue: <DictRule>[],
    );
  }

  /// 根据名称获取规则
  Future<DictRule?> getRuleByName(String name) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return null;
        
        final result = await db.query(
          'dictRules',
          where: 'name = ?',
          whereArgs: [name],
          limit: 1,
        );
    
        if (result.isEmpty) return null;
        return DictRule.fromJson(_convertDbToJson(result.first));
      },
      operationName: '根据名称获取字典规则',
      logError: true,
      defaultValue: null,
    );
  }

  /// 添加或更新规则
  Future<void> addOrUpdateRule(DictRule rule) async {
    final db = await _db.database;
    if (db == null) return;
    
    // 如果已存在同名规则，先删除
    final existing = await getRuleByName(rule.name);
    if (existing != null) {
      await db.delete('dictRules', where: 'name = ?', whereArgs: [rule.name]);
    }
    
    // 如果没有设置排序号，获取最大序号
    if (rule.sortNumber == 0) {
      final maxOrderResult = await db.rawQuery(
        'SELECT IFNULL(MAX(sortNumber), 0) as maxOrder FROM dictRules'
      );
      final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? 0;
      rule = rule.copyWith(sortNumber: maxOrder + 1);
    }
    
    await db.insert(
      'dictRules',
      _convertJsonToDb(rule.toJson()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新规则
  Future<int> updateRule(DictRule rule) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    return await db.update(
      'dictRules',
      _convertJsonToDb(rule.toJson()),
      where: 'name = ?',
      whereArgs: [rule.name],
    );
  }

  /// 删除规则
  Future<int> deleteRule(String name) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    return await db.delete(
      'dictRules',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  /// 批量删除规则
  Future<int> deleteRules(List<String> names) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    if (names.isEmpty) return 0;
    
    final placeholders = List.filled(names.length, '?').join(',');
    return await db.delete(
      'dictRules',
      where: 'name IN ($placeholders)',
      whereArgs: names,
    );
  }

  /// 批量启用/禁用规则
  Future<int> batchSetEnabled(List<String> names, bool enabled) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    if (names.isEmpty) return 0;
    
    final placeholders = List.filled(names.length, '?').join(',');
    return await db.update(
      'dictRules',
      {'enabled': enabled ? 1 : 0},
      where: 'name IN ($placeholders)',
      whereArgs: names,
    );
  }

  /// 更新排序
  Future<void> updateOrder(List<DictRule> rules) async {
    final db = await _db.database;
    if (db == null) return;
    
    final batch = db.batch();
    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i].copyWith(sortNumber: i + 1);
      batch.update(
        'dictRules',
        _convertJsonToDb(rule.toJson()),
        where: 'name = ?',
        whereArgs: [rule.name],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 导入规则列表
  Future<int> importRules(List<DictRule> rules) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    int count = 0;
    final batch = db.batch();
    
    for (final rule in rules) {
      // 检查是否已存在（根据名称）
      final existing = await getRuleByName(rule.name);
      
      if (existing == null) {
        // 获取最大序号
        final maxOrderResult = await db.rawQuery(
          'SELECT IFNULL(MAX(sortNumber), 0) as maxOrder FROM dictRules'
        );
        final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? 0;
        
        final ruleWithOrder = rule.copyWith(sortNumber: maxOrder + 1);
        batch.insert(
          'dictRules',
          _convertJsonToDb(ruleWithOrder.toJson()),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      } else {
        // 更新现有规则
        batch.update(
          'dictRules',
          _convertJsonToDb(rule.toJson()),
          where: 'name = ?',
          whereArgs: [rule.name],
        );
      }
    }
    
    await batch.commit(noResult: true);
    return count;
  }

  /// 导入默认规则
  Future<void> importDefaultRules() async {
    // 从 assets/defaultData/dictRules.json 加载默认规则
    final defaultRules = await DefaultData.instance.dictRules;
    await importRules(defaultRules);
  }

  /// 转换数据库JSON格式
  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbMap) {
    return {
      'name': dbMap['name'],
      'urlRule': dbMap['urlRule'],
      'showRule': dbMap['showRule'],
      'enabled': dbMap['enabled'],
      'sortNumber': dbMap['sortNumber'],
    };
  }

  /// 转换JSON为数据库格式
  Map<String, dynamic> _convertJsonToDb(Map<String, dynamic> json) {
    return {
      'name': json['name'],
      'urlRule': json['urlRule'] ?? '',
      'showRule': json['showRule'] ?? '',
      'enabled': json['enabled'] == true || json['enabled'] == 1 ? 1 : 0,
      'sortNumber': json['sortNumber'] ?? 0,
    };
  }
}

