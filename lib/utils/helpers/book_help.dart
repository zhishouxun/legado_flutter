/// 书籍帮助工具类
/// 参考项目：io.legado.app.help.book.BookHelp
///
/// 提供书籍相关的工具方法，包括：
/// - 章节定位算法（换源时定位阅读进度）
/// - 章节名称解析
/// - 文本相似度计算
/// - 章节缓存管理
/// - 图片缓存管理
library;

import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../string_utils.dart';
import '../file_utils.dart';
import '../app_log.dart';
import '../network_utils.dart';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';

/// 书籍帮助工具类
/// 参考项目：io.legado.app.help.book.BookHelp
class BookHelp {
  BookHelp._();

  // ========== 章节定位相关 ==========

  /// 根据目录名获取当前章节索引
  /// 参考项目：BookHelp.getDurChapter
  ///
  /// 用于换源时，根据旧章节名称在新目录中定位对应章节
  ///
  /// [oldDurChapterIndex] 旧的当前章节索引
  /// [oldDurChapterName] 旧的当前章节名称
  /// [newChapterList] 新的章节列表
  /// [oldChapterListSize] 旧章节列表大小（用于比例计算）
  ///
  /// 返回新目录中对应的章节索引
  static int getDurChapter(
    int oldDurChapterIndex,
    String? oldDurChapterName,
    List<BookChapter> newChapterList, [
    int oldChapterListSize = 0,
  ]) {
    if (oldDurChapterIndex <= 0) return 0;
    if (newChapterList.isEmpty) return oldDurChapterIndex;

    final oldChapterNum = _getChapterNum(oldDurChapterName);
    final oldName = _getPureChapterName(oldDurChapterName);
    final newChapterSize = newChapterList.length;

    // 根据比例估算新章节索引
    final durIndex = oldChapterListSize == 0
        ? oldDurChapterIndex
        : (oldDurChapterIndex * newChapterSize / oldChapterListSize).round();

    // 搜索范围：前后各10章
    final minIndex = max(0, min(oldDurChapterIndex, durIndex) - 10);
    final maxIndex =
        min(newChapterSize - 1, max(oldDurChapterIndex, durIndex) + 10);

    double nameSim = 0.0;
    int newIndex = 0;
    int newNum = 0;

    // 首先通过章节名称相似度匹配
    if (oldName.isNotEmpty) {
      for (int i = minIndex; i <= maxIndex; i++) {
        final newName = _getPureChapterName(newChapterList[i].title);
        final temp = _jaccardSimilarity(oldName, newName);
        if (temp > nameSim) {
          nameSim = temp;
          newIndex = i;
        }
      }
    }

    // 如果名称相似度不够高，尝试通过章节序号匹配
    if (nameSim < 0.96 && oldChapterNum > 0) {
      for (int i = minIndex; i <= maxIndex; i++) {
        final temp = _getChapterNum(newChapterList[i].title);
        if (temp == oldChapterNum) {
          newNum = temp;
          newIndex = i;
          break;
        } else if ((temp - oldChapterNum).abs() <
            (newNum - oldChapterNum).abs()) {
          newNum = temp;
          newIndex = i;
        }
      }
    }

    // 返回最佳匹配结果
    if (nameSim > 0.96 || (newNum - oldChapterNum).abs() < 1) {
      return newIndex;
    } else {
      return min(max(0, newChapterList.length - 1), oldDurChapterIndex);
    }
  }

  /// 根据书籍获取当前章节索引
  /// 参考项目：BookHelp.getDurChapter(oldBook, newChapterList)
  static int getDurChapterFromBook(
    Book oldBook,
    List<BookChapter> newChapterList,
  ) {
    return getDurChapter(
      oldBook.durChapterIndex,
      oldBook.durChapterTitle,
      newChapterList,
      oldBook.totalChapterNum,
    );
  }

  // ========== 章节名称解析 ==========

