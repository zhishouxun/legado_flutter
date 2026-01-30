import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import '../../core/base/base_service.dart';
import '../../core/exceptions/app_exceptions.dart'
    show
        EmptyFileException,
        ContentEmptyException,
        TocEmptyException,
        FileException,
        InvalidBooksDirException,
        NoBooksDirException;
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import 'book_service.dart';
import 'epub_parser.dart';
import 'mobi/mobi_reader.dart';
import 'umd/umd_reader.dart';
import 'pdf/pdf_reader.dart';
import '../txt_toc_rule_service.dart';
import '../../utils/app_log.dart';
import '../../utils/file_utils.dart';

/// 本地书籍服务
class LocalBookService extends BaseService {
  static final LocalBookService instance = LocalBookService._init();
  LocalBookService._init();

  final BookService _bookService = BookService.instance;

  /// 选择并导入本地文件
  Future<List<Book>> importLocalFiles({List<String>? allowedExtensions}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions:
            allowedExtensions ?? ['txt', 'epub', 'mobi', 'azw', 'azw3', 'umd'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final books = <Book>[];
      for (final file in result.files) {
        if (file.path == null) continue;

        try {
          final book = await _importFile(file.path!);
          if (book != null) {
            books.add(book);
          }
        } catch (e) {}
      }

      return books;
    } catch (e) {
      rethrow;
    }
  }

  /// 获取书籍存储目录
  Future<Directory> _getBooksDirectory() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      if (!await appDocDir.exists()) {
        throw NoBooksDirException('应用文档目录不存在');
      }

      final booksDir = Directory(path.join(appDocDir.path, 'books'));
      if (!await booksDir.exists()) {
        try {
          await booksDir.create(recursive: true);
        } catch (e) {
          throw InvalidBooksDirException('无法创建书籍目录: ${booksDir.path}, 错误: $e');
        }
      }

      // 验证目录是否可访问
      try {
        final testFile = File(path.join(booksDir.path, '.test'));
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        throw InvalidBooksDirException('书籍目录不可访问: ${booksDir.path}, 错误: $e');
      }

