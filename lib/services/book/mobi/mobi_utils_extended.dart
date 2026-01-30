/// MOBI工具扩展类
/// 提供一些便捷的工具方法
library;

import 'dart:io';
import 'mobi_reader.dart';
import 'mobi_constants.dart';
import '../../../utils/app_log.dart';

/// MOBI工具类
class MobiUtils {
  MobiUtils._();

  /// 获取MOBI文件的基本信息（不打开完整文件）
  /// 快速获取文件元数据，适合文件列表展示
  static Future<Map<String, dynamic>?> getFileMetadata(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }

      final isValid = await MobiReader.isValidMobiFile(file);
      if (!isValid) {
        return null;
      }

      // 读取基本信息
      final mobiBook = await MobiReader.readMobi(file);
      try {
        final metadata = mobiBook.metadata;
        final fileSize = await file.length();

        return {
          'title': metadata.title,
          'author': metadata.creators.join(', '),
          'publisher': metadata.publisher,
          'language': metadata.language,
          'fileSize': fileSize,
          'hasNCX': mobiBook.hasNCX,
          'isKF8': mobiBook.isKF8,
          'compression': mobiBook.palmdoc.compression == 1
              ? 'Plain'
              : mobiBook.palmdoc.compression == 2
                  ? 'LZ77'
                  : 'Unknown',
        };
      } finally {
        await mobiBook.close();
      }
    } catch (e) {
      AppLog.instance.put('获取MOBI文件元数据失败: ${file.path}', error: e);
      return null;
    }
  }

  /// 批量获取多个MOBI文件的基本信息
  static Future<List<Map<String, dynamic>>> getFilesMetadata(
      List<File> files) async {
    final results = <Map<String, dynamic>>[];

    for (final file in files) {
      final metadata = await getFileMetadata(file);
      if (metadata != null) {
        metadata['filePath'] = file.path;
        metadata['fileName'] = file.path.split('/').last;
        results.add(metadata);
      }
    }

    return results;
  }

  /// 检查文件是否损坏
  static Future<bool> isFileCorrupted(File file) async {
    try {
      final mobiBook = await MobiReader.readMobi(file);
      try {
        final validation = await mobiBook.validateFile();
        return !validation['isValid'];
      } finally {
        await mobiBook.close();
      }
    } catch (e) {
      return true;
    }
  }

  /// 获取文件统计信息
  static Future<Map<String, dynamic>?> getFileStatistics(File file) async {
    try {
      final mobiBook = await MobiReader.readMobi(file);
      try {
        final chapters = await mobiBook.getChapters();
        final totalLength = await mobiBook.getTotalTextLength();
        final fileSize = await file.length();

        // 计算平均章节长度
        final avgChapterLength =
            chapters.isNotEmpty ? totalLength / chapters.length : 0;

        // 计算压缩率
        final compressionRatio =
            fileSize > 0 ? (1 - totalLength / fileSize) * 100 : 0;

        return {
          'fileSize': fileSize,
          'textLength': totalLength,
          'compressionRatio': '${compressionRatio.toStringAsFixed(2)}%',
          'chapterCount': chapters.length,
          'avgChapterLength': avgChapterLength.toInt(),
          'textRecords': mobiBook.palmdoc.numTextRecords,
          'hasNCX': mobiBook.hasNCX,
          'isKF8': mobiBook.isKF8,
        };
      } finally {
        await mobiBook.close();
      }
    } catch (e) {
      AppLog.instance.put('获取MOBI文件统计信息失败: ${file.path}', error: e);
      return null;
    }
  }

  /// 搜索文本内容
  ///
  /// [file] MOBI文件
  /// [keyword] 搜索关键词
  /// [maxResults] 最大结果数，默认100
  ///
  /// 返回匹配结果列表，每个结果包含：
  /// - chapterIndex: 章节索引
  /// - chapterTitle: 章节标题
  /// - position: 匹配位置
  /// - context: 上下文（前后各50个字符）
  /// - match: 匹配的关键词
  ///
  /// 示例：
  /// ```dart
  /// final results = await MobiUtils.searchText(file, '关键词', maxResults: 50);
  /// for (final result in results) {
  ///   print('在章节"${result['chapterTitle']}"中找到匹配');
  /// }
  /// ```
  static Future<List<Map<String, dynamic>>> searchText(
    File file,
    String keyword, {
    int maxResults = MobiDefaults.maxSearchResults,
  }) async {
    if (keyword.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    try {
      final mobiBook = await MobiReader.readMobi(file);
      try {
        final chapters = await mobiBook.getChapters();

        for (int i = 0;
            i < chapters.length && results.length < maxResults;
            i++) {
          final chapter = chapters[i];
          final content = await mobiBook.getChapterContent(chapter);

          if (content != null && content.contains(keyword)) {
            // 查找所有匹配位置
            int index = 0;
            while (index < content.length && results.length < maxResults) {
              final pos = content.indexOf(keyword, index);
              if (pos == -1) break;

              // 提取上下文（前后各50个字符）
              final start = (pos - 50).clamp(0, content.length);
              final end = (pos + keyword.length + 50).clamp(0, content.length);
              final context = content.substring(start, end);

              results.add({
                'chapterIndex': i,
                'chapterTitle': chapter.title,
                'position': pos,
                'context': context,
                'match': keyword,
              });

              index = pos + keyword.length;
            }
          }
        }
      } finally {
        await mobiBook.close();
      }
    } catch (e) {
      AppLog.instance.put('搜索MOBI文件内容失败: ${file.path}', error: e);
    }

    return results;
  }

  /// 提取所有图片资源
  static Future<List<Map<String, dynamic>>> extractImages(File file) async {
    final images = <Map<String, dynamic>>[];
    try {
      final mobiBook = await MobiReader.readMobi(file);
      try {
        // 尝试获取封面
        final cover = await mobiBook.getCover();
        if (cover != null && cover.isNotEmpty) {
          images.add({
            'type': 'cover',
            'data': cover,
            'size': cover.length,
          });
        }

        // 注意：提取所有图片资源需要遍历资源记录
        // 这里只提取封面，完整实现需要解析资源索引
      } finally {
        await mobiBook.close();
      }
    } catch (e) {
      AppLog.instance.put('提取MOBI图片失败: ${file.path}', error: e);
    }

    return images;
  }

  /// 比较两个MOBI文件是否相同
  static Future<bool> compareFiles(File file1, File file2) async {
    try {
      final metadata1 = await getFileMetadata(file1);
      final metadata2 = await getFileMetadata(file2);

      if (metadata1 == null || metadata2 == null) {
        return false;
      }

      // 比较关键字段
      return metadata1['title'] == metadata2['title'] &&
          metadata1['author'] == metadata2['author'] &&
          metadata1['fileSize'] == metadata2['fileSize'];
    } catch (e) {
      return false;
    }
  }
}
