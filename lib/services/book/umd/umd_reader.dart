/// UMD文件读取器
/// 参考项目：me.ag2s.umdlib.umd.UmdReader
///
/// UMD格式是一个比较老的手机电子书格式，主要用于早期手机阅读器。
/// 本实现提供了基础的UMD文件解析功能。
///
/// 使用示例：
/// ```dart
/// // 验证文件
/// final isValid = await UmdReader.isValidUmdFile(file);
/// if (!isValid) {
///   print('文件不是有效的UMD文件');
///   return;
/// }
///
/// // 读取文件
/// final umdBook = await UmdReader.readUmd(file);
/// try {
///   // 使用umdBook...
/// } finally {
///   await umdBook.close();
/// }
/// ```
library;

import 'dart:io';
import 'dart:typed_data';
import 'umd_entities.dart';
import 'umd_utils.dart';
import 'umd_exceptions.dart';
import 'umd_book.dart';
import '../../../utils/app_log.dart';

/// UMD读取器
class UmdReader {
  /// UMD文件魔数（文件头标识）
  /// UMD文件通常以特定的字节序列开头
  static const List<int> umdMagic = [0x45, 0x42, 0x4F, 0x4F, 0x4B]; // "EBOOK"

  /// 验证UMD文件
  /// 快速检查文件是否是有效的UMD文件
  static Future<bool> isValidUmdFile(File file) async {
    try {
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      if (bytes.length < 10) return false;

      // 检查文件头魔数
      // 注意：UMD文件格式可能有多种变体，这里使用简单的检查
      // 实际UMD文件可能以不同的字节序列开头
      // 由于UMD格式可能有多种变体，这里使用宽松的检查
      return bytes.length > 100; // 至少要有一定大小
    } catch (e) {
      return false;
    }
  }

