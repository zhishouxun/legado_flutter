import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../../core/base/base_service.dart';
import '../../config/app_config.dart';
import '../../utils/app_log.dart';
import '../crash_log_service.dart';

/// 日志保存服务
/// 参考项目：AboutFragment.saveLog()
class LogSaveService extends BaseService {
  static final LogSaveService instance = LogSaveService._init();
  LogSaveService._init();

  /// 保存日志到备份目录
  /// 参考项目：AboutFragment.saveLog()
  Future<void> saveLogs() async {
    return await execute(
      action: () async {
        if (kIsWeb) {
          throw Exception('Web平台不支持保存日志');
        }

        // 检查备份目录
        final backupPath = AppConfig.getBackupPath();
        if (backupPath == null || backupPath.isEmpty) {
          throw Exception('未设置备份目录');
        }

        // 检查是否启用日志记录
        if (!AppConfig.getRecordLog()) {
          throw Exception('未开启日志记录，请去其他设置里打开记录日志');
        }

        final backupDir = Directory(backupPath);
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }

        // 收集日志文件
        await _copyLogs(backupDir);
        
        // 复制堆转储文件（如果存在）
        await _copyHeapDump(backupDir);

        AppLog.instance.put('日志已保存至备份目录');
      },
      operationName: '保存日志',
      logError: true,
    );
  }

  /// 复制日志文件
  /// 参考项目：AboutFragment.copyLogs()
  Future<void> _copyLogs(Directory backupDir) async {
    try {
      // 获取缓存目录
      final cacheDir = await getTemporaryDirectory();
      final logsDir = Directory(path.join(cacheDir.path, 'logs'));
      final crashDir = Directory(path.join(cacheDir.path, 'crash'));
      final logcatFile = File(path.join(cacheDir.path, 'logcat.txt'));

      // 创建日志目录
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // 保存应用日志
      await _saveAppLogs(logsDir);

      // 保存崩溃日志
      await _saveCrashLogs(crashDir);

      // 保存logcat（Android平台）
      if (Platform.isAndroid) {
        await _dumpLogcat(logcatFile);
      }

      // 压缩日志文件
      final archive = Archive();
      
      // 添加日志目录
      if (await logsDir.exists()) {
        await _addDirectoryToArchive(archive, logsDir, 'logs');
      }

      // 添加崩溃日志目录
      if (await crashDir.exists()) {
        await _addDirectoryToArchive(archive, crashDir, 'crash');
      }

      // 添加logcat文件
      if (await logcatFile.exists()) {
        final bytes = await logcatFile.readAsBytes();
        archive.addFile(ArchiveFile('logcat.txt', bytes.length, bytes));
      }

      // 创建ZIP文件
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        throw Exception('压缩日志失败');
      }

      // 保存到备份目录
      final zipFile = File(path.join(backupDir.path, 'logs.zip'));
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
      await zipFile.writeAsBytes(zipBytes);

      // 清理临时文件
      if (await logcatFile.exists()) {
        await logcatFile.delete();
      }
    } catch (e) {
      AppLog.instance.put('复制日志文件失败: $e', error: e);
      rethrow;
    }
  }

  /// 保存应用日志
  Future<void> _saveAppLogs(Directory logsDir) async {
    try {
      final logs = AppLog.instance.logs;
      if (logs.isEmpty) {
        return;
      }

      final logFile = File(path.join(logsDir.path, 'app_log.txt'));
      final buffer = StringBuffer();
      
      for (final log in logs.reversed) {
        buffer.writeln('[${log.formattedTime}] ${log.message}');
        if (log.error != null) {
          buffer.writeln('错误: ${log.error}');
        }
        if (log.stackTrace != null) {
          buffer.writeln('堆栈: ${log.stackTrace}');
        }
        buffer.writeln('');
      }

      await logFile.writeAsString(buffer.toString());
    } catch (e) {
      AppLog.instance.put('保存应用日志失败: $e', error: e);
    }
  }

  /// 保存崩溃日志
  Future<void> _saveCrashLogs(Directory crashDir) async {
    try {
      if (!await crashDir.exists()) {
        await crashDir.create(recursive: true);
      }

      final crashLogFiles = await CrashLogService.instance.getCrashLogFiles();
      if (crashLogFiles.isEmpty) {
        AppLog.instance.put('没有崩溃日志文件');
        return;
      }

      int successCount = 0;
      for (final file in crashLogFiles) {
        try {
          if (!await file.exists()) {
            continue;
          }
          final fileName = path.basename(file.path);
          final targetFile = File(path.join(crashDir.path, fileName));
          
          // 如果目标文件已存在，先删除
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          
          await file.copy(targetFile.path);
          successCount++;
        } catch (e) {
          AppLog.instance.put('复制崩溃日志文件失败: ${file.path}', error: e);
        }
      }
      
      AppLog.instance.put('崩溃日志已保存: $successCount/${crashLogFiles.length}');
    } catch (e) {
      AppLog.instance.put('保存崩溃日志失败: $e', error: e);
    }
  }

  /// 转储logcat（仅Android）
  /// 参考项目：AboutFragment.dumpLogcat()
  Future<void> _dumpLogcat(File logcatFile) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      // 确保文件目录存在
      final parentDir = logcatFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      // 通过平台通道执行logcat -d命令
      const platform = MethodChannel('io.legado.app/logcat');
      try {
        final result = await platform.invokeMethod<String>('dumpLogcat');
        if (result != null && result.isNotEmpty) {
          await logcatFile.writeAsString(result);
          AppLog.instance.put('logcat转储成功');
        } else {
          // 如果平台通道返回空，创建占位文件
          await logcatFile.writeAsString('logcat转储为空（可能需要READ_LOGS权限）\n');
          AppLog.instance.put('logcat转储为空');
        }
      } catch (e) {
        // 平台通道失败，创建占位文件
        AppLog.instance.put('logcat转储平台通道失败: $e', error: e);
        await logcatFile.writeAsString('logcat转储失败: $e\n注意：可能需要READ_LOGS权限\n');
      }
    } catch (e) {
      AppLog.instance.put('转储logcat失败: $e', error: e);
      // 即使失败也尝试创建占位文件
      try {
        if (!await logcatFile.exists()) {
          await logcatFile.create(recursive: true);
          await logcatFile.writeAsString('logcat转储失败: $e\n');
        }
      } catch (_) {
        // 忽略创建占位文件失败
      }
    }
  }

  /// 添加目录到归档
  Future<void> _addDirectoryToArchive(Archive archive, Directory dir, String basePath) async {
    if (!await dir.exists()) {
      return;
    }

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            final relativePath = path.relative(entity.path, from: dir.path);
            final archivePath = path.join(basePath, relativePath).replaceAll('\\', '/');
            final bytes = await entity.readAsBytes();
            if (bytes.isNotEmpty) {
              archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
            }
          } catch (e) {
            // 跳过无法读取的文件
            AppLog.instance.put('跳过文件 ${entity.path}: $e', error: e);
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('添加目录到归档失败: $e', error: e);
    }
  }

  /// 复制堆转储文件
  /// 参考项目：AboutFragment.copyHeapDump()
  Future<bool> _copyHeapDump(Directory backupDir) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final heapDumpDir = Directory(path.join(cacheDir.path, 'heapDump'));
      
      if (!await heapDumpDir.exists()) {
        return false;
      }

      final files = <File>[];
      await for (final entity in heapDumpDir.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }

      if (files.isEmpty) {
        return false;
      }

      final backupHeapDumpDir = Directory(path.join(backupDir.path, 'heapDump'));
      if (await backupHeapDumpDir.exists()) {
        await backupHeapDumpDir.delete(recursive: true);
      }
      await backupHeapDumpDir.create(recursive: true);

      for (final file in files) {
        final fileName = path.basename(file.path);
        final targetFile = File(path.join(backupHeapDumpDir.path, fileName));
        await file.copy(targetFile.path);
      }

      return true;
    } catch (e) {
      AppLog.instance.put('复制堆转储文件失败: $e', error: e);
      return false;
    }
  }
}

