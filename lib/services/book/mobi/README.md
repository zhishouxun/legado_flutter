# MOBI解析器使用文档

## 一、概述

MOBI解析器是一个完整的MOBI/AZW/AZW3格式电子书解析库，支持章节解析、内容提取、元数据读取等功能。

## 二、快速开始

### 1. 基本使用

```dart
import 'package:legado_flutter/services/book/mobi/mobi_reader.dart';
import 'dart:io';

// 读取MOBI文件
final file = File('/path/to/book.mobi');
final mobiBook = await MobiReader.readMobi(file);

try {
  // 获取元数据
  final metadata = mobiBook.metadata;
  print('标题: ${metadata.title}');
  print('作者: ${metadata.creators.join(', ')}');
  
  // 获取章节列表
  final chapters = await mobiBook.getChapters();
  print('章节数: ${chapters.length}');
  
  // 获取章节内容
  final content = await mobiBook.getChapterContent(chapters[0]);
  print('第一章: ${content?.substring(0, 100)}...');
} finally {
  await mobiBook.close();
}
```

### 2. 文件验证

```dart
// 快速验证文件
final isValid = await MobiReader.isValidMobiFile(file);
if (!isValid) {
  print('文件不是有效的MOBI文件');
  return;
}

// 详细验证
final mobiBook = await MobiReader.readMobi(file);
try {
  final validation = await mobiBook.validateFile();
  if (!validation['isValid']) {
    print('文件验证失败:');
    for (final issue in validation['issues']) {
      print('  - $issue');
    }
  }
} finally {
  await mobiBook.close();
}
```

## 三、主要功能

### 1. 元数据读取

```dart
final metadata = mobiBook.metadata;
// metadata.title - 标题
// metadata.creators - 作者列表
// metadata.publisher - 出版社
// metadata.language - 语言
// metadata.description - 描述
// metadata.subjects - 主题列表
```

### 2. 章节解析

```dart
// 获取所有章节
final chapters = await mobiBook.getChapters();

// 获取章节数量
final count = await mobiBook.getChapterCount();

// 检查是否有NCX索引
if (mobiBook.hasNCX) {
  print('文件包含NCX索引');
}

// 获取NCX原始数据
final ncxList = await mobiBook.getNCX();
```

### 3. 内容提取

```dart
// 根据章节对象获取内容
final content = await mobiBook.getChapterContent(chapter);

// 根据href获取内容
final content2 = await mobiBook.getChapterContentByHref('filepos:0000000123');

// 根据位置范围获取内容
final content3 = await mobiBook.getTextByRange(1000, 5000);

// 根据文件位置获取内容
final content4 = await mobiBook.getTextByFilepos(1000, maxLength: 10000);
```

### 4. 章节导航

```dart
// 获取相邻章节
final [prevIndex, nextIndex] = await mobiBook.getAdjacentChapters(5);

// 根据位置查找章节
final chapterIndex = await mobiBook.findChapterByPosition(10000);

// 获取章节范围
final rangeContent = await mobiBook.getChaptersRange(0, 2);
```

### 5. 章节预览

```dart
// 获取章节预览（默认500字符）
final preview = await mobiBook.getChapterPreview(0);

// 自定义预览长度
final preview2 = await mobiBook.getChapterPreview(0, previewLength: 300);
```

### 6. 统计信息

```dart
// 获取文件信息
final info = await mobiBook.getFileInfo();

// 获取章节统计
final stats = await mobiBook.getChapterStatistics(0);

// 获取所有章节统计
final allStats = await mobiBook.getAllChaptersStatistics();
```

### 7. 导出功能

```dart
// 导出为纯文本
final success = await mobiBook.exportToText('/path/to/output.txt');
```

## 四、工具方法

### MobiUtils类

```dart
import 'package:legado_flutter/services/book/mobi/mobi_utils_extended.dart';

// 获取文件元数据（快速）
final metadata = await MobiUtils.getFileMetadata(file);

// 批量获取文件元数据
final metadatas = await MobiUtils.getFilesMetadata([file1, file2, file3]);

// 检查文件是否损坏
final isCorrupted = await MobiUtils.isFileCorrupted(file);

// 获取文件统计信息
final stats = await MobiUtils.getFileStatistics(file);

// 搜索文本
final results = await MobiUtils.searchText(file, '关键词', maxResults: 50);

// 提取图片
final images = await MobiUtils.extractImages(file);

// 比较文件
final isSame = await MobiUtils.compareFiles(file1, file2);
```

## 五、常量定义

### 压缩格式

```dart
import 'package:legado_flutter/services/book/mobi/mobi_constants.dart';

MobiCompression.plain      // 1 - 无压缩
MobiCompression.lz77      // 2 - LZ77压缩
MobiCompression.huffcdic  // 17480 - Huffcdic压缩（不支持）

// 获取压缩格式名称
final name = MobiCompression.getName(compression);

// 检查是否支持
final supported = MobiCompression.isSupported(compression);
```

### 编码格式

```dart
MobiEncoding.utf8         // 65001 - UTF-8
MobiEncoding.windows1252  // 1252 - Windows-1252

// 获取编码名称
final name = MobiEncoding.getName(encoding);
```

### 文件类型

```dart
MobiFileType.mobi   // '.mobi'
MobiFileType.azw    // '.azw'
MobiFileType.azw3   // '.azw3'

// 检查扩展名是否支持
final supported = MobiFileType.isSupported('.mobi');
```

## 六、异常处理

