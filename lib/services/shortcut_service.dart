import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import '../core/base/base_service.dart';
import '../utils/app_log.dart';
import '../services/book/book_service.dart';
import '../data/models/book.dart';

/// 快捷方式服务（Android 平台）
class ShortcutService extends BaseService {
  static final ShortcutService instance = ShortcutService._init();
  ShortcutService._init();

  static const MethodChannel _channel = MethodChannel('io.legado.app/shortcuts');

  /// 构建快捷方式
  /// 参考项目：ShortCuts.buildShortCuts()
  Future<void> buildShortcuts() async {
    if (!Platform.isAndroid) {
      // 仅 Android 平台支持
      return;
    }

    try {
      // 获取最后阅读的书籍
      final lastReadBook = await _getLastReadBook();

      // 调用原生代码创建快捷方式
      await _channel.invokeMethod('buildShortcuts', {
        'hasLastReadBook': lastReadBook != null,
        'lastReadBookUrl': lastReadBook?.bookUrl,
        'lastReadBookName': lastReadBook?.name,
      });

      AppLog.instance.put('快捷方式创建成功');
    } catch (e) {
      AppLog.instance.put('创建快捷方式失败', error: e);
    }
  }

  /// 获取最后阅读的书籍
  Future<Book?> _getLastReadBook() async {
    try {
      final books = await BookService.instance.getBookshelfBooks();
      if (books.isEmpty) {
        return null;
      }

      // 按最后阅读时间排序，获取最近阅读的书籍
      books.sort((a, b) => b.durChapterTime.compareTo(a.durChapterTime));
      final lastReadBook = books.first;

      // 检查是否有阅读进度
      if (lastReadBook.durChapterTime == 0) {
        return null;
      }

      return lastReadBook;
    } catch (e) {
      AppLog.instance.put('获取最后阅读书籍失败', error: e);
      return null;
    }
  }
}

