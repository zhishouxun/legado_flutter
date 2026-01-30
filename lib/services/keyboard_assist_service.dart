import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/keyboard_assist.dart';
import '../utils/app_log.dart';
import '../utils/default_data.dart';

/// 键盘辅助服务
/// 参考项目：io.legado.app.data.dao.KeyboardAssistsDao
class KeyboardAssistService extends BaseService {
  static final KeyboardAssistService instance = KeyboardAssistService._init();
  final AppDatabase _db = AppDatabase.instance;

  KeyboardAssistService._init();

  /// 获取所有键盘辅助
  Future<List<KeyboardAssist>> getAllKeyboardAssists() async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'keyboardAssists',
        orderBy: 'serialNo ASC',
      );
      return result.map((row) => KeyboardAssist.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取键盘辅助列表失败', error: e);
      return [];
    }
  }

  /// 根据类型获取键盘辅助
  Future<List<KeyboardAssist>> getKeyboardAssistsByType(int type) async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'keyboardAssists',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'serialNo ASC',
      );
      return result.map((row) => KeyboardAssist.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('根据类型获取键盘辅助失败: $type', error: e);
      return [];
    }
  }

  /// 根据类型和键获取键盘辅助
  Future<KeyboardAssist?> getKeyboardAssist(int type, String key) async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      final result = await db.query(
        'keyboardAssists',
        where: 'type = ? AND "key" = ?',
        whereArgs: [type, key],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return KeyboardAssist.fromJson(_convertDbToJson(result.first));
    } catch (e) {
      AppLog.instance.put('获取键盘辅助失败: $type/$key', error: e);
      return null;
    }
  }

  /// 保存或更新键盘辅助
  Future<bool> saveKeyboardAssist(KeyboardAssist keyboardAssist) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.insert(
        'keyboardAssists',
        keyboardAssist.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('保存键盘辅助失败: ${keyboardAssist.type}/${keyboardAssist.key}', error: e);
      return false;
    }
  }

  /// 批量保存键盘辅助
  Future<int> saveKeyboardAssists(List<KeyboardAssist> keyboardAssists) async {
    final db = await _db.database;
    if (db == null) return 0;

    if (keyboardAssists.isEmpty) return 0;

    try {
      final batch = db.batch();
      for (final keyboardAssist in keyboardAssists) {
        batch.insert(
          'keyboardAssists',
          keyboardAssist.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: false);
      return keyboardAssists.length;
    } catch (e) {
      AppLog.instance.put('批量保存键盘辅助失败', error: e);
      return 0;
    }
  }

  /// 删除键盘辅助
  Future<bool> deleteKeyboardAssist(int type, String key) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete(
        'keyboardAssists',
        where: 'type = ? AND "key" = ?',
        whereArgs: [type, key],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除键盘辅助失败: $type/$key', error: e);
      return false;
    }
  }

  /// 清空所有键盘辅助
  Future<bool> clearAllKeyboardAssists() async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete('keyboardAssists');
      return true;
    } catch (e) {
      AppLog.instance.put('清空键盘辅助失败', error: e);
      return false;
    }
  }

  /// 导入默认键盘辅助
  /// 参考项目：在数据库初始化时自动导入
  Future<void> importDefaultKeyboardAssists() async {
    final db = await _db.database;
    if (db == null) return;

    try {
      // 检查是否已有数据
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM keyboardAssists'),
      ) ?? 0;

      if (count == 0) {
        // 从 assets/defaultData/keyboardAssists.json 加载默认配置
        final defaultKeyboardAssists = await DefaultData.instance.keyboardAssists;
        
        if (defaultKeyboardAssists.isNotEmpty) {
          await saveKeyboardAssists(defaultKeyboardAssists);
          AppLog.instance.put('导入默认键盘辅助成功: ${defaultKeyboardAssists.length} 条');
        }
      }
    } catch (e) {
      AppLog.instance.put('导入默认键盘辅助失败', error: e);
    }
  }

  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbRow) {
    return Map<String, dynamic>.from(dbRow);
  }
}

