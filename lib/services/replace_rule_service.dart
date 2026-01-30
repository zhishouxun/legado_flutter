import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../core/exceptions/app_exceptions.dart';
import '../data/database/app_database.dart';
import '../data/models/replace_rule.dart';
import '../utils/app_log.dart';
import '../utils/replace_analyzer.dart';

/// 替换规则服务
class ReplaceRuleService extends BaseService {
  static final ReplaceRuleService instance = ReplaceRuleService._init();
  ReplaceRuleService._init();

  final AppDatabase _db = AppDatabase.instance;

  /// 获取所有规则
  Future<List<ReplaceRule>> getAllRules() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <ReplaceRule>[];
        
        final result = await db.query(
          'replaceRules',
          orderBy: 'sortNumber ASC',
        );
        
        return result.map((json) => ReplaceRule.fromJson(_convertDbToJson(json))).toList();
      },
      operationName: '获取所有替换规则',
      logError: true,
      defaultValue: <ReplaceRule>[],
    );
  }

  /// 获取启用的规则
  Future<List<ReplaceRule>> getEnabledRules() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <ReplaceRule>[];
        
        final result = await db.query(
          'replaceRules',
          where: 'enabled = 1',
          orderBy: 'sortNumber ASC',
        );
        
        return result.map((json) => ReplaceRule.fromJson(_convertDbToJson(json))).toList();
      },
      operationName: '获取启用的替换规则',
      logError: true,
      defaultValue: <ReplaceRule>[],
    );
  }

  /// 根据ID获取规则
  Future<ReplaceRule?> getRuleById(int id) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return null;
        
        final result = await db.query(
          'replaceRules',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
    
        if (result.isEmpty) return null;
        return ReplaceRule.fromJson(_convertDbToJson(result.first));
      },
      operationName: '根据ID获取替换规则',
      logError: true,
      defaultValue: null,
    );
  }

  /// 根据名称获取规则（兼容旧版本）
  Future<ReplaceRule?> getRuleByName(String name) async {
    final db = await _db.database;
    if (db == null) return null;
    
    final result = await db.query(
      'replaceRules',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return ReplaceRule.fromJson(_convertDbToJson(result.first));
  }

  /// 根据分组获取规则
  Future<List<ReplaceRule>> getRulesByGroup(String? group) async {
    final db = await _db.database;
    if (db == null) return [];
    
    final result = await db.query(
      'replaceRules',
      where: group == null ? '"group" IS NULL' : '"group" = ?',
      whereArgs: group == null ? [] : [group],
      orderBy: 'sortNumber ASC',
    );
    
    return result.map((json) => ReplaceRule.fromJson(_convertDbToJson(json))).toList();
  }

  /// 添加或更新规则
  Future<void> addOrUpdateRule(ReplaceRule rule) async {
    final db = await _db.database;
    if (db == null) return;
    
    // 如果没有设置排序号，获取最大序号
    if (rule.sortNumber == 0) {
      final maxOrderResult = await db.rawQuery(
        'SELECT IFNULL(MAX(sortNumber), 0) as maxOrder FROM replaceRules'
      );
      final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? 0;
      rule = rule.copyWith(sortNumber: maxOrder + 1);
    }
    
    await db.insert(
      'replaceRules',
      _convertJsonToDb(rule.toJson()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新规则
  Future<int> updateRule(ReplaceRule rule) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    return await db.update(
      'replaceRules',
      _convertJsonToDb(rule.toJson()),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  /// 删除规则（根据ID）
  Future<int> deleteRuleById(int id) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    return await db.delete(
      'replaceRules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除规则（根据名称，兼容旧版本）
  Future<int> deleteRule(String name) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    final rule = await getRuleByName(name);
    if (rule != null) {
      return await deleteRuleById(rule.id);
    }
    return 0;
  }

  /// 批量删除规则（根据ID）
  Future<int> deleteRulesByIds(List<int> ids) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    if (ids.isEmpty) return 0;
    
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.delete(
      'replaceRules',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// 批量删除规则（根据名称，兼容旧版本）
  Future<int> deleteRules(List<String> names) async {
    if (names.isEmpty) return 0;
    
    final ids = <int>[];
    for (final name in names) {
      final rule = await getRuleByName(name);
      if (rule != null) {
        ids.add(rule.id);
      }
    }
    
    return await deleteRulesByIds(ids);
  }

  /// 批量启用/禁用规则（根据ID）
  Future<int> batchSetEnabledByIds(List<int> ids, bool enabled) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    if (ids.isEmpty) return 0;
    
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.update(
      'replaceRules',
      {'enabled': enabled ? 1 : 0},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// 批量启用/禁用规则（根据名称，兼容旧版本）
  Future<int> batchSetEnabled(List<String> names, bool enabled) async {
    if (names.isEmpty) return 0;
    
    final ids = <int>[];
    for (final name in names) {
      final rule = await getRuleByName(name);
      if (rule != null) {
        ids.add(rule.id);
      }
    }
    
    return await batchSetEnabledByIds(ids, enabled);
  }

  /// 获取所有分组
  Future<List<String>> getAllGroups() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <String>[];
        
        final result = await db.rawQuery(
          'SELECT DISTINCT "group" FROM replaceRules WHERE "group" IS NOT NULL AND "group" != "" ORDER BY "group" ASC',
        );
        
        return result
            .map((row) => row['group'] as String?)
            .where((group) => group != null && group.isNotEmpty)
            .cast<String>()
            .toList();
      },
      operationName: '获取所有分组',
      logError: true,
      defaultValue: <String>[],
    );
  }

  /// 更新分组名称（批量更新该分组下所有规则的分组名）
  Future<int> updateGroupName(String oldGroup, String newGroup) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return 0;
        
        return await db.update(
          'replaceRules',
          {'group': newGroup},
          where: '"group" = ?',
          whereArgs: [oldGroup],
        );
      },
      operationName: '更新分组名称',
      logError: true,
      defaultValue: 0,
    );
  }

  /// 删除分组（将该分组下所有规则的分组设为null）
  Future<int> deleteGroup(String group) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return 0;
        
        return await db.update(
          'replaceRules',
          {'group': null},
          where: '"group" = ?',
          whereArgs: [group],
        );
      },
      operationName: '删除分组',
      logError: true,
      defaultValue: 0,
    );
  }

  /// 将规则置顶
  Future<void> moveToTop(ReplaceRule rule) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return;
        
        // 获取当前最小排序号
        final minOrderResult = await db.rawQuery(
          'SELECT IFNULL(MIN(sortNumber), 0) as minOrder FROM replaceRules',
        );
        final minOrder = (minOrderResult.first['minOrder'] as int?) ?? 0;
        
        // 将规则排序号设为最小排序号-1
        await db.update(
          'replaceRules',
          {'sortNumber': minOrder - 1},
          where: 'id = ?',
          whereArgs: [rule.id],
        );
      },
      operationName: '置顶规则',
      logError: true,
    );
  }

  /// 将规则置底
  Future<void> moveToBottom(ReplaceRule rule) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return;
        
        // 获取当前最大排序号
        final maxOrderResult = await db.rawQuery(
          'SELECT IFNULL(MAX(sortNumber), 0) as maxOrder FROM replaceRules',
        );
        final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? 0;
        
        // 将规则排序号设为最大排序号+1
        await db.update(
          'replaceRules',
          {'sortNumber': maxOrder + 1},
          where: 'id = ?',
          whereArgs: [rule.id],
        );
      },
      operationName: '置底规则',
      logError: true,
    );
  }

  /// 批量置顶
  Future<void> batchMoveToTop(List<int> ids) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return;
        if (ids.isEmpty) return;
        
        // 获取当前最小排序号
        final minOrderResult = await db.rawQuery(
          'SELECT IFNULL(MIN(sortNumber), 0) as minOrder FROM replaceRules',
        );
        final minOrder = (minOrderResult.first['minOrder'] as int?) ?? 0;
        
        // 批量更新排序号
        final placeholders = List.filled(ids.length, '?').join(',');
        await db.update(
          'replaceRules',
          {'sortNumber': minOrder - ids.length},
          where: 'id IN ($placeholders)',
          whereArgs: ids,
        );
        
        // 重新排序，确保顺序正确
        await _reorderAfterBatchTop(ids, minOrder - ids.length);
      },
      operationName: '批量置顶',
      logError: true,
    );
  }

  /// 批量置底
  Future<void> batchMoveToBottom(List<int> ids) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return;
        if (ids.isEmpty) return;
        
        // 获取当前最大排序号
        final maxOrderResult = await db.rawQuery(
          'SELECT IFNULL(MAX(sortNumber), 0) as maxOrder FROM replaceRules',
        );
        final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? 0;
        
        // 批量更新排序号
        final placeholders = List.filled(ids.length, '?').join(',');
        await db.update(
          'replaceRules',
          {'sortNumber': maxOrder + ids.length},
          where: 'id IN ($placeholders)',
          whereArgs: ids,
        );
        
        // 重新排序，确保顺序正确
        await _reorderAfterBatchBottom(ids, maxOrder + 1);
      },
      operationName: '批量置底',
      logError: true,
    );
  }

  /// 批量置顶后重新排序
  Future<void> _reorderAfterBatchTop(List<int> ids, int startOrder) async {
    final db = await _db.database;
    if (db == null) return;
    
    final batch = db.batch();
    for (var i = 0; i < ids.length; i++) {
      batch.update(
        'replaceRules',
        {'sortNumber': startOrder + i},
        where: 'id = ?',
        whereArgs: [ids[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 批量置底后重新排序
  Future<void> _reorderAfterBatchBottom(List<int> ids, int startOrder) async {
    final db = await _db.database;
    if (db == null) return;
    
    final batch = db.batch();
    for (var i = 0; i < ids.length; i++) {
      batch.update(
        'replaceRules',
        {'sortNumber': startOrder + i},
        where: 'id = ?',
        whereArgs: [ids[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 更新排序
  Future<void> updateOrder(List<ReplaceRule> rules) async {
    final db = await _db.database;
    if (db == null) return;
    
    final batch = db.batch();
    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i].copyWith(sortNumber: i + 1);
      batch.update(
        'replaceRules',
        _convertJsonToDb(rule.toJson()),
        where: 'id = ?',
        whereArgs: [rule.id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 导入规则列表
  Future<int> importRules(List<ReplaceRule> rules) async {
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
          'SELECT IFNULL(MAX(sortNumber), 0) as maxOrder FROM replaceRules'
        );
        final maxOrder = (maxOrderResult.first['maxOrder'] as int?) ?? 0;
        
        final ruleWithOrder = rule.copyWith(sortNumber: maxOrder + 1);
        batch.insert(
          'replaceRules',
          _convertJsonToDb(ruleWithOrder.toJson()),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      } else {
        // 更新现有规则
        batch.update(
          'replaceRules',
          _convertJsonToDb(rule.toJson()),
          where: 'name = ?',
          whereArgs: [rule.name],
        );
      }
    }
    
    await batch.commit(noResult: true);
    return count;
  }

  /// 根据作用范围获取启用的规则（用于正文）
  Future<List<ReplaceRule>> getEnabledRulesByContentScope(String bookName, String bookOrigin) async {
    final db = await _db.database;
    if (db == null) return [];
    
    // 查询条件：启用 && 作用于正文 && (作用范围包含书籍名称或来源，或作用范围为空) && (排除范围不包含书籍名称和来源，或排除范围为空)
    final result = await db.rawQuery('''
      SELECT * FROM replaceRules 
      WHERE enabled = 1 AND scopeContent = 1
      AND (scope LIKE '%' || ? || '%' OR scope LIKE '%' || ? || '%' OR scope IS NULL OR scope = '')
      AND (excludeScope IS NULL OR (excludeScope NOT LIKE '%' || ? || '%' AND excludeScope NOT LIKE '%' || ? || '%'))
      ORDER BY sortNumber ASC
    ''', [bookName, bookOrigin, bookName, bookOrigin]);
    
    return result.map((json) => ReplaceRule.fromJson(_convertDbToJson(json))).toList();
  }

  /// 根据作用范围获取启用的规则（用于标题）
  Future<List<ReplaceRule>> getEnabledRulesByTitleScope(String bookName, String bookOrigin) async {
    final db = await _db.database;
    if (db == null) return [];
    
    // 查询条件：启用 && 作用于标题 && (作用范围包含书籍名称或来源，或作用范围为空) && (排除范围不包含书籍名称和来源，或排除范围为空)
    final result = await db.rawQuery('''
      SELECT * FROM replaceRules 
      WHERE enabled = 1 AND scopeTitle = 1
      AND (scope LIKE '%' || ? || '%' OR scope LIKE '%' || ? || '%' OR scope IS NULL OR scope = '')
      AND (excludeScope IS NULL OR (excludeScope NOT LIKE '%' || ? || '%' AND excludeScope NOT LIKE '%' || ? || '%'))
      ORDER BY sortNumber ASC
    ''', [bookName, bookOrigin, bookName, bookOrigin]);
    
    return result.map((json) => ReplaceRule.fromJson(_convertDbToJson(json))).toList();
  }

  /// 应用替换规则到文本
  /// 按照排序顺序应用所有启用的规则
  /// 参考项目：ContentProcessor.getContent 中的替换规则应用逻辑
  /// 支持超时机制，防止正则表达式执行时间过长
  Future<String> applyRules(String text, {List<ReplaceRule>? rules}) async {
    final rulesToApply = rules ?? await getEnabledRules();
    
    String result = text;
    for (final rule in rulesToApply) {
      if (!rule.isValid()) continue;
      
      try {
        String tmp;
        if (rule.isRegex) {
          // 正则表达式替换（带超时机制）
          try {
            tmp = await _applyRegexReplaceWithTimeout(
              result,
              rule.pattern,
              rule.replacement,
              rule.getValidTimeoutMillisecond(),
            );
          } on RegexTimeoutException catch (e) {
            // 超时后自动禁用规则（参考项目逻辑）
            final updatedRule = rule.copyWith(enabled: false);
            await updateRule(updatedRule);
            AppLog.instance.put('正则替换超时，已禁用规则: ${rule.name}, 错误: ${e.message}');
            // 跳过该规则
            continue;
          } on TimeoutException catch (e) {
            // 兼容处理：将 TimeoutException 转换为 RegexTimeoutException
            final updatedRule = rule.copyWith(enabled: false);
            await updateRule(updatedRule);
            AppLog.instance.put('正则替换超时，已禁用规则: ${rule.name}, 错误: ${e.message}');
            // 跳过该规则
            continue;
          }
        } else {
          // 普通文本替换
          tmp = result.replaceAll(rule.pattern, rule.replacement);
        }
        
        // 只有内容发生变化时才更新（参考项目逻辑）
        if (result != tmp) {
          result = tmp;
        }
      } catch (e) {
        // 如果替换失败（正则表达式错误等），跳过该规则
        // 参考项目：记录错误但不自动禁用（可能需要用户手动处理）
        continue;
      }
    }
    
    return result;
  }

  /// 应用正则替换（带超时机制）
  /// 参考项目：ReplaceRule.getValidTimeoutMillisecond 和超时处理
  /// 注意：Dart的正则替换是同步的，无法真正实现超时
  /// 这里使用compute在isolate中执行，但compute本身不支持超时
  /// 参考项目使用Java的Pattern.compile和超时机制，Flutter需要其他方案
  /// 当前实现：使用Future.timeout包装，但实际超时检测有限
  Future<String> _applyRegexReplaceWithTimeout(
    String text,
    String pattern,
    String replacement,
    int timeoutMs,
  ) async {
    try {
      // 使用 Future.timeout 实现超时机制
      // 注意：由于Dart的正则替换是同步的，真正的超时检测需要isolate支持
      return await Future<String>(() {
        final regex = RegExp(pattern, multiLine: true);
        return text.replaceAll(regex, replacement);
      }).timeout(
        Duration(milliseconds: timeoutMs),
        onTimeout: () {
          // 超时后抛出 RegexTimeoutException
          throw RegexTimeoutException('正则替换超时: $pattern (超时时间: ${timeoutMs}ms)');
        },
      );
    } catch (e) {
      // 如果是超时异常，重新抛出
      if (e is TimeoutException) {
        rethrow;
      }
      // 其他异常（如正则表达式错误），也抛出
      throw Exception('正则替换失败: $pattern, 错误: $e');
    }
  }

  /// 导入默认规则
  Future<void> importDefaultRules() async {
    // 默认规则列表（参考参考项目的默认规则）
    final defaultRules = [
      ReplaceRule(
        name: '去除多余空行',
        pattern: r'\n\s*\n',
        replacement: '\n',
        sortNumber: 1,
        enabled: true,
      ),
      ReplaceRule(
        name: '去除行首行尾空格',
        pattern: r'^\s+|\s+$',
        replacement: '',
        sortNumber: 2,
        enabled: true,
      ),
      ReplaceRule(
        name: '去除HTML标签',
        pattern: r'<[^>]+>',
        replacement: '',
        sortNumber: 3,
        enabled: false, // 默认禁用，因为可能影响某些内容
      ),
    ];
    
    await importRules(defaultRules);
  }

  /// 从 JSON 字符串解析替换规则
  /// 参考项目：ReplaceAnalyzer.jsonToReplaceRule()
  ///
  /// [json] JSON 字符串
  /// 返回解析后的替换规则，如果解析失败返回 null
  ReplaceRule? jsonToReplaceRule(String json) {
    return ReplaceAnalyzer.jsonToReplaceRule(json);
  }

  /// 从 JSON 字符串解析替换规则列表
  /// 参考项目：ReplaceAnalyzer.jsonToReplaceRules()
  ///
  /// [json] JSON 字符串（数组格式）
  /// 返回解析后的替换规则列表
  List<ReplaceRule> jsonToReplaceRules(String json) {
    return ReplaceAnalyzer.jsonToReplaceRules(json);
  }

  /// 转换数据库JSON格式
  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbMap) {
    return {
      'id': dbMap['id'],
      'name': dbMap['name'],
      'pattern': dbMap['pattern'],
      'replacement': dbMap['replacement'],
      'enabled': dbMap['enabled'],
      'sortNumber': dbMap['sortNumber'],
      'group': dbMap['group'],
      'scope': dbMap['scope'],
      'scopeTitle': dbMap['scopeTitle'],
      'scopeContent': dbMap['scopeContent'],
      'excludeScope': dbMap['excludeScope'],
      'isRegex': dbMap['isRegex'],
      'timeoutMillisecond': dbMap['timeoutMillisecond'],
    };
  }

  /// 转换JSON为数据库格式
  Map<String, dynamic> _convertJsonToDb(Map<String, dynamic> json) {
    return {
      'id': json['id'],
      'name': json['name'] ?? '',
      'pattern': json['pattern'] ?? '',
      'replacement': json['replacement'] ?? '',
      'enabled': json['enabled'] == true || json['enabled'] == 1 ? 1 : 0,
      'sortNumber': json['sortNumber'] ?? 0,
      'group': json['group'],
      'scope': json['scope'],
      'scopeTitle': json['scopeTitle'] == true || json['scopeTitle'] == 1 ? 1 : 0,
      'scopeContent': json['scopeContent'] == true || json['scopeContent'] == 1 || json['scopeContent'] == null ? 1 : 0,
      'excludeScope': json['excludeScope'],
      'isRegex': json['isRegex'] == true || json['isRegex'] == 1 || json['isRegex'] == null ? 1 : 0,
      'timeoutMillisecond': json['timeoutMillisecond'] ?? 3000,
    };
  }
}

