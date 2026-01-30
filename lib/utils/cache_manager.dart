import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../data/database/app_database.dart';
import '../data/models/cache.dart';
import 'app_log.dart';
import 'a_cache.dart';

/// 内存LRU缓存
/// 参考项目：CacheManager.kt 中的 memoryLruCache
class _MemoryLruCache {
  final int maxSize;
  final Map<String, dynamic> _cache = {};
  final List<String> _accessOrder = [];

  _MemoryLruCache(this.maxSize);

  /// 计算值的大小（字节）
  int _sizeOf(String key, dynamic value) {
    // 简化实现：使用字符串长度估算
    return value.toString().length * 2; // UTF-16 每个字符2字节
  }

  void put(String key, dynamic value) {
    final valueSize = _sizeOf(key, value);

    // 如果值太大，直接返回
    if (valueSize > maxSize) {
      return;
    }

    // 移除旧值
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    }

    // 检查是否需要清理空间
    int currentSize = _cache.values.fold<int>(
      0,
      (sum, value) => sum + _sizeOf('', value),
    );

    while (currentSize + valueSize > maxSize && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeAt(0);
      final oldValue = _cache.remove(oldestKey);
      if (oldValue != null) {
        currentSize -= _sizeOf(oldestKey, oldValue);
      }
    }

    // 添加新值
    _cache[key] = value;
    _accessOrder.add(key);
  }

  dynamic get(String key) {
    if (_cache.containsKey(key)) {
      // 更新访问顺序
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return _cache[key];
    }
    return null;
  }

  void remove(String key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  Map<String, dynamic> snapshot() {
    return Map<String, dynamic>.from(_cache);
  }
}

/// 缓存管理器
/// 参考项目：CacheManager.kt
class CacheManager {
  static final CacheManager instance = CacheManager._init();
  CacheManager._init();

  // 最多只缓存50M的数据,防止OOM
  static const int maxMemorySize = 1024 * 1024 * 50; // 50MB
  final _MemoryLruCache _memoryCache = _MemoryLruCache(maxMemorySize);

  /// 保存缓存
  /// saveTime 单位为秒，0表示永不过期
  /// 参考项目：CacheManager.put
  Future<void> put(String key, dynamic value, {int saveTime = 0}) async {
    try {
      final deadline = saveTime == 0
          ? 0
          : DateTime.now().millisecondsSinceEpoch + saveTime * 1000;

      if (value is Uint8List || value is List<int>) {
        // ByteArray 使用 ACache
        final bytes = value is Uint8List ? value : Uint8List.fromList(value);
        await ACache.instance.putBytes(key, bytes);
      } else {
        // 其他类型保存到数据库
        final cache = Cache(
          key: key,
          value: value.toString(),
          deadline: deadline,
        );

        // 保存到内存
        _memoryCache.put(key, value);

        // 保存到数据库
        final db = await AppDatabase.instance.database;
        if (db != null) {
          await db.insert(
            'caches',
            cache.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    } catch (e) {
      AppLog.instance.put('CacheManager.put error: $e');
    }
  }

  /// 保存到内存
  /// 参考项目：CacheManager.putMemory
  void putMemory(String key, dynamic value) {
    _memoryCache.put(key, value);
  }

  /// 从内存中获取数据
  /// 参考项目：CacheManager.getFromMemory
  dynamic getFromMemory(String key) {
    return _memoryCache.get(key);
  }

  /// 删除内存缓存
  /// 参考项目：CacheManager.deleteMemory
  void deleteMemory(String key) {
    _memoryCache.remove(key);
  }

  /// 获取缓存
  /// 参考项目：CacheManager.get
  Future<String?> get(String key) async {
    try {
      // 先从内存获取
      final memoryValue = _memoryCache.get(key);
      if (memoryValue is String) {
        return memoryValue;
      }

      // 从数据库获取
      final db = await AppDatabase.instance.database;
      if (db != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final result = await db.query(
          'caches',
          where: '"key" = ? AND (deadline = 0 OR deadline > ?)',
          whereArgs: [key, now],
          limit: 1,
        );

        if (result.isNotEmpty) {
          final cache = Cache.fromMap(result.first);
          // 保存到内存
          _memoryCache.put(key, cache.value ?? '');
          return cache.value;
        }
      }
    } catch (e) {
      AppLog.instance.put('CacheManager.get error: $e');
    }
    return null;
  }

  /// 获取整数缓存
  /// 参考项目：CacheManager.getInt
  Future<int?> getInt(String key) async {
    final value = await get(key);
    return value != null ? int.tryParse(value) : null;
  }

  /// 获取长整数缓存
  /// 参考项目：CacheManager.getLong
  Future<int?> getLong(String key) async {
    final value = await get(key);
    return value != null ? int.tryParse(value) : null;
  }

  /// 获取浮点数缓存
  /// 参考项目：CacheManager.getDouble
  Future<double?> getDouble(String key) async {
    final value = await get(key);
    return value != null ? double.tryParse(value) : null;
  }

  /// 获取字节数组缓存
  /// 参考项目：CacheManager.getByteArray
  Future<Uint8List?> getByteArray(String key) async {
    return await ACache.instance.getAsBinary(key);
  }

  /// 保存文件缓存
  /// 参考项目：CacheManager.putFile
  Future<void> putFile(String key, String value, {int saveTime = 0}) async {
    await ACache.instance.put(key, value, saveTime: saveTime);
  }

  /// 获取文件缓存
  /// 参考项目：CacheManager.getFile
  Future<String?> getFile(String key) async {
    return await ACache.instance.getAsString(key);
  }

  /// 删除缓存
  /// 参考项目：CacheManager.delete
  Future<void> delete(String key) async {
    try {
      // 从数据库删除
      final db = await AppDatabase.instance.database;
      if (db != null) {
        await db.delete('caches', where: '"key" = ?', whereArgs: [key]);
      }

      // 从内存删除
      _memoryCache.remove(key);

      // 从文件缓存删除
      await ACache.instance.remove(key);
    } catch (e) {
      AppLog.instance.put('CacheManager.delete error: $e');
    }
  }

  /// 清除书源变量缓存
  /// 参考项目：AppCacheManager.clearSourceVariables
  void clearSourceVariables() {
    final snapshot = _memoryCache.snapshot();
    for (final key in snapshot.keys) {
      if (key.startsWith('v_') ||
          key.startsWith('userInfo_') ||
          key.startsWith('loginHeader_') ||
          key.startsWith('sourceVariable_')) {
        _memoryCache.remove(key);
      }
    }
  }

  /// 删除书源变量缓存（数据库）
  /// 参考项目：CacheDao.deleteSourceVariables
  Future<void> deleteSourceVariables(String key) async {
    try {
      final db = await AppDatabase.instance.database;
      if (db != null) {
        await db.delete(
          'caches',
          where: '"key" LIKE ? OR "key" = ? OR "key" = ? OR "key" = ?',
          whereArgs: [
            'v_${key}_%',
            'userInfo_$key',
            'loginHeader_$key',
            'sourceVariable_$key',
          ],
        );
      }
    } catch (e) {
      AppLog.instance.put('CacheManager.deleteSourceVariables error: $e');
    }
  }

  /// 清理过期缓存
  /// 参考项目：CacheDao.clearDeadline
  Future<void> clearDeadline() async {
    try {
      final db = await AppDatabase.instance.database;
      if (db != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.delete(
          'caches',
          where: 'deadline > 0 AND deadline < ?',
          whereArgs: [now],
        );
      }
    } catch (e) {
      AppLog.instance.put('CacheManager.clearDeadline error: $e');
    }
  }
}
