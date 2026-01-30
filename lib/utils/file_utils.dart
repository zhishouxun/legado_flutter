import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'app_log.dart';

/// 文件工具类
/// 参考项目：FileUtils.kt
class FileUtils {
  /// 创建文件（如果不存在）
  /// 参考项目：FileUtils.createFileIfNotExist
  static Future<File> createFileIfNotExist(String filePath) async {
    final file = File(filePath);
    try {
      if (!await file.exists()) {
        // 创建父目录
        final parent = file.parent;
        if (parent.path.isNotEmpty) {
          await createFolderIfNotExist(parent.path);
        }
        // 创建文件
        await file.create();
      }
    } catch (e) {
      AppLog.instance.put('FileUtils.createFileIfNotExist error: $e');
    }
    return file;
  }

  /// 创建文件夹（如果不存在）
  /// 参考项目：FileUtils.createFolderIfNotExist
  static Future<Directory> createFolderIfNotExist(String dirPath) async {
    final dir = Directory(dirPath);
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      AppLog.instance.put('FileUtils.createFolderIfNotExist error: $e');
    }
    return dir;
  }

  /// 创建文件（替换已存在的）
  /// 参考项目：FileUtils.createFileWithReplace
  static Future<File> createFileWithReplace(String filePath) async {
    final file = File(filePath);
    try {
      if (await file.exists()) {
        await file.delete();
      }
      // 创建父目录
      final parent = file.parent;
      if (parent.path.isNotEmpty) {
        await createFolderIfNotExist(parent.path);
      }
      // 创建文件
      await file.create();
    } catch (e) {
      AppLog.instance.put('FileUtils.createFileWithReplace error: $e');
    }
    return file;
  }

  /// 路径拼接
  /// 参考项目：FileUtils.getPath
  static String getPath(String rootPath, List<String> subPaths) {
    var result = rootPath;
    for (final subPath in subPaths) {
      if (subPath.isNotEmpty) {
        if (!result.endsWith(Platform.pathSeparator)) {
          result += Platform.pathSeparator;
        }
        result += subPath;
      }
    }
    return result;
  }

  /// 路径拼接（从Directory）
  static String getPathFromDir(Directory root, List<String> subPaths) {
    return getPath(root.path, subPaths);
  }

  /// 获取缓存路径
  /// 参考项目：FileUtils.getCachePath
  static Future<String> getCachePath() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      return cacheDir.path;
    } catch (e) {
      AppLog.instance.put('FileUtils.getCachePath error: $e');
      return '';
    }
  }

  /// 获取应用文档路径
  /// 参考项目：FileUtils.getSdCardPath（在Flutter中使用应用文档目录）
  static Future<String> getDocumentsPath() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      return documentsDir.path;
    } catch (e) {
      AppLog.instance.put('FileUtils.getDocumentsPath error: $e');
      return '';
    }
  }

  /// 统一路径分隔符
  /// 参考项目：FileUtils.separator
  static String separator(String pathStr) {
    var result = pathStr.replaceAll('\\', Platform.pathSeparator);
    if (!result.endsWith(Platform.pathSeparator)) {
      result += Platform.pathSeparator;
    }
    return result;
  }

  /// 删除文件或目录
  /// 参考项目：FileUtils.delete
  static Future<bool> delete(String pathStr) async {
    try {
      final file = File(pathStr);
      if (await file.exists()) {
        await file.delete(recursive: true);
        return true;
      }
      final dir = Directory(pathStr);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      AppLog.instance.put('FileUtils.delete error: $e');
      return false;
    }
  }

  /// 移动文件或目录
  /// 参考项目：FileUtils.move
  static Future<bool> move(String sourcePath, String destPath) async {
    try {
      final source = File(sourcePath);
      if (await source.exists()) {
        final dest = File(destPath);
        // 确保目标目录存在
        await createFolderIfNotExist(dest.parent.path);
        await source.rename(destPath);
        return true;
      }
      final sourceDir = Directory(sourcePath);
      if (await sourceDir.exists()) {
        // 目录移动需要递归复制后删除
        final destDir = Directory(destPath);
        await _copyDirectory(sourceDir, destDir);
        await sourceDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      AppLog.instance.put('FileUtils.move error: $e');
      return false;
    }
  }

  /// 复制目录
  static Future<void> _copyDirectory(Directory source, Directory dest) async {
    await createFolderIfNotExist(dest.path);
    await for (final entity in source.list(recursive: false)) {
      if (entity is File) {
        final destFile = File(path.join(dest.path, path.basename(entity.path)));
        await entity.copy(destFile.path);
      } else if (entity is Directory) {
        final destSubDir = Directory(path.join(dest.path, path.basename(entity.path)));
        await _copyDirectory(entity, destSubDir);
      }
    }
  }

  /// 获取文件大小
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      AppLog.instance.put('FileUtils.getFileSize error: $e');
    }
    return 0;
  }

  /// 获取目录大小
  static Future<int> getDirectorySize(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return 0;
      }
      int totalSize = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      AppLog.instance.put('FileUtils.getDirectorySize error: $e');
      return 0;
    }
  }

  /// 读取文本文件
  /// 参考项目：FileUtils.readText
  static Future<String> readText(String filePath, {String encoding = 'utf-8'}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return '';
      }
      if (encoding.toLowerCase() == 'utf-8') {
        return await file.readAsString(encoding: utf8);
      } else {
        // 其他编码需要使用 charset_converter
        final bytes = await file.readAsBytes();
        // 简化实现：默认使用 UTF-8
        return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (e) {
      AppLog.instance.put('FileUtils.readText error: $e');
      return '';
    }
  }

  /// 写入文本文件
  /// 参考项目：FileUtils.writeText
  static Future<void> writeText(String filePath, String content, {String encoding = 'utf-8'}) async {
    try {
      // 确保父目录存在
      final file = File(filePath);
      final parent = file.parent;
      if (parent.path.isNotEmpty) {
        await createFolderIfNotExist(parent.path);
      }
      
      if (encoding.toLowerCase() == 'utf-8') {
        await file.writeAsString(content, encoding: utf8);
      } else {
        // 其他编码需要使用 charset_converter
        // 简化实现：默认使用 UTF-8
        await file.writeAsString(content, encoding: utf8);
      }
    } catch (e) {
      AppLog.instance.put('FileUtils.writeText error: $e');
    }
  }

  /// 读取字节数组
  /// 参考项目：FileUtils.readBytes
  static Future<Uint8List> readBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Uint8List(0);
      }
      return await file.readAsBytes();
    } catch (e) {
      AppLog.instance.put('FileUtils.readBytes error: $e');
      return Uint8List(0);
    }
  }

  /// 写入字节数组
  /// 参考项目：FileUtils.writeBytes
  static Future<void> writeBytes(String filePath, Uint8List bytes) async {
    try {
      // 确保父目录存在
      final file = File(filePath);
      final parent = file.parent;
      if (parent.path.isNotEmpty) {
        await createFolderIfNotExist(parent.path);
      }
      await file.writeAsBytes(bytes);
    } catch (e) {
      AppLog.instance.put('FileUtils.writeBytes error: $e');
    }
  }
}

