import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'app_log.dart';

/// 本地文件缓存
/// 参考项目：ACache.kt
class ACache {
  static final ACache instance = ACache._init();
  ACache._init();

  static const int timeHour = 60 * 60;
  static const int timeDay = timeHour * 24;
  static const int maxSize = 1000 * 1000 * 50; // 50 MB
  static const int maxCount = 2147483647; // Integer.MAX_VALUE

  Directory? _cacheDir;

  /// 获取缓存目录
  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    
    final appDir = await getApplicationCacheDirectory();
    _cacheDir = Directory('${appDir.path}/ACache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  /// 获取文件路径
  Future<File> _getFile(String key) async {
    final cacheDir = await _getCacheDir();
    // 使用 MD5 生成文件名
    final bytes = utf8.encode(key);
    final digest = md5.convert(bytes);
    final fileName = digest.toString();
    return File('${cacheDir.path}/$fileName');
  }

  /// 保存字符串数据
  /// 参考项目：ACache.put(String, String)
  Future<void> putString(String key, String value) async {
    try {
      final file = await _getFile(key);
      await file.writeAsString(value);
    } catch (e) {
      AppLog.instance.put('ACache.putString error: $e');
    }
  }

  /// 保存字符串数据（带过期时间）
  /// saveTime 单位为秒
  /// 参考项目：ACache.put(String, String, Int)
  Future<void> put(String key, String value, {int saveTime = 0}) async {
    if (saveTime == 0) {
      await putString(key, value);
    } else {
      // 添加过期时间信息
      final deadline = DateTime.now().millisecondsSinceEpoch + saveTime * 1000;
      final dataWithDate = '$deadline\n$value';
      await putString(key, dataWithDate);
    }
  }

  /// 保存字节数组数据
  /// 参考项目：ACache.put(String, ByteArray)
  Future<void> putBytes(String key, Uint8List value) async {
    try {
      final file = await _getFile(key);
      await file.writeAsBytes(value);
    } catch (e) {
      AppLog.instance.put('ACache.putBytes error: $e');
    }
  }

  /// 保存字节数组数据（带过期时间）
  /// 参考项目：ACache.put(String, ByteArray, Int)
  Future<void> putBinary(String key, Uint8List value, {int saveTime = 0}) async {
    if (saveTime == 0) {
      await putBytes(key, value);
    } else {
      // 将过期时间信息添加到二进制数据前面
      // 格式：{currentTime}-{saveTime}\n{data}
      final dataWithDate = _newByteArrayWithDateInfo(saveTime, value);
      await putBytes(key, dataWithDate);
    }
  }

  /// 创建带过期时间信息的二进制数据
  /// 参考项目：Utils.newByteArrayWithDateInfo
  Uint8List _newByteArrayWithDateInfo(int saveTime, Uint8List data) {
    final dateInfo = _createDateInfo(saveTime);
    final dateInfoBytes = utf8.encode(dateInfo);
    final result = Uint8List(dateInfoBytes.length + data.length);
    result.setRange(0, dateInfoBytes.length, dateInfoBytes);
    result.setRange(dateInfoBytes.length, result.length, data);
    return result;
  }

  /// 创建日期信息字符串
  /// 格式：{currentTime}-{saveTime}\n
  /// 参考项目：Utils.createDateInfo
  String _createDateInfo(int saveTime) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final timeStr = currentTime.toString().padLeft(13, '0');
    return '$timeStr-$saveTime\n';
  }

  /// 检查二进制数据是否包含过期时间信息
  /// 参考项目：Utils.hasDateInfo
  bool _hasDateInfo(Uint8List data) {
    if (data.length < 15) return false;
    // 检查第13个字节是否为 '-' (ASCII 45)
    if (data.length > 13 && data[13] != 45) return false;
    // 检查是否包含分隔符 '\n' (ASCII 10)
    final separatorIndex = data.indexOf(10); // '\n'
    return separatorIndex > 14;
  }

  /// 清除二进制数据中的过期时间信息
  /// 参考项目：Utils.clearDateInfo(ByteArray)
  Uint8List _clearDateInfo(Uint8List data) {
    if (!_hasDateInfo(data)) return data;
    
    final separatorIndex = data.indexOf(10); // '\n'
    if (separatorIndex == -1 || separatorIndex >= data.length - 1) {
      return data;
    }
    
    // 返回分隔符之后的数据
    return Uint8List.sublistView(data, separatorIndex + 1);
  }

  /// 检查二进制数据是否已过期
  /// 参考项目：Utils.isDue
  bool _isDue(Uint8List data) {
    if (!_hasDateInfo(data)) return false;
    
    try {
      // 提取日期信息：前13个字符是时间戳，第14个是'-'，之后是saveTime
      final timeStr = utf8.decode(data.sublist(0, 13));
      final separatorIndex = data.indexOf(10); // '\n'
      if (separatorIndex == -1 || separatorIndex <= 14) return false;
      
      final saveTimeStr = utf8.decode(data.sublist(14, separatorIndex));
      final saveTime = int.tryParse(saveTimeStr);
      final saveDate = int.tryParse(timeStr);
      
      if (saveTime == null || saveDate == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final deadline = saveDate + saveTime * 1000;
      
      return now > deadline;
    } catch (e) {
      return false;
    }
  }

  /// 读取字符串数据
  /// 参考项目：ACache.getAsString
  Future<String?> getAsString(String key) async {
    try {
      final file = await _getFile(key);
      if (!await file.exists()) {
        return null;
      }

      final text = await file.readAsString();
      
      // 检查是否包含过期时间信息
      if (text.contains('\n')) {
        final lines = text.split('\n');
        if (lines.length >= 2) {
          final deadline = int.tryParse(lines[0]);
          if (deadline != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now > deadline) {
              // 已过期，删除文件
              await remove(key);
              return null;
            }
            // 返回实际内容
            return lines.sublist(1).join('\n');
          }
        }
      }

      return text;
    } catch (e) {
      AppLog.instance.put('ACache.getAsString error: $e');
      return null;
    }
  }

  /// 读取二进制数据
  /// 参考项目：ACache.getAsBinary
  Future<Uint8List?> getAsBinary(String key) async {
    try {
      final file = await _getFile(key);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final data = Uint8List.fromList(bytes);
      
      // 检查是否已过期
      if (_isDue(data)) {
        // 已过期，删除文件
        await remove(key);
        return null;
      }
      
      // 清除过期时间信息，返回实际数据
      return _clearDateInfo(data);
    } catch (e) {
      AppLog.instance.put('ACache.getAsBinary error: $e');
      return null;
    }
  }

  /// 删除缓存
  /// 参考项目：ACache.remove
  Future<void> remove(String key) async {
    try {
      final file = await _getFile(key);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLog.instance.put('ACache.remove error: $e');
    }
  }

  /// 清空所有缓存
  Future<void> clear() async {
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
    } catch (e) {
      AppLog.instance.put('ACache.clear error: $e');
    }
  }
}