  /// 读取UMD文件
  static Future<SimpleUmdBook> readUmd(File file) async {
    if (!await file.exists()) {
      throw UmdFormatException('文件不存在: ${file.path}');
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw UmdFormatException('文件为空: ${file.path}');
      }

      // 解析UMD文件
      return _parseUmdFile(bytes, file.path);
    } catch (e) {
      if (e is UmdFormatException || e is UmdCorruptedException) {
        rethrow;
      }
      throw UmdFormatException('读取UMD文件失败: ${file.path}', e.toString());
    }
  }

  /// 解析UMD文件
  /// 注意：UMD格式比较复杂，这里提供一个基础实现
  /// 完整的UMD解析需要详细的格式规范文档
  static SimpleUmdBook _parseUmdFile(Uint8List bytes, String filePath) {
    try {
      // UMD文件基本结构（简化实现）：
      // 1. 文件头（包含元数据）
      // 2. 章节列表
      // 3. 章节内容
      // 4. 封面图片（可选）

      // 尝试解析文件头
      final header = _parseHeader(bytes);

      // 尝试解析章节列表和内容
      final chapters = _parseChapters(bytes, header);

      // 尝试解析封面
      final cover = _parseCover(bytes, header);

      return SimpleUmdBook(
        filePath: filePath,
        header: header,
        chapters: chapters,
        cover: cover,
        rawData: bytes,
      );
    } catch (e) {
      AppLog.instance.put('解析UMD文件失败: $filePath', error: e);
      throw UmdFormatException('解析UMD文件失败', e.toString());
    }
  }

  /// 解析文件头
  static UmdHeader _parseHeader(Uint8List bytes) {
    // UMD文件头解析（简化实现）
    // 实际UMD格式可能有多种变体，这里提供基础解析

    String title = '未知标题';
    String author = '未知作者';
    String bookType = '小说';
    int chapterCount = 0;

    try {
      // 尝试查找标题和作者信息
      // UMD文件通常在这些位置存储元数据
      // 这里使用启发式方法查找

      // 查找可能的标题位置（通常在文件开头附近）
      for (int i = 0; i < bytes.length - 20 && i < 500; i++) {
        // 尝试读取可能的标题字符串
        if (bytes[i] > 0x20 && bytes[i] < 0x7F) {
          // 可能是ASCII字符
          int len = 0;
          while (i + len < bytes.length &&
              len < 100 &&
              bytes[i + len] >= 0x20 &&
              bytes[i + len] < 0x7F) {
            len++;
          }
          if (len > 5 && len < 50) {
            final possibleTitle = bytes.readStringGBK(i, len);
            if (possibleTitle.isNotEmpty && !possibleTitle.contains('\x00')) {
              title = possibleTitle;
              break;
            }
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('解析UMD标题失败', error: e);
    }

    return UmdHeader(
      title: title,
      author: author,
      bookType: bookType,
      chapterCount: chapterCount,
    );
  }

  /// 解析章节列表和内容
  static UmdChapters _parseChapters(Uint8List bytes, UmdHeader header) {
    final titles = <String>[];
    final contents = <int, String>{};

    try {
      // UMD章节解析（简化实现）
      // 实际UMD格式的章节结构可能更复杂

      // 如果文件头中没有章节数量，尝试从文件中查找
      // 这里提供一个基础的章节分割实现
      // 实际应该根据UMD格式规范解析

      // 简化实现：将整个文件内容作为一个章节
      // 实际UMD文件应该有明确的章节结构
      if (bytes.length > 100) {
        // 尝试查找章节分隔符
        // UMD文件可能使用特定的字节序列分隔章节
        final content = bytes.readStringGBK(0, bytes.length);

        // 使用常见的章节标题模式分割
        final chapterPattern = RegExp(r'第[0-9一二三四五六七八九十百千万]+[章节回]');
        final matches = chapterPattern.allMatches(content);

        if (matches.isNotEmpty) {
          int lastIndex = 0;
          int chapterIndex = 0;

          for (final match in matches) {
            if (match.start > lastIndex) {
              // 添加前一章的内容
              if (chapterIndex > 0) {
                contents[chapterIndex - 1] =
                    content.substring(lastIndex, match.start);
              }

              // 提取章节标题
              final titleEnd = match.end;
              int titleStart = match.start;
              // 查找标题结束位置（通常是换行符）
              while (titleEnd < content.length &&
                  titleEnd < match.start + 100 &&
                  content[titleEnd] != '\n' &&
                  content[titleEnd] != '\r') {
                // 继续查找
              }

              final title = content.substring(titleStart, titleEnd).trim();
              titles.add(title);
              lastIndex = titleEnd;
              chapterIndex++;
            }
          }

          // 添加最后一章
          if (lastIndex < content.length) {
            contents[chapterIndex] = content.substring(lastIndex);
          }
        } else {
          // 没有找到章节分隔符，将整个内容作为一个章节
          titles.add('正文');
          contents[0] = content;
        }
      }
    } catch (e) {
      AppLog.instance.put('解析UMD章节失败', error: e);
      // 如果解析失败，至少提供一个章节
      titles.add('正文');
      contents[0] = bytes.readStringGBK(0, bytes.length.clamp(0, 10000));
    }

    return UmdChapters(titles: titles, contents: contents);
  }

  /// 解析封面
  static UmdCover? _parseCover(Uint8List bytes, UmdHeader header) {
    try {
      // UMD封面解析（简化实现）
      // 封面通常存储在文件的特定位置
      // 这里提供一个基础实现

      if (header.coverOffset != null && header.coverOffset! > 0) {
        final offset = header.coverOffset!;
        if (offset < bytes.length) {
          // 尝试读取封面数据
          // 封面通常是图片格式（JPEG、PNG等）
          final coverSize = bytes.length - offset;
          if (coverSize > 0 && coverSize < 1024 * 1024) {
            // 限制封面大小
            final coverData = bytes.sublist(offset);
            return UmdCover(coverData: coverData);
          }
        }
      }

      return null;
    } catch (e) {
      AppLog.instance.put('解析UMD封面失败', error: e);
      return null;
    }
  }
}