  /// 章节序号正则1: "第X章/节/篇/回/集/话"
  static final RegExp _chapterNamePattern1 = RegExp(
    r'.*?第([\d零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+)[章节篇回集话]',
  );

  /// 章节序号正则2: 数字开头 "1,2,3" 或 "1、2、3"
  static final RegExp _chapterNamePattern2 = RegExp(
    r'^(?:[\d零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+[,:、])*([\d零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+)(?:[,:、]|\.[^\d])',
  );

  /// 空白字符正则
  static final RegExp _regexWhitespace = RegExp(r'\s');

  /// 章节序号正则（用于提取纯章节名）
  static final RegExp _regexChapterNum = RegExp(
    r'^.*?第(?:[\d零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+)[章节篇回集话](?!$)|^(?:[\d零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+[,:、])*(?:[\d零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+)(?:[,:、](?!$)|\.(?=[^\d]))',
  );

  /// 括号内容正则
  static final RegExp _regexBrackets = RegExp(
    r'(?!^)(?:[〖【《〔\[{(][^〖【《〔\[{()〕》】〗\]}]+)?[)〕》】〗\]}]$|^[〖【《〔\[{(](?:[^〖【《〔\[{()〕》】〗\]}]+[〕》】〗\]})])?(?!$)',
  );

  /// 非字母数字中日韩文字
  static final RegExp _regexNonAlphanumericCJK = RegExp(
    r'[^\w\u4E00-\u9FEF〇\u3400-\u4DBF]',
  );

  /// 从章节名称中提取章节序号
  /// 参考项目：BookHelp.getChapterNum
  static int _getChapterNum(String? chapterName) {
    if (chapterName == null) return -1;

    final name =
        StringUtils.fullToHalf(chapterName).replaceAll(_regexWhitespace, '');

    // 尝试匹配第一种格式
    final match1 = _chapterNamePattern1.firstMatch(name);
    if (match1 != null) {
      return StringUtils.stringToInt(match1.group(1) ?? '-1');
    }

    // 尝试匹配第二种格式
    final match2 = _chapterNamePattern2.firstMatch(name);
    if (match2 != null) {
      return StringUtils.stringToInt(match2.group(1) ?? '-1');
    }

    return -1;
  }

  /// 获取纯章节名称（去除序号和附加内容）
  /// 参考项目：BookHelp.getPureChapterName
  static String _getPureChapterName(String? chapterName) {
    if (chapterName == null) return '';

    return StringUtils.fullToHalf(chapterName)
        .replaceAll(_regexWhitespace, '')
        .replaceAll(_regexChapterNum, '')
        .replaceAll(_regexBrackets, '')
        .replaceAll(_regexNonAlphanumericCJK, '');
  }

  // ========== 文本相似度计算 ==========

  /// Jaccard 相似度计算
  /// 参考项目：使用 Apache Commons Text 的 JaccardSimilarity
  ///
  /// Jaccard 系数 = 交集大小 / 并集大小
  static double _jaccardSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final setA = a.split('').toSet();
    final setB = b.split('').toSet();

    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;

