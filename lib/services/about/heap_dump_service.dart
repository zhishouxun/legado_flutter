import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../../core/base/base_service.dart';
import '../../config/app_config.dart';
import '../../utils/app_log.dart';

/// 堆转储服务
/// 参考项目：AboutFragment.createHeapDump()
class HeapDumpService extends BaseService {
  static final HeapDumpService instance = HeapDumpService._init();
  HeapDumpService._init();

  /// 创建堆转储
  /// 参考项目：AboutFragment.createHeapDump()
  /// 注意：Flutter中无法直接创建堆转储，这里记录内存信息
  Future<void> createHeapDump() async {
    return await execute(
      action: () async {
        if (kIsWeb) {
          throw Exception('Web平台不支持创建堆转储');
        }

        // 检查备份目录
        final backupPath = AppConfig.getBackupPath();
        if (backupPath == null || backupPath.isEmpty) {
          throw Exception('未设置备份目录');
        }

        // 检查是否启用堆转储记录
        if (!AppConfig.getRecordHeapDump()) {
          throw Exception('未开启堆转储记录，请去其他设置里打开记录堆转储');
        }

        // 触发GC（通过平台通道）
        const platform = MethodChannel('io.legado.app/heapdump');
        try {
          await platform.invokeMethod('triggerGC');
        } catch (e) {
          AppLog.instance.put('触发GC失败: $e', error: e);
        }

        AppLog.instance.put('开始创建堆转储');

        // 尝试通过平台通道创建实际堆转储文件（仅Android）
        File? heapDumpFile;
        if (Platform.isAndroid) {
          try {
            final heapDumpPath = await platform.invokeMethod<String>('createHeapDump');
            if (heapDumpPath != null && heapDumpPath.isNotEmpty) {
              heapDumpFile = File(heapDumpPath);
              if (await heapDumpFile.exists()) {
                AppLog.instance.put('通过平台通道创建堆转储文件成功: ${heapDumpFile.path}');
              }
            }
          } catch (e) {
            AppLog.instance.put('通过平台通道创建堆转储失败: $e', error: e);
          }
        }

        // 如果平台通道失败，创建内存信息文件
        if (heapDumpFile == null || !await heapDumpFile.exists()) {
          // 记录内存信息
          final memoryInfo = await _getMemoryInfo();
          
          // 保存到缓存目录
          final cacheDir = await getTemporaryDirectory();
          final heapDumpDir = Directory(path.join(cacheDir.path, 'heapDump'));
          if (!await heapDumpDir.exists()) {
            await heapDumpDir.create(recursive: true);
          }

          final dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
          final fileName = 'heapDump_${dateFormat.format(DateTime.now())}.txt';
          heapDumpFile = File(path.join(heapDumpDir.path, fileName));
          await heapDumpFile.writeAsString(memoryInfo);
          AppLog.instance.put('创建内存信息文件: ${heapDumpFile.path}');
        }

        // 复制到备份目录
        final backupDir = Directory(backupPath);
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }

        final backupHeapDumpDir = Directory(path.join(backupDir.path, 'heapDump'));
        if (await backupHeapDumpDir.exists()) {
          // 清理旧的堆转储文件（可选，保留最近的几个）
          try {
            final existingFiles = <File>[];
            await for (final entity in backupHeapDumpDir.list()) {
              if (entity is File) {
                existingFiles.add(entity);
              }
            }
            // 保留最近5个文件，删除旧的
            if (existingFiles.length > 5) {
              existingFiles.sort((a, b) => b.path.compareTo(a.path));
              for (int i = 5; i < existingFiles.length; i++) {
                try {
                  await existingFiles[i].delete();
                } catch (e) {
                  // 忽略删除失败
                }
              }
            }
          } catch (e) {
            // 忽略清理失败
          }
        } else {
          await backupHeapDumpDir.create(recursive: true);
        }

        // 获取文件名
        final fileName = path.basename(heapDumpFile.path);
        final backupFile = File(path.join(backupHeapDumpDir.path, fileName));
        
        // 如果目标文件已存在，先删除
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
        
        await heapDumpFile.copy(backupFile.path);
        AppLog.instance.put('堆转储文件已复制到备份目录: ${backupFile.path}');

        AppLog.instance.put('堆转储已保存至备份目录');
      },
      operationName: '创建堆转储',
      logError: true,
    );
  }

  /// 获取内存信息
  /// 在Flutter中，可以通过平台通道获取内存信息
  Future<String> _getMemoryInfo() async {
    final buffer = StringBuffer();
    buffer.writeln('堆转储信息');
    buffer.writeln('=' * 50);
    buffer.writeln('时间: ${DateTime.now()}');
    buffer.writeln('');
    
    // 获取系统信息
    if (Platform.isAndroid) {
      buffer.writeln('平台: Android');
    } else if (Platform.isIOS) {
      buffer.writeln('平台: iOS');
    } else {
      buffer.writeln('平台: ${Platform.operatingSystem}');
    }
    
    buffer.writeln('版本: ${Platform.operatingSystemVersion}');
    buffer.writeln('');
    
    // 通过平台通道获取内存信息（仅Android）
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('io.legado.app/heapdump');
        final memoryInfo = await platform.invokeMethod<Map<Object?, Object?>>('getMemoryInfo');
        if (memoryInfo != null) {
          buffer.writeln('内存信息:');
          for (final entry in memoryInfo.entries) {
            buffer.writeln('${entry.key}: ${entry.value}');
          }
          buffer.writeln('');
        }
      } catch (e) {
        AppLog.instance.put('获取内存信息失败: $e', error: e);
        buffer.writeln('获取内存信息失败: $e');
        buffer.writeln('');
      }
    }
    
    // 注意：实际堆转储文件需要通过平台通道创建
    buffer.writeln('注意：此文件包含内存信息');
    buffer.writeln('实际堆转储文件需要通过平台通道创建');
    
    return buffer.toString();
  }
}

