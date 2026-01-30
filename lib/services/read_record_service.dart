import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/read_record_entity.dart';
import '../data/models/read_record.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 阅读记录服务
/// 参考项目：ReadRecordDao.kt
class ReadRecordService extends BaseService {
  static final ReadRecordService instance = ReadRecordService._init();
  final AppDatabase _db = AppDatabase.instance;
  String? _deviceId;

  ReadRecordService._init();

  /// 获取设备ID
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'ios-unknown';
      } else {
        // 其他平台使用包名
        final packageInfo = await PackageInfo.fromPlatform();
        _deviceId = packageInfo.packageName;
      }
    } catch (e) {
      _deviceId = 'unknown';
    }
    
    return _deviceId ?? 'unknown';
  }

  /// 获取所有阅读记录
  Future<List<ReadRecordEntity>> getAllRecords() async {
    final db = await _db.database;
    if (db == null) return [];
    
    final result = await db.query('readRecord');
    return result.map((json) => ReadRecordEntity.fromMap(json)).toList();
  }

  /// 获取所有阅读记录统计（按书名分组）
  Future<List<ReadRecordShow>> getAllShow() async {
    final db = await _db.database;
    if (db == null) return [];
    
    final result = await db.rawQuery('''
      SELECT 
        bookName, 
        SUM(readTime) as readTime, 
        MAX(lastRead) as lastRead 
      FROM readRecord 
      GROUP BY bookName 
      ORDER BY bookName
    ''');
    
    return result.map((json) {
      return ReadRecordShow(
        bookName: json['bookName'] as String,
        readTime: json['readTime'] as int? ?? 0,
        lastRead: json['lastRead'] as int? ?? 0,
      );
    }).toList();
  }

  /// 获取总阅读时长
  Future<int> getAllTime() async {
    final db = await _db.database;
    if (db == null) return 0;
    
    final result = await db.rawQuery('SELECT SUM(readTime) as totalTime FROM readRecord');
    if (result.isEmpty || result[0]['totalTime'] == null) {
      return 0;
    }
    return result[0]['totalTime'] as int? ?? 0;
  }

  /// 搜索阅读记录
  Future<List<ReadRecordShow>> search(String searchKey) async {
    final db = await _db.database;
    if (db == null) return [];
    
    final result = await db.rawQuery('''
      SELECT 
        bookName, 
        SUM(readTime) as readTime, 
        MAX(lastRead) as lastRead 
      FROM readRecord 
      WHERE bookName LIKE ?
      GROUP BY bookName 
      ORDER BY bookName
    ''', ['%$searchKey%']);
    
    return result.map((json) {
      return ReadRecordShow(
        bookName: json['bookName'] as String,
        readTime: json['readTime'] as int? ?? 0,
        lastRead: json['lastRead'] as int? ?? 0,
      );
    }).toList();
  }

  /// 获取指定书籍的阅读时长
  Future<int> getReadTime(String bookName) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    final result = await db.rawQuery(
      'SELECT SUM(readTime) as totalTime FROM readRecord WHERE bookName = ?',
      [bookName],
    );
    
    if (result.isEmpty || result[0]['totalTime'] == null) {
      return 0;
    }
    return result[0]['totalTime'] as int? ?? 0;
  }

  /// 获取指定设备和书籍的阅读时长
  Future<int> getReadTimeByDevice(String deviceId, String bookName) async {
    final db = await _db.database;
    if (db == null) return 0;
    
    final result = await db.rawQuery(
      'SELECT readTime FROM readRecord WHERE deviceId = ? AND bookName = ?',
      [deviceId, bookName],
    );
    
    if (result.isEmpty || result[0]['readTime'] == null) {
      return 0;
    }
    return result[0]['readTime'] as int? ?? 0;
  }

  /// 插入或更新阅读记录
  Future<void> insertOrUpdate(ReadRecordEntity record) async {
    final db = await _db.database;
    if (db == null) return;
    
    await db.insert(
      'readRecord',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 增加阅读时长
  /// [bookName] 书名
  /// [readTime] 增加的阅读时长（毫秒）
  Future<void> addReadTime(String bookName, int readTime) async {
    if (readTime <= 0) return;
    
    final deviceId = await _getDeviceId();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 获取现有记录
    final existing = await getReadTimeByDevice(deviceId, bookName);
    
    // 创建或更新记录
    final record = ReadRecordEntity(
      deviceId: deviceId,
      bookName: bookName,
      readTime: existing + readTime,
      lastRead: now,
    );
    
    await insertOrUpdate(record);
  }

  /// 更新最后阅读时间
  Future<void> updateLastRead(String bookName) async {
    final deviceId = await _getDeviceId();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 获取现有记录
    final existing = await getReadTimeByDevice(deviceId, bookName);
    
    // 更新记录
    final record = ReadRecordEntity(
      deviceId: deviceId,
      bookName: bookName,
      readTime: existing,
      lastRead: now,
    );
    
    await insertOrUpdate(record);
  }

  /// 删除阅读记录
  Future<void> delete(ReadRecordEntity record) async {
    final db = await _db.database;
    if (db == null) return;
    
    await db.delete(
      'readRecord',
      where: 'deviceId = ? AND bookName = ?',
      whereArgs: [record.deviceId, record.bookName],
    );
  }

  /// 清除所有阅读记录
  Future<void> clear() async {
    final db = await _db.database;
    if (db == null) return;
    
    await db.delete('readRecord');
  }

  /// 删除指定书籍的阅读记录
  Future<void> deleteByName(String bookName) async {
    final db = await _db.database;
    if (db == null) return;
    
    await db.delete(
      'readRecord',
      where: 'bookName = ?',
      whereArgs: [bookName],
    );
  }
}