      return booksDir;
    } catch (e) {
      if (e is NoBooksDirException || e is InvalidBooksDirException) {
        rethrow;
      }
      throw InvalidBooksDirException('获取书籍目录失败: $e');
    }
  }

  /// 复制文件到应用目录
  Future<String> _copyFileToAppDir(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在: $sourcePath');
    }

    final fileName = path.basename(sourcePath);
    Directory booksDir;
    try {
      booksDir = await _getBooksDirectory();
    } on NoBooksDirException catch (e) {
      throw NoBooksDirException('无法获取书籍目录，无法复制文件: ${e.message}');
    } on InvalidBooksDirException catch (e) {
      throw InvalidBooksDirException('书籍目录无效，无法复制文件: ${e.message}');
    }
    final targetPath = path.join(booksDir.path, fileName);
    final targetFile = File(targetPath);

    // 如果目标文件已存在，检查是否需要更新
    if (await targetFile.exists()) {
      final sourceModified = await sourceFile.lastModified();
      final targetModified = await targetFile.lastModified();

      // 如果源文件更新，则覆盖
      if (sourceModified.isAfter(targetModified)) {
        await sourceFile.copy(targetPath);
      }
    } else {
      // 复制文件
      await sourceFile.copy(targetPath);
    }

    return targetPath;
  }

  /// 导入单个文件（公共方法）
  Future<Book?> importBook(String filePath) async {
    return await _importFile(filePath);
  }

  /// 导入单个文件
  Future<Book?> _importFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileException('文件不存在: $filePath');
    }

    // 检查文件大小
    try {
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw EmptyFileException('文件为空: $filePath');
      }
    } catch (e) {
      if (e is EmptyFileException) {
        rethrow;
      }
      // 如果无法获取文件大小，继续处理
    }

    final fileName = path.basename(filePath);
    final extension = path.extension(filePath).toLowerCase();

    // 解析文件名获取书名和作者
    final nameAuthor = _parseNameAuthor(fileName);

    // 复制文件到应用目录（确保应用重启后仍可访问）
    String savedFilePath;
    try {
      savedFilePath = await _copyFileToAppDir(filePath);
    } catch (e) {
      // 如果复制失败，使用原路径（可能在某些情况下仍可访问）
      savedFilePath = filePath;
    }

    // 创建书籍对象
    final book = Book(
      bookUrl: savedFilePath,
      name: nameAuthor['name'] ?? fileName,
      author: nameAuthor['author'] ?? '',
      origin: BookType.localTag,
      originName: fileName,
      type: BookType.text, // 默认类型，会根据文件类型更新
      latestChapterTime:
          await file.lastModified().then((v) => v.millisecondsSinceEpoch),
    );

    // 根据文件类型解析章节
    List<BookChapter> chapters;
    if (extension == '.txt') {
      chapters = await _parseTxtFile(file, book);
      // TXT 文件保持 BookType.text (0)
    } else if (extension == '.epub') {
      chapters = await _parseEpubFile(file, book);
      // EPUB 文件使用 BookType.file (3) 表示文件类型
      book.type = BookType.file;
    } else if (extension == '.mobi' ||
        extension == '.azw' ||
        extension == '.azw3') {
      chapters = await _parseMobiFile(file, book);
      // MOBI 文件使用 BookType.file (3) 表示文件类型
      book.type = BookType.file;
    } else if (extension == '.umd') {
      chapters = await _parseUmdFile(file, book);
      // UMD 文件使用 BookType.file (3) 表示文件类型
      book.type = BookType.file;
    } else if (extension == '.pdf') {
      chapters = await _parsePdfFile(file, book);
      // PDF 文件使用 BookType.image (1) 表示图片类型（纯图片形式）
      book.type = BookType.image;
    } else {
      throw Exception('不支持的文件类型: $extension');
    }

    if (chapters.isEmpty) {
      throw TocEmptyException('无法解析文件章节: $fileName');
    }

    // 更新书籍信息
    book.totalChapterNum = chapters.length;
    book.latestChapterTitle = chapters.last.title;

    // 保存书籍和章节
    await _bookService.createBook(book);
    for (final chapter in chapters) {
      await _bookService.createChapter(chapter);
    }

    return book;
  }

  /// 解析TXT文件章节
  Future<List<BookChapter>> _parseTxtFile(File file, Book book) async {
    final content = await file.readAsString();

    if (content.isEmpty) {
      throw EmptyFileException('文件为空: ${file.path}');
    }

    // 获取启用的TXT目录规则
    final enabledRules = await TxtTocRuleService.instance.getEnabledRules();

    // 如果没有启用的规则，使用默认规则
    List<RegExp> chapterPatterns = [];
    if (enabledRules.isNotEmpty) {
      // 使用启用的规则
      for (final rule in enabledRules) {
        try {
          chapterPatterns.add(RegExp(rule.rule, multiLine: true));
        } catch (e) {}
      }
    }

    // 如果没有规则或规则都无效，使用默认规则
    if (chapterPatterns.isEmpty) {
      chapterPatterns = [
        RegExp(r'第[0-9一二三四五六七八九十百千万]+[章节回]'),
        RegExp(r'Chapter\s+\d+', caseSensitive: false),
        RegExp(r'第\s*\d+\s*章'),
        RegExp(r'^\s*第\s*[0-9一二三四五六七八九十百千万]+\s*[章节回]\s*[^\n]*',
            multiLine: true),
      ];
    }

    RegExp? matchedPattern;
    for (final pattern in chapterPatterns) {
      final matches = pattern.allMatches(content);
      if (matches.length >= 3) {
        // 至少找到3个章节才认为匹配成功
        matchedPattern = pattern;
        break;
      }
    }

    final chapters = <BookChapter>[];

    if (matchedPattern != null) {
      // 使用正则表达式分割章节
      final matches = matchedPattern.allMatches(content);
      List<RegExpMatch> matchList = matches.toList();

      if (matchList.isEmpty) {
        return _parseTxtFileByLength(file, book, content);
      }

      int index = 0;

      // 处理第一个章节（从文件开头到第一个匹配位置）
      final firstMatch = matchList[0];
      if (firstMatch.start > 0) {
        // 文件开头有内容，作为第一章
        // 跳过开头的空白字符，找到正文开始位置
        int start = 0;
        while (start < firstMatch.start &&
            (content[start] == '\n' ||
                content[start] == '\r' ||
                content[start] == ' ' ||
                content[start] == '\t')) {
          start++;
        }

        if (start < firstMatch.start) {
          chapters.add(BookChapter(
            url: '${book.bookUrl}#$index',
            bookUrl: book.bookUrl,
            title: '第${index + 1}章',
            index: index++,
            start: start,
            end: firstMatch.start,
          ));
        }
      }

      // 处理中间的章节（从每个匹配位置到下一个匹配位置）
      // 检测连续的章节标题（目录），将它们之间的所有内容合并为一章
      int i = 0;
      while (i < matchList.length) {
        final match = matchList[i];
        // 提取完整的章节标题：从匹配位置开始到该行结束，保留原始格式
        String firstTitle = match.group(0)?.trim() ?? '第${index + 1}章';
        // 提取到行尾的完整标题（包括方括号等格式）
        if (match.end < content.length) {
          final lineEnd = content.indexOf('\n', match.end);
          if (lineEnd > match.end) {
            // 提取从匹配开始到行尾的完整内容
            final fullTitle = content.substring(match.start, lineEnd).trim();
            if (fullTitle.isNotEmpty) {
              firstTitle = fullTitle; // 完整保留原始标题，不做任何截取
            }
          } else {
            // 如果没有换行符，尝试提取到下一个匹配位置（但只取第一行）
            final nextStart = i + 1 < matchList.length
                ? matchList[i + 1].start
                : content.length;
            final fullContent = content.substring(match.start, nextStart);
            // 只取第一行作为标题
            final firstLineEnd = fullContent.indexOf('\n');
            if (firstLineEnd > 0) {
              firstTitle = fullContent.substring(0, firstLineEnd).trim();
            } else {
              // 如果没有换行，且内容不太长，可能是完整标题
              final trimmed = fullContent.trim();
              if (trimmed.length < 200) {
                firstTitle = trimmed;
              }
            }
          }
        }

        // 检查是否有连续的章节标题（目录）
        int lastMatchIndex = i;
        int nextMatchIndex = i + 1;

        // 查找连续的章节标题（目录列表）
        // 如果两个章节标题之间距离较近（少于1000个字符），认为是连续的目录
        while (nextMatchIndex < matchList.length) {
          final currentMatch = matchList[lastMatchIndex];
          final nextMatch = matchList[nextMatchIndex];

          // 计算两个章节标题之间的距离
          final distance = nextMatch.start - currentMatch.end;

          // 如果距离小于1000个字符，认为是连续的目录
          // 这样可以包含目录页中的其他信息（如"七月新番"、"简介"、"秦吏"等）
          if (distance < 1000) {
            lastMatchIndex = nextMatchIndex;
            nextMatchIndex++;
          } else {
            // 距离太远，不是连续的目录，停止合并
            break;
          }
        }

        // 确定章节的起始和结束位置
        final chapterStartMatch = matchList[i];
        final chapterEndMatch = matchList[lastMatchIndex];

        // 如果连续章节标题有多个（2个或以上），将整个目录区域作为一章
        if (lastMatchIndex > i) {
          // 从第一个章节标题开始，到最后一个章节标题结束
          // 包含它们之间的所有内容（目录页内容）
          int start = chapterStartMatch.start;

          // 跳过最后一个章节标题后的空白字符，找到正文开始位置
          int contentStart = chapterEndMatch.end;
          while (contentStart < content.length &&
              (content[contentStart] == '\n' ||
                  content[contentStart] == '\r' ||
                  content[contentStart] == ' ' ||
                  content[contentStart] == '\t')) {
            contentStart++;
          }

          // 确定章节结束位置（到下一个非连续章节标题开始位置）
          final chapterEnd = lastMatchIndex + 1 < matchList.length
              ? matchList[lastMatchIndex + 1].start
              : content.length;

          // 创建目录章节：包含从第一个章节标题到最后一个章节标题的所有内容
          chapters.add(BookChapter(
            url: '${book.bookUrl}#$index',
            bookUrl: book.bookUrl,
            title: '目录',
            index: index++,
            start: start,
            end: contentStart < chapterEnd ? contentStart : chapterEnd,
          ));

          // 如果目录后还有正文内容，继续处理后续章节
          if (contentStart < chapterEnd &&
              lastMatchIndex + 1 < matchList.length) {
            // 继续处理下一个非连续的章节
            i = lastMatchIndex + 1;
            continue;
          }
        } else {
          // 单个章节标题，正常处理
          // 提取完整的章节标题（到行尾）
          String chapterTitle = firstTitle;
          // 从匹配位置开始，提取到行尾的完整标题
          if (chapterStartMatch.end < content.length) {
            final lineEnd = content.indexOf('\n', chapterStartMatch.end);
            if (lineEnd > chapterStartMatch.end) {
              final fullTitle =
                  content.substring(chapterStartMatch.start, lineEnd).trim();
              if (fullTitle.isNotEmpty) {
                chapterTitle = fullTitle; // 完整保留原始标题
              }
            }
          }

          // 从章节标题行结束位置开始，跳过空白字符，找到正文开始位置
          int start = chapterStartMatch.end;
          // 如果找到了行尾，从行尾开始
          final lineEnd = content.indexOf('\n', chapterStartMatch.end);
          if (lineEnd > chapterStartMatch.end) {
            start = lineEnd;
          }
          // 跳过换行符和空白字符
          while (start < content.length &&
              (content[start] == '\n' ||
                  content[start] == '\r' ||
                  content[start] == ' ' ||
                  content[start] == '\t')) {
            start++;
          }

          final end = i + 1 < matchList.length
              ? matchList[i + 1].start
              : content.length;

          if (end > start) {
            chapters.add(BookChapter(
              url: '${book.bookUrl}#$index',
              bookUrl: book.bookUrl,
              title: chapterTitle,
              index: index++,
              start: start,
              end: end,
            ));
          }
        }

        // 移动到下一个章节
        i = nextMatchIndex;
      }

      // 如果没有生成任何章节，使用固定长度分割
      if (chapters.isEmpty) {
        return _parseTxtFileByLength(file, book, content);
      }
    } else {
      // 没有找到章节标题，按固定长度分割
      return _parseTxtFileByLength(file, book, content);
    }

    return chapters;
  }

  /// 按固定长度分割文件为章节
  Future<List<BookChapter>> _parseTxtFileByLength(
      File file, Book book, String content) async {
    final chapters = <BookChapter>[];
    const maxChapterLength = 10000; // 每章最大长度
    int index = 0;
    int start = 0;

    while (start < content.length) {
      int end = (start + maxChapterLength).clamp(0, content.length);

      // 尝试在换行符处分割
      if (end < content.length) {
        final lastNewline = content.lastIndexOf('\n', end);
        if (lastNewline > start) {
          end = lastNewline;
        }
      }

      chapters.add(BookChapter(
        url: '${book.bookUrl}#$index',
        bookUrl: book.bookUrl,
        title: '第${index + 1}章',
        index: index++,
        start: start,
        end: end,
      ));

      start = end;
    }

    return chapters;
  }

  /// 从文件名解析书名和作者
  Map<String, String> _parseNameAuthor(String fileName) {
    final nameWithoutExt = path.basenameWithoutExtension(fileName);

    // 常见的文件名格式：
    // - 《书名》作者
    // - 书名 作者：xxx
    // - 书名 by 作者
    // - 书名-作者

    final patterns = [
      RegExp(r'《([^《》]+)》(.*)'),
      RegExp(r'(.+?)\s*作者[：:]\s*(.+)'),
      RegExp(r'(.+?)\s+by\s+(.+)', caseSensitive: false),
      RegExp(r'(.+?)[-－]\s*(.+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(nameWithoutExt);
      if (match != null && match.groupCount >= 2) {
        return {
          'name': match.group(1)?.trim() ?? nameWithoutExt,
          'author': match.group(2)?.trim() ?? '',
        };
      }
    }

    // 如果没有匹配到，返回文件名作为书名
    return {
      'name': nameWithoutExt,
      'author': '',
    };
  }

  /// 解析EPUB文件章节
  Future<List<BookChapter>> _parseEpubFile(File file, Book book) async {
    try {
      // 读取EPUB文件（EPUB 本质上是 ZIP 文件）
      final epubBytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(epubBytes);

      // 使用 EPUB 解析器解析
      final epubData = EpubParser.parseEpub(archive);

      // 提取书籍信息
      if (epubData['title'] != null &&
          (epubData['title'] as String).isNotEmpty) {
        book.name = epubData['title'] as String;
      }
      if (epubData['author'] != null &&
          (epubData['author'] as String).isNotEmpty) {
        book.author = epubData['author'] as String;
      }
      if (epubData['description'] != null &&
          (epubData['description'] as String).isNotEmpty) {
        book.intro = epubData['description'] as String;
      }

      // 提取封面
      final coverImage = epubData['coverImage'] as List<int>?;
      if (coverImage != null && coverImage.isNotEmpty) {
        try {
          // 保存封面到应用目录
          Directory? booksDir;
          try {
            booksDir = await _getBooksDirectory();
          } on NoBooksDirException catch (e) {
            AppLog.instance.put('无法获取书籍目录，跳过封面保存: ${e.message}');
            // 封面保存失败不影响章节解析，继续执行
          } on InvalidBooksDirException catch (e) {
            AppLog.instance.put('书籍目录无效，跳过封面保存: ${e.message}');
            // 封面保存失败不影响章节解析，继续执行
          }

          if (booksDir != null) {
            final coverFileName =
                '${path.basenameWithoutExtension(book.bookUrl)}_cover.jpg';
            final coverPath = path.join(booksDir.path, coverFileName);
            final coverFile = File(coverPath);
            await coverFile.writeAsBytes(coverImage);
            book.customCoverUrl = coverPath;
          }
        } catch (e) {
          AppLog.instance.put('提取EPUB封面失败', error: e);
        }
      }

      // 提取章节列表
      final chapters = <BookChapter>[];
      final chapterList = epubData['chapters'] as List<Map<String, String>>;
      final opfPath = epubData['opfPath'] as String;

      // 存储 OPF 路径和章节信息到书籍变量中，用于后续读取章节内容
      // 这里我们使用 variable 字段存储章节的 href 信息
      final chapterHrefs = <String>[];

      for (int i = 0; i < chapterList.length; i++) {
        final chapterInfo = chapterList[i];
        final chapterHref = chapterInfo['href'] ?? '';
        chapterHrefs.add(chapterHref);

        // 尝试从章节 HTML 中提取标题
        String title = '第${i + 1}章';
        try {
          final chapterContent =
              EpubParser.getChapterContent(archive, opfPath, chapterHref);
          if (chapterContent != null) {
            // 简单提取标题（从 <title> 标签或第一个 <h1> 标签）
            final titleMatch =
                RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false)
                    .firstMatch(chapterContent);
            if (titleMatch != null) {
              title = titleMatch.group(1)?.trim() ?? title;
            } else {
              final h1Match =
                  RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false)
                      .firstMatch(chapterContent);
              if (h1Match != null) {
                title = h1Match.group(1)?.trim() ?? title;
              }
            }
          }
        } catch (e) {
          // 忽略标题提取错误
        }

        // 创建章节对象
        final chapter = BookChapter(
          url: '${book.bookUrl}#$i',
          bookUrl: book.bookUrl,
          title: title,
          index: i,
          baseUrl: book.bookUrl,
          variable: chapterHref, // 存储章节的 href 路径
        );

        chapters.add(chapter);
      }

      // 如果还是没有章节，创建一个默认章节
      if (chapters.isEmpty) {
        chapters.add(BookChapter(
          url: '${book.bookUrl}#0',
          bookUrl: book.bookUrl,
          title: '正文',
          index: 0,
          baseUrl: book.bookUrl,
        ));
      }

      return chapters;
    } catch (e) {
      AppLog.instance.put('解析EPUB文件失败', error: e);
      throw Exception('EPUB文件解析失败: $e');
    }
  }

  /// 获取章节内容
  Future<String?> getChapterContent(BookChapter chapter, Book book) async {
    if (book.origin != BookType.localTag) {
      return null;
    }

    // EPUB 文件需要特殊处理（使用 BookType.file 表示 EPUB）
    if (book.type == BookType.file &&
        book.bookUrl.toLowerCase().endsWith('.epub')) {
      return await _getEpubChapterContent(chapter, book);
    }

    // MOBI 文件需要特殊处理
    final bookUrlLower = book.bookUrl.toLowerCase();
    if (book.type == BookType.file &&
        (bookUrlLower.endsWith('.mobi') ||
            bookUrlLower.endsWith('.azw') ||
            bookUrlLower.endsWith('.azw3'))) {
      return await _getMobiChapterContent(chapter, book);
    }

    // UMD 文件需要特殊处理
    if (book.type == BookType.file && bookUrlLower.endsWith('.umd')) {
      return await _getUmdChapterContent(chapter, book);
    }

    // PDF 文件需要特殊处理（纯图片形式）
    if (book.type == BookType.image && bookUrlLower.endsWith('.pdf')) {
      return await _getPdfChapterContent(chapter, book);
    }

    File? file;
    String? filePath = book.bookUrl;

    try {
      // 首先尝试使用原始路径
      file = File(filePath);

      // 检查文件是否存在且可访问
      bool canAccess = false;
      try {
        if (await file.exists()) {
          // 尝试打开文件以检查权限
          final randomAccessFile = await file.open();
          await randomAccessFile.close();
          canAccess = true;
        }
      } catch (e) {
        // 文件存在但无法访问（权限问题）
        canAccess = false;
      }

      // 如果文件不存在或无法访问，尝试从应用目录查找
      if (!canAccess) {
        try {
          Directory booksDir;
          try {
            booksDir = await _getBooksDirectory();
          } on NoBooksDirException catch (e) {
            AppLog.instance.put('无法获取书籍目录: ${e.message}');
            return null;
          } on InvalidBooksDirException catch (e) {
            AppLog.instance.put('书籍目录无效: ${e.message}');
            return null;
          }
          final fileName = path.basename(book.bookUrl);
          final appFilePath = path.join(booksDir.path, fileName);
          final appFile = File(appFilePath);

          if (await appFile.exists()) {
            file = appFile;
            filePath = appFilePath;
            // 更新书籍的 bookUrl 为应用目录路径
            final updatedBook = book.copyWith(bookUrl: appFilePath);
            await _bookService.saveBook(updatedBook);
          } else {
            // 如果应用目录也没有文件，尝试复制原文件（如果原文件路径可访问）
            try {
              final originalFile = File(book.bookUrl);
              if (await originalFile.exists()) {
                final newPath = await _copyFileToAppDir(book.bookUrl);
                file = File(newPath);
                filePath = newPath;
                final updatedBook = book.copyWith(bookUrl: newPath);
                await _bookService.saveBook(updatedBook);
              } else {
                return null;
              }
            } catch (copyError) {
              return null;
            }
          }
        } catch (e) {
          return null;
        }
      }

      // 此时 file 应该已经确定
      final content = await file.readAsString();

      if (chapter.start != null && chapter.end != null) {
        final start = chapter.start!;
        final end = chapter.end!.clamp(0, content.length);

        if (start < end && start < content.length) {
          // start 已经指向正文开始位置（不包含章节标题），直接提取正文内容
          var chapterContent = content.substring(start, end);

          // 如果内容为空或只有空白，抛出异常
          if (chapterContent.trim().isEmpty) {
            throw ContentEmptyException('本章节内容为空: ${chapter.title}');
          }

          // 清理首尾空白
          chapterContent = chapterContent.trim();

          // 不截取原文本，保持原样显示
          // 只做基本的格式处理：保留段落分隔
          chapterContent =
              chapterContent.replaceAll(RegExp(r'\n\s*\n+'), '\n\n');

          return chapterContent;
        } else {}
      }

      // 如果没有 start 和 end，返回整个文件内容（用于某些特殊情况）
      if (chapter.start == null || chapter.end == null) {
        return content;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取EPUB章节内容
  Future<String?> _getEpubChapterContent(BookChapter chapter, Book book) async {
    try {
      final file = File(book.bookUrl);
      if (!await file.exists()) {
        return null;
      }

      // 读取EPUB文件
      final epubBytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(epubBytes);

      // 从章节的 variable 字段获取章节 href
      final chapterHref = chapter.variable;
      if (chapterHref == null || chapterHref.isEmpty) {
        return null;
      }

      // 需要找到 OPF 文件路径
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile == null) {
        return null;
      }

      final containerXml = utf8.decode(containerFile.content as List<int>);
      final containerDoc = xml.XmlDocument.parse(containerXml);
      final rootfile = containerDoc.findAllElements('rootfile').first;
      final opfPath = rootfile.getAttribute('full-path') ?? 'OEBPS/content.opf';

      // 读取章节内容
      final htmlContent =
          EpubParser.getChapterContent(archive, opfPath, chapterHref);

      if (htmlContent != null && htmlContent.isNotEmpty) {
        // 返回HTML内容，由阅读器页面处理显示
        return htmlContent;
      }

      return null;
    } catch (e) {
      AppLog.instance.put('获取EPUB章节内容失败', error: e);
      return null;
    }
  }

  /// 解析UMD文件章节
  Future<List<BookChapter>> _parseUmdFile(File file, Book book) async {
    try {
      // 读取UMD文件
      final umdBook = await UmdReader.readUmd(file);

      try {
        // 提取书籍信息
        final metadata = umdBook.metadata;
        if (metadata.title.isNotEmpty && metadata.title != '未知标题') {
          book.name = metadata.title;
        }
        if (metadata.author.isNotEmpty && metadata.author != '未知作者') {
          book.author = metadata.author;
        }
        if (metadata.description != null && metadata.description!.isNotEmpty) {
          book.intro = metadata.description!;
        }

        // 提取封面
        final coverImage = await umdBook.getCover();
        if (coverImage != null && coverImage.isNotEmpty) {
          // 保存封面到应用目录
          try {
            final appDocPath = await FileUtils.getDocumentsPath();
            final coverDir = FileUtils.getPath(appDocPath, ['covers']);
            await Directory(coverDir).create(recursive: true);

            final coverFileName = '${book.name}_${book.author}.jpg'
                .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
            final coverFile =
                File(FileUtils.getPath(coverDir, [coverFileName]));
            await coverFile.writeAsBytes(coverImage);
            book.coverUrl = coverFile.path;
          } catch (e) {
            AppLog.instance.put('保存UMD封面失败', error: e);
          }
        }

        // 获取章节列表
        final umdChapters = await umdBook.getChapters();
        final chapters = <BookChapter>[];

        for (int i = 0; i < umdChapters.length; i++) {
          final umdChapter = umdChapters[i];
          final bookChapter = BookChapter(
            bookUrl: book.bookUrl,
            index: i,
            title: umdChapter.title,
            url: i.toString(), // UMD章节使用索引作为URL
          );
          chapters.add(bookChapter);
        }

        return chapters;
      } finally {
        await umdBook.close();
      }
    } catch (e) {
      AppLog.instance.put('解析UMD文件失败: ${file.path}', error: e);
      rethrow;
    }
  }

  /// 解析PDF文件章节
  /// PDF 以图片形式渲染，每 pdfPageSize 页为一章
  Future<List<BookChapter>> _parsePdfFile(File file, Book book) async {
    try {
      final pdfReader = PdfReader(file.path);

      // 初始化 PDF
      final initialized = await pdfReader.initialize();
      if (!initialized) {
        throw Exception(pdfReader.errorMessage ?? 'PDF 初始化失败');
      }

      // 更新书籍信息
      pdfReader.updateBookInfo(book);

      // 获取章节列表
      final chapters = pdfReader.getChapterList(book);

      // 尝试获取封面
      try {
        final coverImage = await pdfReader.getCoverImage();
        if (coverImage != null && coverImage.isNotEmpty) {
          final appDocPath = await FileUtils.getDocumentsPath();
          final coverDir = FileUtils.getPath(appDocPath, ['covers']);
          await Directory(coverDir).create(recursive: true);

          final coverFileName = '${book.name}_${book.author}.jpg'
              .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          final coverFile = File(FileUtils.getPath(coverDir, [coverFileName]));
          await coverFile.writeAsBytes(coverImage);
          book.coverUrl = coverFile.path;
        }
      } catch (e) {
        AppLog.instance.put('保存PDF封面失败', error: e);
      }

      // 关闭 PDF reader
      pdfReader.close();

      return chapters;
    } catch (e) {
      AppLog.instance.put('解析PDF文件失败: ${file.path}', error: e);
      rethrow;
    }
  }

  /// 解析MOBI文件章节
  Future<List<BookChapter>> _parseMobiFile(File file, Book book) async {
    try {
      // 读取MOBI文件
      final mobiBook = await MobiReader.readMobi(file);

      try {
        // 提取书籍信息
        final metadata = mobiBook.metadata;
        if (metadata.title.isNotEmpty) {
          book.name = metadata.title;
        }
        if (metadata.creators.isNotEmpty) {
          book.author = metadata.creators.join(', ');
        }
        if (metadata.description.isNotEmpty) {
          book.intro = metadata.description;
        }

        // 提取封面
        final coverImage = await mobiBook.getCover();
        if (coverImage != null && coverImage.isNotEmpty) {
          // 保存封面到应用目录
          try {
            final appDocPath = await FileUtils.getDocumentsPath();
            final coverDir = FileUtils.getPath(appDocPath, ['covers']);
            await Directory(coverDir).create(recursive: true);

            final coverFileName = '${book.name}_${book.author}.jpg'
                .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
            final coverFile =
                File(FileUtils.getPath(coverDir, [coverFileName]));
            await coverFile.writeAsBytes(coverImage);
            book.coverUrl = coverFile.path;
          } catch (e) {
            AppLog.instance.put('保存MOBI封面失败', error: e);
          }
        }

        // 获取章节列表
        final mobiChapters = await mobiBook.getChapters();
        final chapters = <BookChapter>[];

        for (int i = 0; i < mobiChapters.length; i++) {
          final mobiChapter = mobiChapters[i];
          final chapter = BookChapter(
            bookUrl: book.bookUrl,
            index: i,
            title: mobiChapter.title,
            url: mobiChapter.href ?? 'chapter_$i',
            variable: mobiChapter.href,
          );
          chapters.add(chapter);
        }

        return chapters;
      } finally {
        await mobiBook.close();
      }
    } catch (e) {
      AppLog.instance.put('解析MOBI文件失败', error: e);
      rethrow;
    }
  }

  /// 获取MOBI章节内容
  Future<String?> _getMobiChapterContent(BookChapter chapter, Book book) async {
    try {
      final file = File(book.bookUrl);
      if (!await file.exists()) {
        return null;
      }

      // 读取MOBI文件
      final mobiBook = await MobiReader.readMobi(file);

      try {
        // 尝试从章节的variable字段获取href
        final href = chapter.variable;
        if (href != null && href.isNotEmpty) {
          final content = await mobiBook.getChapterContentByHref(href);
          if (content != null && content.isNotEmpty) {
            return content;
          }
        }

        // 如果href无效，尝试从章节的start和end获取
        if (chapter.start != null && chapter.end != null) {
          final start = chapter.start!;
          final length = chapter.end! - start;
          if (length > 0) {
            final content = await mobiBook.getTextByRange(start, length);
            if (content.isNotEmpty) {
              return content;
            }
          }
        }

        // 如果都无效，尝试获取所有章节并找到对应的章节
        final chapters = await mobiBook.getChapters();
        if (chapter.index >= 0 && chapter.index < chapters.length) {
          final mobiChapter = chapters[chapter.index];
          final content = await mobiBook.getChapterContent(mobiChapter);
          if (content != null && content.isNotEmpty) {
            return content;
          }
        }

        // 最后尝试：返回所有文本（作为fallback）
        final text = await mobiBook.getAllText();
        if (text.isNotEmpty) {
          // 如果章节有start和end，尝试截取
          if (chapter.start != null && chapter.end != null) {
            final start = chapter.start!.clamp(0, text.length);
            final end = chapter.end!.clamp(0, text.length);
            if (end > start) {
              return text.substring(start, end);
            }
          }
          return text;
        }

        return null;
      } finally {
        await mobiBook.close();
      }
    } catch (e) {
      AppLog.instance.put('获取MOBI章节内容失败', error: e);
      return null;
    }
  }

  /// 获取UMD章节内容
  Future<String?> _getUmdChapterContent(BookChapter chapter, Book book) async {
    try {
      final file = File(book.bookUrl);
      if (!await file.exists()) {
        return null;
      }

      // 读取UMD文件
      final umdBook = await UmdReader.readUmd(file);

      try {
        // 根据章节索引获取内容
        final chapterIndex = chapter.index;
        final content = await umdBook.getChapterContentByIndex(chapterIndex);

        return content;
      } finally {
        await umdBook.close();
      }
    } catch (e) {
      AppLog.instance.put('获取UMD章节内容失败: ${chapter.title}', error: e);
      return null;
    }
  }

  /// 获取PDF章节内容
  /// 返回 HTML 格式的图片标签
  Future<String?> _getPdfChapterContent(BookChapter chapter, Book book) async {
    try {
      final file = File(book.bookUrl);
      if (!await file.exists()) {
        return null;
      }

      final pdfReader = PdfReader(file.path);

      // 初始化 PDF
      final initialized = await pdfReader.initialize();
      if (!initialized) {
        AppLog.instance.put('PDF 初始化失败: ${pdfReader.errorMessage}');
        return null;
      }

      try {
        // 获取章节内容（HTML 图片标签）
        final content = pdfReader.getContent(chapter);
        return content;
      } finally {
        pdfReader.close();
      }
    } catch (e) {
      AppLog.instance.put('获取PDF章节内容失败: ${chapter.title}', error: e);
      return null;
    }
  }
}
