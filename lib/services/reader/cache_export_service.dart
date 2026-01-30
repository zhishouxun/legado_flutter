import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import '../../core/base/base_service.dart';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import '../book/book_service.dart';
import '../source/book_source_service.dart';
import '../network/network_service.dart';
import 'cache_service.dart';
import '../../utils/app_log.dart';
import '../notification_service.dart';

/// 缓存导出服务
/// 参考项目：io.legado.app.service.ExportBookService
class CacheExportService extends BaseService {
  static final CacheExportService instance = CacheExportService._init();
  CacheExportService._init();

  static const int notificationId = 104; // 参考项目：NotificationId.ExportBook

  /// 导出书籍为TXT
  /// 参考项目：ExportBookService.exportTxt()
  Future<bool> exportAsTxt(
    Book book, {
    List<BookChapter>? chapters,
    Function(int current, int total)? onProgress,
    bool showNotification = false,
  }) async {
    try {
      // 获取章节列表
      final chapterList =
          chapters ?? await BookService.instance.getChapterList(book);
      if (chapterList.isEmpty) {
        throw Exception('书籍没有章节');
      }

      // 选择保存路径
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出书籍',
        fileName: '${book.name}_${book.author}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result == null) {
        return false; // 用户取消
      }

      // 显示通知（如果启用）
      if (showNotification) {
        await NotificationService.instance.showProgressNotification(
          id: notificationId,
          title: '导出书籍',
          content: '正在导出: ${book.name}',
          progress: 0.0,
          max: chapterList.length,
          current: 0,
          isOngoing: true,
          channelId: NotificationService.channelIdExport,
        );
      }

      final file = File(result);
      final buffer = StringBuffer();

      // 写入书籍信息
      buffer.writeln(book.name);
      if (book.author.isNotEmpty) {
        buffer.writeln('作者：${book.author}');
      }
      if (book.intro != null && book.intro!.isNotEmpty) {
        buffer.writeln('\n${book.intro}');
      }
      buffer.writeln('\n${'=' * 50}\n');

      // 写入章节内容
      for (int i = 0; i < chapterList.length; i++) {
        final chapter = chapterList[i];

        // 获取章节内容（优先从缓存读取）
        String? content =
            await CacheService.instance.getCachedChapterContent(book, chapter);

        // 如果缓存中没有，尝试从书源获取
        if (content == null || content.isEmpty) {
          try {
            final source = await BookSourceService.instance
                .getBookSourceByUrl(book.origin);
            if (source != null) {
              content = await BookService.instance.getChapterContent(
                chapter,
                source,
                bookName: book.name,
                bookOrigin: book.origin,
                book: book, // 传入 book 参数，启用缓存优化
              );
            }
          } catch (e) {
            AppLog.instance.put('获取章节内容失败: ${chapter.title}', error: e);
          }
        }

        // 写入章节标题和内容
        buffer.writeln('\n${chapter.title}\n');
        if (content != null && content.isNotEmpty) {
          buffer.writeln(content);
        } else {
          buffer.writeln('[内容获取失败]');
        }
        buffer.writeln('\n${'=' * 50}\n');

        // 更新进度
        onProgress?.call(i + 1, chapterList.length);

        // 更新通知
        if (showNotification) {
          final progress = (i + 1) / chapterList.length;
          await NotificationService.instance.showProgressNotification(
            id: notificationId,
            title: '导出书籍',
            content: '正在导出: ${book.name} (${i + 1}/${chapterList.length})',
            progress: progress,
            max: chapterList.length,
            current: i + 1,
            isOngoing: true,
          );
        }
      }

      // 写入文件
      await file.writeAsString(buffer.toString());

      // 完成通知
      if (showNotification) {
        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '导出完成',
          content: '${book.name} 导出成功',
          isOngoing: false,
        );
      }

