import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/http_tts.dart';
import '../utils/app_log.dart';
import '../utils/default_data.dart';

/// HTTP TTS服务
/// 参考项目：io.legado.app.data.dao.HttpTTSDao
class HttpTTSService extends BaseService {
  static final HttpTTSService instance = HttpTTSService._init();
  final AppDatabase _db = AppDatabase.instance;

  HttpTTSService._init();

  /// 获取所有HTTP TTS配置
  Future<List<HttpTTS>> getAllHttpTTS() async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.query('httpTTS');
      return result.map((row) => HttpTTS.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取HTTP TTS列表失败', error: e);
      return [];
    }
  }

  /// 根据ID获取HTTP TTS
  Future<HttpTTS?> getHttpTTS(int id) async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      final result = await db.query(
        'httpTTS',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return HttpTTS.fromJson(_convertDbToJson(result.first));
    } catch (e) {
      AppLog.instance.put('获取HTTP TTS失败: $id', error: e);
      return null;
    }
  }

  /// 保存或更新HTTP TTS
  Future<bool> saveHttpTTS(HttpTTS httpTTS) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.insert(
        'httpTTS',
        httpTTS.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('保存HTTP TTS失败: ${httpTTS.name}', error: e);
      return false;
    }
  }

  /// 删除HTTP TTS
  Future<bool> deleteHttpTTS(int id) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete(
        'httpTTS',
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除HTTP TTS失败: $id', error: e);
      return false;
    }
  }

  /// 更新最后更新时间
  Future<bool> updateLastUpdateTime(int id) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.update(
        'httpTTS',
        {'lastUpdateTime': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('更新HTTP TTS最后更新时间失败: $id', error: e);
      return false;
    }
  }

  /// 导入默认HTTP TTS配置
  /// 参考项目：DefaultData.importDefaultHttpTTS()
  Future<void> importDefaultHttpTTS() async {
    final db = await _db.database;
    if (db == null) return;

    try {
      // 删除默认配置（id < 0）
      await db.delete('httpTTS', where: 'id < 0');

      // 从 assets/defaultData/httpTTS.json 加载默认配置
      final defaultHttpTTS = await DefaultData.instance.httpTTS;
      
      if (defaultHttpTTS.isNotEmpty) {
        final batch = db.batch();
        for (final httpTTS in defaultHttpTTS) {
          batch.insert(
            'httpTTS',
            httpTTS.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        AppLog.instance.put('导入默认HTTP TTS配置成功: ${defaultHttpTTS.length} 条');
      }
    } catch (e) {
      AppLog.instance.put('导入默认HTTP TTS配置失败', error: e);
    }
  }

  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbRow) {
    return Map<String, dynamic>.from(dbRow);
  }
}

