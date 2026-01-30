# Legado解析器使用指南

## 概述

LegadoParser是一个高层封装的书源解析器,完全兼容Legado规则格式。它基于项目已有的RuleParser,提供了更简洁友好的API。

## 核心特性

✅ **完整规则支持**
- CSS选择器 (如 `class.book-item`)
- XPath (如 `//div[@class='item']`)
- JSONPath (如 `$.data.list`)
- JavaScript代码 (如 `{{$.title}}`)

✅ **Legado特有功能**
- `##`格式正则替换 (如 `##广告.*##`)
- 嵌套规则递归解析
- preUpdateJs、formatJs等JS钩子
- init初始化规则

✅ **性能优化**
- 支持compute函数后台执行
- 异步处理避免UI阻塞
- 完整的错误处理和日志

## 快速开始

### 1. 解析搜索结果

```dart
import 'package:legado_flutter/utils/parsers/legado_parser.dart';

final parser = LegadoParser();

// 解析搜索列表
final books = await parser.parseSearchList(
  htmlContent: response.data,
  bookSource: source,
  baseUrl: searchUrl,
);

// books 是 List<Map<String, dynamic>>
// 每个Map包含: name, author, kind, bookUrl, coverUrl 等字段
```

### 2. 解析书籍详情

```dart
final bookInfo = await parser.parseBookInfo(
  htmlContent: response.data,
  bookSource: source,
  baseUrl: bookUrl,
);

// bookInfo 包含:
// - name: 书名
// - author: 作者
// - intro: 简介
// - coverUrl: 封面URL
// - tocUrl: 目录URL
// 等字段
```

### 3. 解析目录列表

```dart
final chapters = await parser.parseTocList(
  htmlContent: response.data,
  bookSource: source,
  baseUrl: tocUrl,
);

// chapters 是 List<Map<String, dynamic>>
// 每个Map包含: chapterName, chapterUrl, isVip, isVolume 等字段
```

### 4. 解析正文内容

```dart
final contentData = await parser.parseContent(
  htmlContent: response.data,
  bookSource: source,
  baseUrl: chapterUrl,
);

// contentData 包含:
// - content: 正文内容(已净化)
// - nextContentUrl: 下一页URL(如果有)
```

## 高级用法

### 使用自定义变量

```dart
final books = await parser.parseSearchList(
  htmlContent: response.data,
  bookSource: source,
  baseUrl: searchUrl,
  variables: {
    'keyword': '玄幻',
    'page': '1',
  },
);
```

### 后台线程解析(大数据量)

```dart
// 使用compute函数在后台线程执行
final books = await LegadoParser.computeParse(
  parseFunction: (params) => parser.parseSearchList(
    htmlContent: params['html'],
    bookSource: params['source'],
    baseUrl: params['url'],
  ),
  params: {
    'html': response.data,
    'source': source,
    'url': searchUrl,
  },
);
```

## BookSource规则说明

### SearchRule (搜索规则)

```json
{
  "ruleSearch": {
    "bookList": "class.book-item",          // 列表规则
    "name": "tag.h3@text",                  // 书名
    "author": "class.author@text",          // 作者
    "bookUrl": "tag.a@href",                // 书籍URL
    "coverUrl": "tag.img@src",              // 封面URL
    "kind": "class.tags@text",              // 分类
    "intro": "class.intro@text",            // 简介
    "lastChapter": "class.last-chapter@text" // 最新章节
  }
}
```

### BookInfoRule (详情规则)

```json
{
  "ruleBookInfo": {
    "init": "{{一些初始化JS代码}}",         // 可选
    "name": "class.book-name@text",
    "author": "class.author@text",
    "intro": "id.intro@text",
    "coverUrl": "class.cover@src",
    "tocUrl": "class.catalog-link@href"
  }
}
```

### TocRule (目录规则)

```json
{
  "ruleToc": {
    "preUpdateJs": "{{目录解析前执行的JS}}",  // 可选
    "chapterList": "class.chapter-item",
    "chapterName": "tag.a@text",
    "chapterUrl": "tag.a@href",
    "formatJs": "{{格式化章节名的JS}}",       // 可选
    "isVolume": "tag.h2"                     // 卷名判断
  }
}
```

### ContentRule (正文规则)

```json
{
  "ruleContent": {
    "webJs": "{{网页加载前的JS}}",           // 可选
    "content": "id.content@text",
    "sourceRegex": "##<script>.*?</script>##",  // 净化规则
    "replaceRegex": "##广告.*##",              // 替换规则
    "nextContentUrl": "id.next-page@href"     // 下一页
  }
}
```

## 规则语法详解

### CSS选择器

```
class.book-item      # class="book-item"
tag.h3               # <h3> 标签
id.content           # id="content"
tag.a@href           # 获取<a>的href属性
tag.img@src          # 获取<img>的src属性
tag.div@text         # 获取<div>的文本内容
```

### XPath

```
//div[@class='item']              # XPath选择器
//a[@href]/@href                  # 获取href属性
//div[@id='content']/text()       # 获取文本
```

### JSONPath

```
$.data.list             # JSON路径
$.items[*].name         # 遍历数组
```

### JavaScript

```
{{$.title}}                        # 执行JS并返回结果
{{$.replace(/广告/, '')}}          # JS字符串处理
```

### 正则替换 (##格式)

```
##<script>.*?</script>##           # 删除script标签
##广告.*##替换文本##               # 替换广告文字
```

## 与BookRemoteDataSourceImpl集成

```dart
@override
Future<List<Book>> searchBooks(
  String keyword,
  BookSource bookSource, {
  int page = 1,
}) async {
  // 1. 构建搜索URL
  final searchUrl = bookSource.searchUrl?.replaceAll('{{key}}', keyword);
  
  // 2. 发起网络请求
  final response = await _dio.get(searchUrl);
  
  // 3. 使用LegadoParser解析
  final parser = LegadoParser();
  final booksData = await parser.parseSearchList(
    htmlContent: response.data,
    bookSource: bookSource,
    baseUrl: searchUrl,
  );
  
  // 4. 转换为Book实体
  return booksData.map((data) {
    return Book(
      name: data['name'] ?? '',
      author: data['author'] ?? '',
      bookUrl: data['bookUrl'] ?? '',
      coverUrl: data['coverUrl'],
      intro: data['intro'],
      // ...其他字段
    );
  }).toList();
}
```

## 错误处理

LegadoParser内置了完整的错误处理:

- 解析失败不会抛出异常,而是返回空列表/空Map
- 所有错误都会记录到AppLog
- 支持查看详细的错误堆栈信息

```dart
// 错误会自动记录,返回空结果
final books = await parser.parseSearchList(
  htmlContent: invalidHtml,
  bookSource: source,
  baseUrl: url,
);
// books 将是 []
```

## 性能建议

1. **批量解析**: 对于大量数据,建议使用`computeParse`在后台线程执行
2. **缓存结果**: 搜索结果可以缓存到数据库,避免重复解析
3. **懒加载**: 目录列表可以分页加载,不用一次解析所有章节

## 调试技巧

1. 查看AppLog输出,了解解析过程
2. 使用BookSourceDebugService测试规则
3. 参考10月/16精选书源.json中的规则示例

## 总结

LegadoParser提供了完整的Legado规则兼容性,是连接网络数据和应用实体的桥梁。通过简洁的API,可以轻松集成到BookRemoteDataSourceImpl中,实现书源解析功能。
