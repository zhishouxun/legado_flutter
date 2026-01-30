import 'dart:io';
import 'package:flutter/material.dart';
import '../core/base/base_service.dart';
import '../core/exceptions/app_exceptions.dart' show InvalidBooksDirException, NoBooksDirException;
import '../utils/app_log.dart';
import '../utils/file_utils.dart';

/// 文件信息
class FileInfo {
  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime lastModified;

  FileInfo({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.lastModified,
  });
}

/// 文件管理服务
class FileManageService extends BaseService {
  static final FileManageService instance = FileManageService._init();
  FileManageService._init();

  /// 获取根目录
  Future<Directory> getRootDirectory() async {
    final appDirPath = await FileUtils.getDocumentsPath();
    final appDir = Directory(appDirPath);
    return appDir.parent;
  }

  /// 获取应用文档目录
  Future<Directory> getAppDocumentsDirectory() async {
    final appDirPath = await FileUtils.getDocumentsPath();
    return Directory(appDirPath);
  }

  /// 获取书籍目录
  Future<Directory> getBooksDirectory() async {
    try {
      final appDirPath = await FileUtils.getDocumentsPath();
      final appDir = Directory(appDirPath);
      
      if (!await appDir.exists()) {
        throw NoBooksDirException('应用文档目录不存在: $appDirPath');
      }
      
      final booksDirPath = FileUtils.getPath(appDirPath, ['books']);
      final booksDir = Directory(booksDirPath);
      
      try {
        await FileUtils.createFolderIfNotExist(booksDirPath);
      } catch (e) {
        throw InvalidBooksDirException('无法创建书籍目录: $booksDirPath, 错误: $e');
      }
      
      // 验证目录是否可访问
      if (!await booksDir.exists()) {
        throw NoBooksDirException('书籍目录不存在: $booksDirPath');
      }
      
      return booksDir;
    } catch (e) {
      if (e is NoBooksDirException || e is InvalidBooksDirException) {
        rethrow;
      }
      throw InvalidBooksDirException('获取书籍目录失败: $e');
    }
  }

  /// 获取目录下的文件和文件夹
  Future<List<FileInfo>> getFilesInDirectory(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return [];
      }

      final entities = directory.listSync();
      final files = <FileInfo>[];

      // 添加父目录（如果不是根目录）
      final parent = directory.parent;
      if (parent.path != directory.path) {
        files.add(FileInfo(
          path: parent.path,
          name: '..',
          isDirectory: true,
          size: 0,
          lastModified: DateTime.now(),
        ));
      }

      // 添加当前目录本身（用于显示）
            final dirStat = await directory.stat();
            files.add(FileInfo(
              path: directory.path,
              name: '.',
              isDirectory: true,
              size: 0,
              lastModified: dirStat.modified,
            ));

      // 添加文件和文件夹
      for (final entity in entities) {
        try {
          if (entity is File) {
            final stat = await entity.stat();
            files.add(FileInfo(
              path: entity.path,
              name: entity.path.split('/').last,
              isDirectory: false,
              size: stat.size,
              lastModified: await entity.lastModified(),
            ));
          } else if (entity is Directory) {
            final dirStat = await entity.stat();
            files.add(FileInfo(
              path: entity.path,
              name: entity.path.split('/').last,
              isDirectory: true,
              size: 0,
              lastModified: dirStat.modified,
            ));
          }
        } catch (e) {
          // 跳过无法访问的文件/目录
          AppLog.instance.put('无法访问文件: ${entity.path}', error: e);
        }
      }

      // 排序：目录在前，文件在后，按名称排序
      files.sort((a, b) {
        if (a.name == '..') return -1;
        if (b.name == '..') return 1;
        if (a.name == '.') return -1;
        if (b.name == '.') return 0;
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return files;
    } catch (e) {
      AppLog.instance.put('获取目录文件列表失败', error: e);
      return [];
    }
  }

  /// 删除文件或目录
  Future<bool> deleteFile(String path) async {
    try {
      return await FileUtils.delete(path);
    } catch (e) {
      AppLog.instance.put('删除文件失败: $path', error: e);
      return false;
    }
  }

  /// 获取文件大小（格式化）
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 判断是否为书籍文件
  bool isBookFile(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3', 'fb2', 'zip', 'rar', '7z'].contains(ext);
  }

  /// 获取文件图标
  IconData getFileIcon(String fileName, bool isDirectory) {
    if (isDirectory) {
      return Icons.folder;
    }

    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'txt':
        return Icons.description;
      case 'epub':
      case 'pdf':
      case 'mobi':
      case 'azw':
      case 'azw3':
      case 'fb2':
        return Icons.book;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp3':
      case 'mp4':
      case 'avi':
      case 'mkv':
        return Icons.video_library;
      default:
        return Icons.insert_drive_file;
    }
  }
}