```dart
try {
  final mobiBook = await MobiReader.readMobi(file);
  // 使用mobiBook...
} on MobiFormatException catch (e) {
  print('文件格式错误: $e');
} on MobiCompressionException catch (e) {
  print('压缩格式不支持: $e');
} on MobiIndexOutOfBoundsException catch (e) {
  print('索引越界: $e');
} on MobiCorruptedException catch (e) {
  print('文件损坏: $e');
} catch (e) {
  print('其他错误: $e');
}
```

## 七、性能优化

### 缓存机制

MOBI解析器自动缓存已解压的文本记录，重复读取相同章节时性能提升显著。

```dart
// 缓存会自动管理，无需手动操作
// 关闭文件时会自动清理缓存
await mobiBook.close();
```

### 批量读取

```dart
// 批量获取文本记录（利用缓存）
final records = await mobiBook.getTextRecordsBatch([0, 1, 2, 3, 4]);
```

## 八、已知限制

1. **Huffcdic压缩** - 当前不支持，会抛出`MobiCompressionException`
2. **KF8格式** - 基础支持，完整实现需要更多工作
3. **图片资源** - 当前只支持封面提取，完整图片列表需要更多工作

## 九、最佳实践

1. **总是使用try-finally**
   ```dart
   final mobiBook = await MobiReader.readMobi(file);
   try {
     // 使用mobiBook...
   } finally {
     await mobiBook.close();
   }
   ```

2. **先验证文件**
   ```dart
   final isValid = await MobiReader.isValidMobiFile(file);
   if (!isValid) {
     // 处理无效文件
     return;
   }
   ```

3. **使用批量操作**
   ```dart
   // 批量获取章节统计
   final stats = await mobiBook.getAllChaptersStatistics();
   ```

4. **处理异常**
   ```dart
   try {
     final content = await mobiBook.getChapterContent(chapter);
   } catch (e) {
     // 处理错误
   }
   ```

## 十、示例代码

### 完整的文件处理示例

```dart
import 'dart:io';
import 'package:legado_flutter/services/book/mobi/mobi_reader.dart';
import 'package:legado_flutter/services/book/mobi/mobi_utils_extended.dart';

Future<void> processMobiFile(File file) async {
  // 1. 验证文件
  final isValid = await MobiReader.isValidMobiFile(file);
  if (!isValid) {
    print('文件不是有效的MOBI文件');
    return;
  }

  // 2. 获取快速元数据
  final metadata = await MobiUtils.getFileMetadata(file);
  if (metadata != null) {
    print('标题: ${metadata['title']}');
    print('作者: ${metadata['author']}');
  }

  // 3. 读取文件
  final mobiBook = await MobiReader.readMobi(file);
  try {
    // 4. 验证文件完整性
    final validation = await mobiBook.validateFile();
    if (!validation['isValid']) {
      print('文件验证失败:');
      for (final issue in validation['issues']) {
        print('  - $issue');
      }
    }

    // 5. 获取文件信息
    final info = await mobiBook.getFileInfo();
    print('文件信息: $info');

    // 6. 获取章节列表
    final chapters = await mobiBook.getChapters();
    print('章节数: ${chapters.length}');

    // 7. 获取章节预览
    if (chapters.isNotEmpty) {
      final preview = await mobiBook.getChapterPreview(0);
      print('第一章预览: $preview');
    }

    // 8. 搜索文本
    final results = await MobiUtils.searchText(file, '关键词', maxResults: 10);
    print('找到 ${results.length} 个匹配结果');
  } finally {
    await mobiBook.close();
  }
}
```

## 十一、API参考

### MobiReader类

- `isValidMobiFile(File file)` - 验证MOBI文件
- `readMobi(File file)` - 读取MOBI文件

### SimpleMobiBook类

#### 属性
- `metadata` - 元数据
- `hasNCX` - 是否有NCX索引
- `isKF8` - 是否是KF8格式
- `charset` - 字符集

#### 方法
- `getChapters()` - 获取章节列表
- `getChapterCount()` - 获取章节数量
- `getNCX()` - 获取NCX数据
- `getChapterContent(MobiChapter)` - 获取章节内容
- `getChapterContentByHref(String)` - 根据href获取内容
- `getTextByRange(int, int)` - 根据范围获取文本
- `getTextByFilepos(int, {int?})` - 根据位置获取文本
- `getChapterPreview(int, {int})` - 获取章节预览
- `getAdjacentChapters(int)` - 获取相邻章节
- `findChapterByPosition(int)` - 根据位置查找章节
- `getChaptersRange(int, int)` - 获取章节范围
- `getChapterStatistics(int)` - 获取章节统计
- `getAllChaptersStatistics()` - 获取所有章节统计
- `getFileInfo()` - 获取文件信息
- `validateFile()` - 验证文件
- `getCover()` - 获取封面
- `exportToText(String)` - 导出为文本
- `close()` - 关闭文件

### MobiUtils类

- `getFileMetadata(File)` - 获取文件元数据
- `getFilesMetadata(List<File>)` - 批量获取文件元数据
- `isFileCorrupted(File)` - 检查文件是否损坏
- `getFileStatistics(File)` - 获取文件统计
- `searchText(File, String, {int})` - 搜索文本
- `extractImages(File)` - 提取图片
- `compareFiles(File, File)` - 比较文件

## 十二、更新日志

### v1.0.0
- 初始版本
- 支持MOBI/AZW/AZW3格式
- 支持NCX章节解析
- 支持Plain和LZ77压缩
- 完整的异常处理
- 文件验证功能
- 章节导航功能
- 导出功能

