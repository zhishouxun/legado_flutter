import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../core/base/base_service.dart';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import '../../data/models/book_source.dart';
import '../book/book_service.dart';
import '../../utils/app_log.dart';
import '../notification_service.dart';

/// 缓存服务 - 管理章节缓存
/// 参考项目：io.legado.app.service.CacheBookService
class CacheService extends BaseService {
  static final CacheService instance = CacheService._init();
  CacheService._init();

  static const String cacheFolderName = 'book_cache';
  static const int notificationId = 103; // 参考项目：NotificationId.CacheBookService

  /// 获取缓存目录
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$cacheFolderName');
  }

  /// 获取缓存目录（公共方法）
  Future<Directory> getCacheDir() async {
    return await _getCacheDir();
  }

  /// 获取书籍缓存目录
  Future<Directory> _getBookCacheDir(Book book) async {
    final cacheDir = await _getCacheDir();
    final bookDir = Directory('${cacheDir.path}/${_getBookFolderName(book)}');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    return bookDir;
  }

  /// 获取书籍文件夹名称
  /// 参考项目：Book.getFolderNameNoCache()
  /// 使用书名前9位 + MD5(bookUrl) 作为文件夹名
  String _getBookFolderName(Book book) {
    // 参考项目：移除文件名非法字符
    final cleanName = book.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    // 参考项目：取书名前9位
    final prefix = cleanName.length > 9 ? cleanName.substring(0, 9) : cleanName;
    // 参考项目：使用 bookUrl 的 MD5 前16位
    final bytes = utf8.encode(book.bookUrl);
    final digest = md5.convert(bytes);
    final hash = digest.toString().substring(0, 16);
    return '$prefix$hash';
  }

  /// 获取章节文件名
  /// 参考项目：BookChapter.getFileName() 使用 {index5位}-{titleMD5}.{suffix} 格式
  String _getChapterFileName(BookChapter chapter, [String suffix = 'nb']) {
    // 参考项目：使用章节标题的 MD5 前16位
    final titleBytes = utf8.encode(chapter.title);
    final titleDigest = md5.convert(titleBytes);
    final titleMD5 = titleDigest.toString().substring(0, 16);
    // 参考项目：格式为 {index5位补0}-{titleMD5}.{suffix}
    return '${chapter.index.toString().padLeft(5, '0')}-$titleMD5.$suffix';
  }

  /// 检查章节是否已缓存
  Future<bool> hasChapterCache(Book book, BookChapter chapter) async {
    if (book.isLocal) return true; // 本地书籍不需要缓存

    try {
      final bookDir = await _getBookCacheDir(book);
      final fileName = _getChapterFileName(chapter);
      final file = File('${bookDir.path}/$fileName');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取书籍已缓存的章节数量
  Future<int> getCachedChapterCount(
      Book book, List<BookChapter> chapters) async {
    if (book.isLocal) return chapters.length;

    int count = 0;
    for (final chapter in chapters) {
      if (await hasChapterCache(book, chapter)) {
        count++;
      }
    }
    return count;
  }

  /// 获取已缓存的章节文件列表
  Future<Set<String>> getCachedChapterFiles(Book book) async {
    if (book.isLocal) return {};

    try {
      final bookDir = await _getBookCacheDir(book);
      if (!await bookDir.exists()) return {};

      final files = await bookDir.list().toList();
      return files
          .whereType<File>()
          .map((file) => file.path.split('/').last)
          .toSet();
    } catch (e) {
      return {};
    }
  }

  /// 缓存章节内容
  Future<bool> cacheChapter(
      Book book, BookChapter chapter, BookSource source) async {
    if (book.isLocal) return true;

    try {
      // 检查是否已缓存
      if (await hasChapterCache(book, chapter)) {
        return true;
      }

      // 获取章节内容
      final content = await BookService.instance.getChapterContent(
        chapter,
        source,
        bookName: book.name,
        bookOrigin: book.origin,
      );
      if (content == null || content.isEmpty) {
        AppLog.instance.put('缓存章节失败: ${chapter.title} - 内容为空');
        return false;
      }

      // 保存到文件
      final bookDir = await _getBookCacheDir(book);
      final fileName = _getChapterFileName(chapter);
      final file = File('${bookDir.path}/$fileName');
      await file.writeAsString(content, encoding: utf8);

      return true;
    } catch (e) {
      AppLog.instance.put('缓存章节失败: ${chapter.title}', error: e);
      return false;
    }
  }

  /// 直接保存章节内容到缓存（不调用 getChapterContent）
  /// 参考项目：BookHelp.saveText
  Future<bool> saveChapterContent(
      Book book, BookChapter chapter, String content) async {
    if (book.isLocal) return true;
    if (content.isEmpty) return false;

    try {
      // #region agent log
      try{final f=File('/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');f.writeAsStringSync('${jsonEncode({"location":"cache_service.dart:159","message":"保存章节内容到缓存","data":{"chapterTitle":chapter.title,"chapterIndex":chapter.index,"contentLength":content.length,"contentPreview":content.length > 150 ? content.substring(0, 150) : content},"timestamp":DateTime.now().millisecondsSinceEpoch,"sessionId":"debug-session","hypothesisId":"E"})}\n',mode:FileMode.append);}catch(_){}
      // #endregion
      
      final bookDir = await _getBookCacheDir(book);
      final fileName = _getChapterFileName(chapter);
      final file = File('${bookDir.path}/$fileName');
      await file.writeAsString(content, encoding: utf8);
      return true;
    } catch (e) {
      AppLog.instance.put('保存章节内容失败: ${chapter.title}', error: e);
      return false;
    }
  }

  /// 批量缓存章节
  /// 参考项目：CacheBookService.download()
  Future<Map<String, bool>> cacheChapters(
    Book book,
    List<BookChapter> chapters,
    BookSource source, {
    Function(int current, int total)? onProgress,
    bool showNotification = false,
  }) async {
    final results = <String, bool>{};

    // 显示通知（如果启用）
    if (showNotification) {
      await NotificationService.instance.showProgressNotification(
        id: notificationId,
        title: '缓存书籍',
        content: '正在缓存: ${book.name}',
        progress: 0.0,
        max: chapters.length,
        current: 0,
        isOngoing: true,
        channelId: NotificationService.channelIdCache,
      );
    }

    try {
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final success = await cacheChapter(book, chapter, source);
        // 参考项目：使用 bookUrl + chapterUrl 作为结果的 key
        results[chapter.primaryStr()] = success;

        // 更新进度
        if (onProgress != null) {
          onProgress(i + 1, chapters.length);
        }

        // 更新通知
        if (showNotification) {
          final progress = (i + 1) / chapters.length;
          await NotificationService.instance.showProgressNotification(
            id: notificationId,
            title: '缓存书籍',
            content: '正在缓存: ${book.name} (${i + 1}/${chapters.length})',
            progress: progress,
            max: chapters.length,
            current: i + 1,
            isOngoing: true,
            channelId: NotificationService.channelIdCache,
          );
        }
      }

      // 完成通知
      if (showNotification) {
        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '缓存完成',
          content: '${book.name} 缓存完成',
          isOngoing: false,
          channelId: NotificationService.channelIdCache,
        );
      }
    } catch (e) {
      // 错误通知
      if (showNotification) {
        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '缓存失败',
          content: '${book.name} 缓存失败: ${e.toString()}',
          isOngoing: false,
          channelId: NotificationService.channelIdCache,
        );
      }
      rethrow;
    }

    return results;
  }

  /// 清除书籍缓存
  Future<bool> clearBookCache(Book book) async {
    try {
      final bookDir = await _getBookCacheDir(book);
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      AppLog.instance.put('清除缓存失败: ${book.name}', error: e);
      return false;
    }
  }

  /// 批量清除书籍缓存
  Future<Map<String, bool>> clearBooksCache(List<Book> books) async {
    final results = <String, bool>{};

    for (final book in books) {
      final success = await clearBookCache(book);
      results[book.bookUrl] = success;
    }

    return results;
  }

  /// 清除所有缓存
  Future<bool> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      AppLog.instance.put('清除所有缓存失败', error: e);
      return false;
    }
  }

  /// 获取缓存的章节内容
  Future<String?> getCachedChapterContent(
      Book book, BookChapter chapter) async {
    if (book.isLocal) return null;

    try {
      final bookDir = await _getBookCacheDir(book);
      final fileName = _getChapterFileName(chapter);
      final file = File('${bookDir.path}/$fileName');

      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        // #region agent log
        try{final f=File('/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');f.writeAsStringSync('${jsonEncode({"location":"cache_service.dart:302","message":"从缓存读取章节内容","data":{"chapterTitle":chapter.title,"chapterIndex":chapter.index,"fileName":fileName,"contentLength":content.length,"contentPreview":content.length > 150 ? content.substring(0, 150) : content},"timestamp":DateTime.now().millisecondsSinceEpoch,"sessionId":"debug-session","hypothesisId":"E"})}\n',mode:FileMode.append);}catch(_){}
        // #endregion
        return content;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