    return union == 0 ? 0.0 : intersection / union;
  }

  // ========== 书名/作者格式化 ==========

  /// 格式化书名（去除特殊字符）
  /// 参考项目：BookHelp.formatBookName
  static final RegExp _nameRegex = RegExp(
    r'[(（\erta Mo Mo Mo Mo《<erta Mo Mo Mo《Mo Mo Mo][Mo Mo Mo Mo)](Mo[(Mo](Mo Mo[(Mo Mo](Mo Mo Mo]',
  );

  static String formatBookName(String name) {
    // 移除书名号等特殊字符
    return name
        .replaceAll(RegExp(r'[Mo Mo Mo Mo Mo Mo《Mo》<>Mo Mo]'), '')
        .trim();
  }

  /// 格式化作者名（去除"作者:"等前缀）
  /// 参考项目：BookHelp.formatBookAuthor
  static final RegExp _authorRegex = RegExp(
    r'(作\s*者|出\s*品|文\s*/|翻\s*译|原\s*著|著者)[：:Mo]?\s*',
  );

  static String formatBookAuthor(String author) {
    return author.replaceAll(_authorRegex, '').trim();
  }

  // ========== 常量定义 ==========

  /// 图片样式常量
  static const String imgStyleDefault = 'DEFAULT';
  static const String imgStyleFull = 'FULL';
  static const String imgStyleText = 'TEXT';
  static const String imgStyleSingle = 'SINGLE';

  /// 标签常量
  static const int hTag = 2;
  static const int rubyTag = 4;

  // ========== 缓存目录管理 ==========

  static Directory? _downloadDir;
  static const String _cacheFolderName = 'book_cache';
  static const String _cacheImageFolderName = 'images';
  static const String _cacheEpubFolderName = 'epub';

  /// 初始化缓存目录
  static Future<void> _ensureInitialized() async {
    if (_downloadDir != null) return;
    _downloadDir = await getApplicationSupportDirectory();
  }

  /// 获取缓存路径
  static Future<String> getCachePath() async {
    await _ensureInitialized();
    return '${_downloadDir!.path}/$_cacheFolderName';
  }

  /// 获取书籍缓存文件夹名称
  /// 参考项目：Book.getFolderNameNoCache()
  /// 使用书名前9位 + MD5(bookUrl) 作为文件夹名
  static String getBookFolderName(Book book) {
    // 参考项目：移除文件名非法字符
    final cleanName = book.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    // 参考项目：取书名前9位
    final prefix = cleanName.length > 9 ? cleanName.substring(0, 9) : cleanName;
    // 参考项目：使用 bookUrl 的 MD5 前16位
    final hash =
        md5.convert(utf8.encode(book.bookUrl)).toString().substring(0, 16);
    return '$prefix$hash';
  }

  /// 获取章节缓存文件名
  /// 参考项目：BookChapter.getFileName
  static String getChapterFileName(BookChapter chapter,
      [String suffix = 'nb']) {
    final titleMd5 =
        md5.convert(utf8.encode(chapter.title)).toString().substring(0, 16);
    return '${chapter.index.toString().padLeft(5, '0')}-$titleMd5.$suffix';
  }

  // ========== 章节缓存操作 ==========

  /// 检测该章节是否已缓存
  /// 参考项目：BookHelp.hasContent
  static Future<bool> hasContent(Book book, BookChapter chapter) async {
    // 本地TXT或卷名章节返回true
    if (book.isLocal ||
        (chapter.isVolume && chapter.url.startsWith(chapter.title))) {
      return true;
    }

    await _ensureInitialized();
    final filePath = await _getChapterFilePath(book, chapter);
    return File(filePath).existsSync();
  }

  /// 保存章节文本内容
  /// 参考项目：BookHelp.saveText
  static Future<void> saveText(
    Book book,
    BookChapter chapter,
    String content,
  ) async {
    if (content.isEmpty) return;

    await _ensureInitialized();
    final filePath = await _getChapterFilePath(book, chapter);
    final file = File(filePath);

    // 确保目录存在
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// 读取章节文本内容
  /// 参考项目：BookHelp.getContent
  static Future<String?> getContent(Book book, BookChapter chapter) async {
    await _ensureInitialized();
    final filePath = await _getChapterFilePath(book, chapter);
    final file = File(filePath);

    if (await file.exists()) {
      final content = await file.readAsString();
      return content.isEmpty ? null : content;
    }
    return null;
  }

  /// 删除章节缓存
  /// 参考项目：BookHelp.delContent
  static Future<void> delContent(Book book, BookChapter chapter) async {
    await _ensureInitialized();
    final filePath = await _getChapterFilePath(book, chapter);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 获取章节缓存文件路径
  static Future<String> _getChapterFilePath(
      Book book, BookChapter chapter) async {
    final cachePath = await getCachePath();
    final bookFolder = getBookFolderName(book);
    final chapterFile = getChapterFileName(chapter);
    return '$cachePath/$bookFolder/$chapterFile';
  }

  // ========== 图片缓存操作 ==========

  /// 图片正则表达式
  static final RegExp imgPattern = RegExp(r'<img[^>]*src="([^"]+)"[^>]*>');

  /// 获取图片后缀
  /// 参考项目：BookHelp.getImageSuffix
  static String getImageSuffix(String src) {
    final uri = Uri.tryParse(src);
    if (uri == null) return 'jpg';

    final path = uri.path.toLowerCase();
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.gif')) return 'gif';
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.bmp')) return 'bmp';
    if (path.endsWith('.svg')) return 'svg';
    return 'jpg';
  }

  /// 获取图片缓存文件路径
  /// 参考项目：BookHelp.getImage
  static Future<String> getImagePath(Book book, String src) async {
    await _ensureInitialized();
    final cachePath = await getCachePath();
    final bookFolder = getBookFolderName(book);
    final srcMd5 = md5.convert(utf8.encode(src)).toString().substring(0, 16);
    final suffix = getImageSuffix(src);
    return '$cachePath/$bookFolder/$_cacheImageFolderName/$srcMd5.$suffix';
  }

  /// 检查图片是否已缓存
  /// 参考项目：BookHelp.isImageExist
  static Future<bool> isImageExist(Book book, String src) async {
    final imagePath = await getImagePath(book, src);
    return File(imagePath).existsSync();
  }

  /// 保存图片到缓存
  /// 参考项目：BookHelp.writeImage
  static Future<void> writeImage(Book book, String src, List<int> bytes) async {
    final imagePath = await getImagePath(book, src);
    final file = File(imagePath);

    // 确保目录存在
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  /// 从内容中提取图片URL列表
  /// 参考项目：BookHelp.flowImages
  static List<String> extractImageUrls(String baseUrl, String content) {
    final urls = <String>[];
    final matches = imgPattern.allMatches(content);

    for (final match in matches) {
      final src = match.group(1);
      if (src != null && src.isNotEmpty) {
        // 转换为绝对URL
        final absoluteUrl = NetworkUtils.getAbsoluteURL(baseUrl, src);
        urls.add(absoluteUrl);
      }
    }

    return urls;
  }

  // ========== 缓存清理 ==========

  /// 清除所有缓存
  /// 参考项目：BookHelp.clearCache
  static Future<void> clearCache() async {
    await _ensureInitialized();
    final cachePath = await getCachePath();
    final cacheDir = Directory(cachePath);

    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  /// 清除指定书籍的缓存
  /// 参考项目：BookHelp.clearCache(book)
  static Future<void> clearBookCache(Book book) async {
    await _ensureInitialized();
    final cachePath = await getCachePath();
    final bookFolder = getBookFolderName(book);
    final bookDir = Directory('$cachePath/$bookFolder');

    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }

  /// 获取书籍已缓存的章节文件列表
  /// 参考项目：BookHelp.getChapterFiles
  static Future<Set<String>> getChapterFiles(Book book) async {
    final fileNames = <String>{};
    if (book.isLocal) return fileNames;

    await _ensureInitialized();
    final cachePath = await getCachePath();
    final bookFolder = getBookFolderName(book);
    final bookDir = Directory('$cachePath/$bookFolder');

    if (await bookDir.exists()) {
      await for (final entity in bookDir.list()) {
        if (entity is File) {
          fileNames.add(entity.path.split('/').last);
        }
      }
    }

    return fileNames;
  }

  /// 获取书籍缓存大小（字节）
  static Future<int> getBookCacheSize(Book book) async {
    await _ensureInitialized();
    final cachePath = await getCachePath();
    final bookFolder = getBookFolderName(book);
    final bookDirPath = '$cachePath/$bookFolder';

    return await FileUtils.getDirectorySize(bookDirPath);
  }

  /// 获取总缓存大小（字节）
  static Future<int> getTotalCacheSize() async {
    final cachePath = await getCachePath();
    return await FileUtils.getDirectorySize(cachePath);
  }
}