      AppLog.instance.put('导出成功: ${file.path}');
      return true;
    } catch (e) {
      // 错误通知
      if (showNotification) {
        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '导出失败',
          content: '${book.name} 导出失败: ${e.toString()}',
          isOngoing: false,
        );
      }
      AppLog.instance.put('导出失败: ${book.name}', error: e);
      return false;
    }
  }

  /// 导出书籍为EPUB
  /// 参考项目：ExportBookService.exportEpub()
  Future<bool> exportAsEpub(
    Book book, {
    List<BookChapter>? chapters,
    Function(int current, int total)? onProgress,
    bool showNotification = false,
  }) async {
    try {
      // 获取章节列表
      final chapterList =
          chapters ?? await BookService.instance.getChapterList(book);
      if (chapterList.isEmpty) {
        throw Exception('书籍没有章节');
      }

      // 选择保存路径
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出书籍',
        fileName: '${book.name}_${book.author}.epub',
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );

      if (result == null) {
        return false; // 用户取消
      }

      // 显示通知（如果启用）
      if (showNotification) {
        await NotificationService.instance.showProgressNotification(
          id: notificationId,
          title: '导出书籍',
          content: '正在导出: ${book.name}',
          progress: 0.0,
          max: chapterList.length,
          current: 0,
          isOngoing: true,
          channelId: NotificationService.channelIdExport,
        );
      }

      // 创建 EPUB 文件
      final epubFile = File(result);
      final archive = Archive();

      // 1. 添加 mimetype（必须是第一个文件，不压缩）
      // 注意：EPUB 规范要求 mimetype 不压缩，但 archive 包可能不支持
      // 先添加 mimetype 作为第一个文件
      final mimetypeFile =
          ArchiveFile('mimetype', 20, utf8.encode('application/epub+zip'));
      // 尝试设置不压缩（如果 archive 包支持）
      archive.addFile(mimetypeFile);

      // 2. 读取模板文件
      final chapterTemplate =
          await rootBundle.loadString('assets/epub/chapter.html');
      final coverTemplate =
          await rootBundle.loadString('assets/epub/cover.html');
      final introTemplate =
          await rootBundle.loadString('assets/epub/intro.html');
      final mainCss = await rootBundle.loadString('assets/epub/main.css');
      final fontsCss = await rootBundle.loadString('assets/epub/fonts.css');
      final logoBytes = await rootBundle.load('assets/epub/logo.png');

      // 3. 生成封面页
      final coverHtml = coverTemplate
          .replaceAll('{name}', _escapeXml(book.name))
          .replaceAll('{author}', _escapeXml(book.author));
      archive.addFile(ArchiveFile(
        'OEBPS/Text/cover.html',
        coverHtml.length,
        utf8.encode(coverHtml),
      ));

      // 4. 生成简介页
      final intro = book.intro ?? '';
      final introHtml = introTemplate.replaceAll('{intro}', _escapeXml(intro));
      archive.addFile(ArchiveFile(
        'OEBPS/Text/intro.html',
        introHtml.length,
        utf8.encode(introHtml),
      ));

      // 5. 生成章节 HTML 文件
      final chapterFiles = <String>[];
      final chapterIds = <String>[];

      for (int i = 0; i < chapterList.length; i++) {
        final chapter = chapterList[i];

        // 获取章节内容
        String? content =
            await CacheService.instance.getCachedChapterContent(book, chapter);

        if (content == null || content.isEmpty) {
          try {
            final source = await BookSourceService.instance
                .getBookSourceByUrl(book.origin);
            if (source != null) {
              content = await BookService.instance.getChapterContent(
                chapter,
                source,
                bookName: book.name,
                bookOrigin: book.origin,
                book: book, // 传入 book 参数，启用缓存优化
              );
            }
          } catch (e) {
            AppLog.instance.put('获取章节内容失败: ${chapter.title}', error: e);
          }
        }

        // 处理内容：将换行转换为段落
        final processedContent = _processChapterContent(content ?? '[内容获取失败]');

        // 生成章节 HTML
        final chapterId = 'chapter_${i + 1}';
        final chapterFileName = 'OEBPS/Text/$chapterId.html';
        final chapterHtml = chapterTemplate
            .replaceAll('{title}', _escapeXml(chapter.title))
            .replaceAll('{content}', processedContent);

        archive.addFile(ArchiveFile(
          chapterFileName,
          chapterHtml.length,
          utf8.encode(chapterHtml),
        ));

        chapterFiles.add(chapterFileName);
        chapterIds.add(chapterId);

        // 更新进度
        onProgress?.call(i + 1, chapterList.length + 5); // +5 是为了包含其他文件的生成

        // 更新通知
        if (showNotification) {
          final progress = (i + 1) / chapterList.length;
          await NotificationService.instance.showProgressNotification(
            id: notificationId,
            title: '导出书籍',
            content: '正在导出: ${book.name} (${i + 1}/${chapterList.length})',
            progress: progress,
            max: chapterList.length,
            current: i + 1,
            isOngoing: true,
            channelId: NotificationService.channelIdExport,
          );
        }
      }

      // 6. 添加 CSS 文件
      archive.addFile(ArchiveFile(
        'OEBPS/Styles/main.css',
        mainCss.length,
        utf8.encode(mainCss),
      ));
      archive.addFile(ArchiveFile(
        'OEBPS/Styles/fonts.css',
        fontsCss.length,
        utf8.encode(fontsCss),
      ));

      // 7. 添加封面图片
      List<int> coverImageBytes = logoBytes.buffer.asUint8List();
      String coverImageExt = 'jpg';

      if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
        try {
          // 尝试下载封面图片
          final response = await NetworkService.instance.get(
            book.coverUrl!,
            retryCount: 1,
            options: Options(responseType: ResponseType.bytes),
          );

          // Dio Response 的 data 属性包含字节数据
          if (response.data != null && response.data is List<int>) {
            final imageBytes = response.data as List<int>;
            if (imageBytes.isNotEmpty) {
              coverImageBytes = imageBytes;
              // 根据 URL 判断图片类型
              final url = book.coverUrl!.toLowerCase();
              if (url.contains('.png')) {
                coverImageExt = 'png';
              } else if (url.contains('.gif')) {
                coverImageExt = 'gif';
              } else {
                coverImageExt = 'jpg';
              }
            }
          }
        } catch (e) {
          AppLog.instance.put('下载封面图片失败，使用默认图片', error: e);
        }
      }

      // 更新封面 HTML 中的图片路径
      final updatedCoverHtml = coverHtml.replaceAll(
        '../Images/cover.jpg',
        '../Images/cover.$coverImageExt',
      );

      // 重新添加更新后的封面 HTML
      final coverIndex =
          archive.files.indexWhere((f) => f.name == 'OEBPS/Text/cover.html');
      if (coverIndex >= 0) {
        archive.files[coverIndex] = ArchiveFile(
          'OEBPS/Text/cover.html',
          updatedCoverHtml.length,
          utf8.encode(updatedCoverHtml),
        );
      }

      // 添加封面图片到 EPUB
      archive.addFile(ArchiveFile(
        'OEBPS/Images/cover.$coverImageExt',
        coverImageBytes.length,
        coverImageBytes,
      ));

      // 8. 生成 content.opf 文件
      final opfContent = _generateOpf(book, chapterFiles, chapterIds);
      archive.addFile(ArchiveFile(
        'OEBPS/content.opf',
        opfContent.length,
        utf8.encode(opfContent),
      ));

      // 9. 生成 toc.ncx 文件
      final tocContent = _generateToc(book, chapterList, chapterIds);
      archive.addFile(ArchiveFile(
        'OEBPS/toc.ncx',
        tocContent.length,
        utf8.encode(tocContent),
      ));

      // 10. 生成 container.xml
      final containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile(
        'META-INF/container.xml',
        containerXml.length,
        utf8.encode(containerXml),
      ));

      // 11. 压缩并写入文件
      // 注意：EPUB 规范要求 mimetype 不压缩且是第一个文件
      // archive 包可能无法完全满足这个要求，但大多数阅读器仍能正常打开
      final zipEncoder = ZipEncoder();
      final zipData =
          zipEncoder.encode(archive, level: Deflate.BEST_COMPRESSION);

      if (zipData == null) {
        throw Exception('EPUB 压缩失败');
      }

      await epubFile.writeAsBytes(zipData);

      // 完成通知
      if (showNotification) {
        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '导出完成',
          content: '${book.name} 导出成功',
          isOngoing: false,
          channelId: NotificationService.channelIdExport,
        );
      }

      AppLog.instance.put('EPUB 导出成功: ${epubFile.path}');
      return true;
    } catch (e) {
      // 错误通知
      if (showNotification) {
        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '导出失败',
          content: '${book.name} 导出失败: ${e.toString()}',
          isOngoing: false,
          channelId: NotificationService.channelIdExport,
        );
      }
      AppLog.instance.put('EPUB 导出失败: ${book.name}', error: e);
      return false;
    }
  }

  /// 转义 XML 特殊字符
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// 处理章节内容，将换行转换为段落
  String _processChapterContent(String content) {
    if (content.isEmpty) return '<p>[内容为空]</p>';

    // 将多个连续换行分割为段落
    final paragraphs = content
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim())
        .toList();

    if (paragraphs.isEmpty) {
      return '<p>[内容为空]</p>';
    }

    // 将每个段落包装在 <p> 标签中
    return paragraphs.map((p) => '<p>${_escapeXml(p)}</p>').join('\n');
  }

  /// 生成 OPF 文件内容
  String _generateOpf(
      Book book, List<String> chapterFiles, List<String> chapterIds) {
    final now = DateTime.now().toUtc();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final manifestItems = StringBuffer();
    final spineItems = StringBuffer();

    // 简介
    manifestItems.writeln(
        '    <item id="intro" href="Text/intro.html" media-type="application/xhtml+xml"/>');
    spineItems.writeln('    <itemref idref="intro"/>');

    // 章节
    for (int i = 0; i < chapterFiles.length; i++) {
      final chapterId = chapterIds[i];
      final chapterFile = chapterFiles[i].replaceFirst('OEBPS/', '');
      manifestItems.writeln(
          '    <item id="$chapterId" href="$chapterFile" media-type="application/xhtml+xml"/>');
      spineItems.writeln('    <itemref idref="$chapterId"/>');
    }

    // CSS
    manifestItems.writeln(
        '    <item id="main-css" href="Styles/main.css" media-type="text/css"/>');
    manifestItems.writeln(
        '    <item id="fonts-css" href="Styles/fonts.css" media-type="text/css"/>');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="bookid">${book.bookUrl}</dc:identifier>
    <dc:title>${_escapeXml(book.name)}</dc:title>
    <dc:creator>${_escapeXml(book.author)}</dc:creator>
    <dc:language>zh-CN</dc:language>
    <dc:date>$dateStr</dc:date>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover" href="Text/cover.html" media-type="application/xhtml+xml"/>
    <item id="cover-image" href="Images/cover.jpg" media-type="image/jpeg"/>
$manifestItems
  </manifest>
  <spine toc="ncx">
$spineItems
  </spine>
  <guide>
    <reference type="cover" title="封面" href="Text/cover.html"/>
  </guide>
</package>''';
  }

  /// 生成 TOC 文件内容
  String _generateToc(
      Book book, List<BookChapter> chapters, List<String> chapterIds) {
    final navPoints = StringBuffer();

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final chapterId = chapterIds[i];
      final playOrder = i + 1;
      navPoints
          .writeln('    <navPoint id="$chapterId" playOrder="$playOrder">');
      navPoints.writeln(
          '      <navLabel><text>${_escapeXml(chapter.title)}</text></navLabel>');
      navPoints.writeln('      <content src="Text/$chapterId.html"/>');
      navPoints.writeln('    </navPoint>');
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="${book.bookUrl}"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle>
    <text>${_escapeXml(book.name)}</text>
  </docTitle>
  <navMap>
$navPoints
  </navMap>
</ncx>''';
  }

  /// 批量导出书籍
  Future<Map<String, bool>> exportBooks(
    List<Book> books,
    String exportType, {
    Function(int current, int total)? onProgress,
  }) async {
    final results = <String, bool>{};

    for (int i = 0; i < books.length; i++) {
      final book = books[i];
      bool success = false;

      if (exportType == 'txt') {
        success = await exportAsTxt(book, onProgress: (current, total) {
          // 计算总体进度
          final overallCurrent = (i * 100) + ((current * 100) ~/ total);
          final overallTotal = books.length * 100;
          onProgress?.call(overallCurrent, overallTotal);
        });
      } else if (exportType == 'epub') {
        success = await exportAsEpub(book, onProgress: (current, total) {
          // 计算总体进度
          final overallCurrent = (i * 100) + ((current * 100) ~/ total);
          final overallTotal = books.length * 100;
          onProgress?.call(overallCurrent, overallTotal);
        });
      }

      results[book.bookUrl] = success;
    }

    return results;
  }
}
