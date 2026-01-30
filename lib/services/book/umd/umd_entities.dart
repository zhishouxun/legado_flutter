/// UMD文件格式实体定义
/// 参考项目：me.ag2s.umdlib.domain.UmdBook
library;

import 'dart:typed_data';

/// UMD书籍元数据
class UmdMetadata {
  final String title;
  final String author;
  final String bookType;
  final String? publisher;
  final String? description;

  UmdMetadata({
    required this.title,
    required this.author,
    required this.bookType,
    this.publisher,
    this.description,
  });
}

/// UMD章节
class UmdChapter {
  final int index;
  final String title;
  final String content;

  UmdChapter({
    required this.index,
    required this.title,
    required this.content,
  });
}

/// UMD封面
class UmdCover {
  final Uint8List coverData;
  final String? mimeType;

  UmdCover({
    required this.coverData,
    this.mimeType,
  });
}

/// UMD文件头
class UmdHeader {
  final String title;
  final String author;
  final String bookType;
  final int chapterCount;
  final int? coverOffset;
  final int? contentOffset;

  UmdHeader({
    required this.title,
    required this.author,
    required this.bookType,
    required this.chapterCount,
    this.coverOffset,
    this.contentOffset,
  });
}

/// UMD章节列表
class UmdChapters {
  final List<String> titles;
  final Map<int, String> contents;

  UmdChapters({
    required this.titles,
    required this.contents,
  });

  /// 获取章节标题
  String getTitle(int index) {
    if (index >= 0 && index < titles.length) {
      return titles[index];
    }
    return '第${index + 1}章';
  }

  /// 获取章节内容
  String? getContentString(int index) {
    return contents[index];
  }

  /// 获取章节数量
  int get count => titles.length;
}
