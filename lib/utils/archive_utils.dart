import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'file_utils.dart';
import 'app_log.dart';

/// 压缩工具类
/// 参考项目：ArchiveUtils.kt
class ArchiveUtils {
  static const String tempFolderName = 'ArchiveTemp';

  /// 获取临时目录路径
  /// 参考项目：ArchiveUtils.TEMP_PATH
  static Future<String> getTempPath() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final tempDir = Directory('${cacheDir.path}/$tempFolderName');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      return tempDir.path;
    } catch (e) {
      AppLog.instance.put('ArchiveUtils.getTempPath error: $e');
      return '';
    }
  }

  /// 解压文件
  /// 参考项目：ArchiveUtils.deCompress
  static Future<List<File>> deCompress(
    String archivePath, {
    String? outputPath,
    bool Function(String)? filter,
  }) async {
    try {
      final archiveFile = File(archivePath);
      if (!await archiveFile.exists()) {
        AppLog.instance.put('ArchiveUtils.deCompress: 文件不存在: $archivePath');
        return [];
      }

      final outputDir = outputPath ?? await getTempPath();
      await FileUtils.createFolderIfNotExist(outputDir);

      // 读取压缩文件
      final bytes = await archiveFile.readAsBytes();
      
      // 根据文件扩展名判断压缩格式
      final extension = archivePath.toLowerCase().split('.').last;
      Archive? archive;

      switch (extension) {
        case 'zip':
          archive = ZipDecoder().decodeBytes(bytes);
          break;
        case 'tar':
          archive = TarDecoder().decodeBytes(bytes);
          break;
        case 'gz':
          // GZIP 通常与 TAR 一起使用
          final decompressed = GZipDecoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(decompressed);
          break;
        default:
          // 尝试自动检测
          try {
            archive = ZipDecoder().decodeBytes(bytes);
          } catch (e) {
            try {
              archive = TarDecoder().decodeBytes(bytes);
            } catch (e2) {
              AppLog.instance.put('ArchiveUtils.deCompress: 不支持的压缩格式: $extension');
              return [];
            }
          }
      }

      // 解压文件
      final extractedFiles = <File>[];
      for (final file in archive) {
        final fileName = file.name;
        
        // 应用过滤器
        if (filter != null && !filter(fileName)) {
          continue;
        }

        final outputFile = File('$outputDir/$fileName');
        
        // 确保父目录存在
        await FileUtils.createFolderIfNotExist(outputFile.parent.path);
        
        // 写入文件
        if (file.isFile) {
          await outputFile.writeAsBytes(file.content as List<int>);
          extractedFiles.add(outputFile);
        }
      }

      return extractedFiles;
    } catch (e) {
      AppLog.instance.put('ArchiveUtils.deCompress error: $e');
      return [];
    }
  }

  /// 获取压缩文件中的文件名列表
  /// 参考项目：ArchiveUtils.getArchiveFilesName
  static Future<List<String>> getArchiveFilesName(
    String archivePath, {
    bool Function(String)? filter,
  }) async {
    try {
      final archiveFile = File(archivePath);
      if (!await archiveFile.exists()) {
        return [];
      }

      final bytes = await archiveFile.readAsBytes();
      final extension = archivePath.toLowerCase().split('.').last;
      Archive? archive;

      switch (extension) {
        case 'zip':
          archive = ZipDecoder().decodeBytes(bytes);
          break;
        case 'tar':
          archive = TarDecoder().decodeBytes(bytes);
          break;
        case 'gz':
          final decompressed = GZipDecoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(decompressed);
          break;
        default:
          try {
            archive = ZipDecoder().decodeBytes(bytes);
          } catch (e) {
            try {
              archive = TarDecoder().decodeBytes(bytes);
            } catch (e2) {
              return [];
            }
          }
      }

      final fileNames = <String>[];
      for (final file in archive) {
        if (file.isFile) {
          final fileName = file.name;
          if (filter == null || filter(fileName)) {
            fileNames.add(fileName);
          }
        }
      }

      return fileNames;
    } catch (e) {
      AppLog.instance.put('ArchiveUtils.getArchiveFilesName error: $e');
      return [];
    }
  }

  /// 判断是否为压缩文件
  /// 参考项目：ArchiveUtils.isArchive
  static bool isArchive(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['zip', 'tar', 'gz', '7z', 'rar'].contains(extension);
  }
}

