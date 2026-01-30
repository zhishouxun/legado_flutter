/// UMD书籍类
/// 参考项目：me.ag2s.umdlib.domain.UmdBook
///
/// 使用示例：
/// ```dart
/// // 读取UMD文件
/// final umdBook = await UmdReader.readUmd(file);
///
/// try {
///   // 获取元数据
///   final metadata = umdBook.metadata;
///   print('标题: ${metadata.title}');
///   print('作者: ${metadata.author}');
///
///   // 获取章节列表
///   final chapters = await umdBook.getChapters();
///   print('章节数: ${chapters.length}');
///
///   // 获取章节内容
///   final content = await umdBook.getChapterContent(chapters[0]);
///   print('第一章内容: ${content?.substring(0, 100)}...');
/// } finally {
///   await umdBook.close();
/// }
/// ```
library;

import 'dart:typed_data';
import 'umd_entities.dart';
import '../../../utils/app_log.dart';

/// UMD书籍类
class SimpleUmdBook {
  final String filePath;
  final UmdHeader header;
  final UmdChapters chapters;
  final UmdCover? cover;
  final Uint8List rawData;

  SimpleUmdBook({
    required this.filePath,
    required this.header,
    required this.chapters,
    this.cover,
    required this.rawData,
  });

  /// 获取元数据
  UmdMetadata get metadata {
    return UmdMetadata(
      title: header.title,
      author: header.author,
      bookType: header.bookType,
      description: null,
    );
  }

  /// 获取章节列表
  /// 返回章节对象列表
  Future<List<UmdChapter>> getChapters() async {
    final result = <UmdChapter>[];

    for (int i = 0; i < chapters.count; i++) {
      final title = chapters.getTitle(i);
      final content = chapters.getContentString(i) ?? '';

      result.add(UmdChapter(
        index: i,
        title: title,
        content: content,
      ));
    }

    return result;
  }

  /// 获取章节内容
  /// [chapter] 章节对象
  /// 返回章节内容字符串
  Future<String?> getChapterContent(UmdChapter chapter) async {
    try {
      return chapters.getContentString(chapter.index);
    } catch (e) {
      AppLog.instance.put('获取UMD章节内容失败: ${chapter.title}', error: e);
      return null;
    }
  }

  /// 根据索引获取章节内容
  Future<String?> getChapterContentByIndex(int index) async {
    try {
      return chapters.getContentString(index);
    } catch (e) {
      AppLog.instance.put('获取UMD章节内容失败: index=$index', error: e);
      return null;
    }
  }

  /// 获取封面
  Future<Uint8List?> getCover() async {
    return cover?.coverData;
  }

  /// 获取章节数量
  int getChapterCount() {
    return chapters.count;
  }

  /// 关闭资源
  /// 注意：UMD文件通常不需要特殊的关闭操作，但为了保持接口一致性提供此方法
  Future<void> close() async {
    // UMD文件通常不需要特殊的关闭操作
    // 这里可以做一些清理工作
  }

  /// 验证文件
  Future<Map<String, dynamic>> validateFile() async {
    final issues = <String>[];

    if (header.title.isEmpty || header.title == '未知标题') {
      issues.add('无法解析书籍标题');
    }

    if (chapters.count == 0) {
      issues.add('未找到章节');
    }

    return {
      'isValid': issues.isEmpty,
      'issues': issues,
    };
  }
}
