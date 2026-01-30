import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/server.dart';
import '../utils/app_log.dart';

/// 服务器配置服务
/// 参考项目：io.legado.app.data.dao.ServerDao
class ServerService extends BaseService {
  static final ServerService instance = ServerService._init();
  final AppDatabase _db = AppDatabase.instance;

  ServerService._init();

  /// 获取所有服务器
  Future<List<Server>> getAllServers() async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query(
        'servers',
        orderBy: 'sortNumber ASC',
      );
      return result.map((row) => Server.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取服务器列表失败', error: e);
      return [];
    }
  }

  /// 根据ID获取服务器
  Future<Server?> getServer(int id) async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      final result = await db.query(
        'servers',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return Server.fromJson(_convertDbToJson(result.first));
    } catch (e) {
      AppLog.instance.put('获取服务器失败: $id', error: e);
      return null;
    }
  }

  /// 保存或更新服务器
  Future<bool> saveServer(Server server) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.insert(
        'servers',
        server.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('保存服务器失败: ${server.name}', error: e);
      return false;
    }
  }

  /// 删除服务器
  Future<bool> deleteServer(int id) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete(
        'servers',
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除服务器失败: $id', error: e);
      return false;
    }
  }

  /// 更新服务器排序
  Future<bool> updateServerSort(int id, int sortNumber) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.update(
        'servers',
        {'sortNumber': sortNumber},
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('更新服务器排序失败: $id', error: e);
      return false;
    }
  }

  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbRow) {
    return Map<String, dynamic>.from(dbRow);
  }
}

