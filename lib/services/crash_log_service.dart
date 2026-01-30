import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../core/base/base_service.dart';
import '../../utils/crash_handler.dart';

/// 崩溃日志服务
/// 增强版，集成 CrashHandler 功能
class CrashLogService extends BaseService {
  static final CrashLogService instance = CrashLogService._init();
  CrashLogService._init();

  Directory? _crashDir;

  @override
  Future<void> onInit() async {
    return await execute(
      action: () async {
        if (kIsWeb) {
          // Web平台不支持文件系统
          return;
        }

        final appDocDir = await getApplicationDocumentsDirectory();
        _crashDir = Directory('${appDocDir.path}/crash');
        if (!await _crashDir!.exists()) {
          await _crashDir!.create(recursive: true);
        }
      },
      operationName: '初始化崩溃日志服务',
      logError: true,
    );
  }

  /// 保存崩溃日志
  /// 参考项目：CrashHandler.saveCrashInfo2File()
  Future<void> saveCrashLog({
    required String error,
    required String stackTrace,
    Object? details,
  }) async {
    // 使用增强的 CrashHandler 保存
    final errorObj = Exception(error);
    final stack = StackTrace.fromString(stackTrace);
    await CrashHandler.saveCrashInfoToFile(errorObj, stack);
    
    // 同时保存到原有目录（兼容性）
    return await execute(
      action: () async {
        if (kIsWeb || _crashDir == null) {
          return;
        }

        final timestamp = DateTime.now();
        final dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
        final fileName = 'crash_${dateFormat.format(timestamp)}.txt';
        final file = File('${_crashDir!.path}/$fileName');

        final buffer = StringBuffer();
        buffer.writeln('崩溃时间: ${timestamp.toString()}');
        buffer.writeln('=' * 50);
        buffer.writeln();
        buffer.writeln('错误信息:');
        buffer.writeln(error);
        buffer.writeln();
        buffer.writeln('堆栈跟踪:');
        buffer.writeln(stackTrace);
        if (details != null) {
          buffer.writeln();
          buffer.writeln('详细信息:');
          buffer.writeln(details.toString());
        }
        buffer.writeln();
        buffer.writeln('=' * 50);

        await file.writeAsString(buffer.toString());
      },
      operationName: '保存崩溃日志',
      logError: false, // 崩溃日志保存失败不记录，避免循环
    );
  }

  /// 获取所有崩溃日志文件
  Future<List<File>> getCrashLogFiles() async {
    if (kIsWeb || _crashDir == null) {
      return [];
    }

    try {
      if (!await _crashDir!.exists()) {
        return [];
      }

      final files = <File>[];
      await for (final entity in _crashDir!.list()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          files.add(entity);
        }
      }

      // 按文件名（时间戳）降序排序
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (e) {
      return [];
    }
  }

  /// 读取崩溃日志文件内容
  Future<String?> readCrashLogFile(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      return null;
    }
  }

  /// 清除所有崩溃日志
  Future<bool> clearAllCrashLogs() async {
    if (kIsWeb || _crashDir == null) {
      return false;
    }

    try {
      if (!await _crashDir!.exists()) {
        return true;
      }

      await for (final entity in _crashDir!.list()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          await entity.delete();
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 删除单个崩溃日志文件
  Future<bool> deleteCrashLogFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

