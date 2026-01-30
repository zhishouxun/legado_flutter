import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/app_log.dart';
import '../config/app_config.dart';

/// 崩溃处理器
/// 参考项目：io.legado.app.help.CrashHandler
class CrashHandler {
  static final CrashHandler instance = CrashHandler._init();
  CrashHandler._init();

  /// 系统信息映射
  static final Map<String, String> _systemInfo = {};

  /// 初始化系统信息
  static Future<void> _initSystemInfo() async {
    if (_systemInfo.isNotEmpty) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _systemInfo['packageName'] = packageInfo.packageName;
      _systemInfo['versionName'] = packageInfo.version;
      _systemInfo['versionCode'] = packageInfo.buildNumber;

      if (!kIsWeb) {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          _systemInfo['MANUFACTURER'] = androidInfo.manufacturer;
          _systemInfo['BRAND'] = androidInfo.brand;
          _systemInfo['MODEL'] = androidInfo.model;
          _systemInfo['SDK_INT'] = androidInfo.version.sdkInt.toString();
          _systemInfo['RELEASE'] = androidInfo.version.release;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          _systemInfo['MANUFACTURER'] = 'Apple';
          _systemInfo['BRAND'] = 'Apple';
          _systemInfo['MODEL'] = iosInfo.model;
          _systemInfo['SDK_INT'] = iosInfo.systemVersion;
          _systemInfo['RELEASE'] = iosInfo.systemVersion;
        }
      }

      // 获取内存信息
      if (!kIsWeb) {
        // Flutter 中无法直接获取最大堆内存，使用平台通道或省略
        _systemInfo['heapSize'] = 'N/A';
      }
    } catch (e) {
      AppLog.instance.put('初始化系统信息失败', error: e);
    }
  }

  /// 判断是否应该吸收异常（不处理）
  /// 参考项目：CrashHandler.shouldAbsorb()
  static bool shouldAbsorb(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    // 检查权限相关异常
    if (errorStr.contains('observe_grant_revoke_permissions')) {
      return true;
    }
    // Flutter 中没有 CannotDeliverBroadcastException，但可以检查其他特定异常
    final errorType = error.runtimeType.toString().toLowerCase();
    if (errorType.contains('broadcast') && errorType.contains('exception')) {
      return true;
    }
    return false;
  }

  /// 处理异常
  /// 参考项目：CrashHandler.handleException()
  static Future<void> handleException(dynamic error, StackTrace? stackTrace) async {
    if (error == null) return;

    // 保存崩溃日志
    await saveCrashInfoToFile(error, stackTrace);

    // 检查是否是 OOM 错误
    final isOOM = error.toString().contains('OutOfMemory') ||
        (error is Error && error.toString().contains('OutOfMemory'));
    
    if (isOOM && AppConfig.getRecordHeapDump()) {
      // Flutter 中无法直接进行堆转储，但可以记录日志
      AppLog.instance.put('检测到内存溢出错误，建议检查内存使用情况');
    }
  }

  /// 保存崩溃信息到文件
  /// 参考项目：CrashHandler.saveCrashInfo2File()
  static Future<void> saveCrashInfoToFile(dynamic error, StackTrace? stackTrace) async {
    if (kIsWeb) return;

    try {
      await _initSystemInfo();

      final buffer = StringBuffer();
      
      // 写入系统信息
      for (final entry in _systemInfo.entries) {
        buffer.writeln('${entry.key}=${entry.value}');
      }
      buffer.writeln();

      // 写入异常信息
      buffer.writeln(error.toString());
      if (stackTrace != null) {
        buffer.writeln();
        buffer.writeln(stackTrace.toString());
      }

      // 写入 cause 链
      if (error is Error && error.stackTrace != null) {
        buffer.writeln();
        buffer.writeln('Cause:');
        buffer.writeln(error.stackTrace.toString());
      }

      final crashLog = buffer.toString();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dateFormat = DateFormat('yyyy-MM-dd-HH-mm-ss');
      final time = dateFormat.format(DateTime.now());
      final fileName = 'crash-$time-$timestamp.log';

      // 保存到备份路径（如果配置了）
      try {
        final backupPath = AppConfig.getBackupPath();
        if (backupPath != null && backupPath.isNotEmpty) {
          final backupDir = Directory(backupPath);
          if (await backupDir.exists()) {
            final crashDir = Directory('${backupDir.path}/crash');
            if (!await crashDir.exists()) {
              await crashDir.create(recursive: true);
            }
            final file = File('${crashDir.path}/$fileName');
            await file.writeAsString(crashLog);
          }
        }
      } catch (e) {
        // 备份路径保存失败，继续尝试缓存目录
      }

      // 保存到缓存目录
      try {
        final cacheDir = await getTemporaryDirectory();
        final crashDir = Directory('${cacheDir.path}/crash');
        if (!await crashDir.exists()) {
          await crashDir.create(recursive: true);
        }

        // 清理7天前的日志
        final exceedTimeMillis = DateTime.now().millisecondsSinceEpoch - 
            Duration(days: 7).inMilliseconds;
        if (await crashDir.exists()) {
          await for (final entity in crashDir.list()) {
            if (entity is File) {
              final stat = await entity.stat();
              if (stat.modified.millisecondsSinceEpoch < exceedTimeMillis) {
                try {
                  await entity.delete();
                } catch (e) {
                  // 忽略删除失败
                }
              }
            }
          }
        }

        final file = File('${crashDir.path}/$fileName');
        await file.writeAsString(crashLog);
      } catch (e) {
        AppLog.instance.put('保存崩溃日志到缓存目录失败', error: e);
      }
    } catch (e) {
      // 崩溃日志保存失败不记录，避免循环
    }
  }
}

