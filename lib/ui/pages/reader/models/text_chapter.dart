import 'dart:async';
import 'package:legado_flutter/data/models/book_chapter.dart';
import 'text_page.dart';

/// 文本章节类（参考项目：TextChapter.kt）
/// 用于管理章节的分页数据和状态
class TextChapter {
  final BookChapter chapter;
  final String displayTitle;
  final int chapterIndex;
  final int chaptersSize;
  final bool sameTitleRemoved;
  final bool isVip;
  final bool isPay;

  /// 分页后的页面列表
  final List<TextPage> _pages = [];
  List<TextPage> get pages => _pages;

  /// 是否已完成排版
  bool isCompleted = false;

  /// 渐进式渲染Stream（参考项目：layoutChannel）
  /// 每完成一页就发送到Stream，实现渐进式渲染
  final _pageStreamController = StreamController<TextPage>.broadcast();
  Stream<TextPage> get pageStream => _pageStreamController.stream;

  /// 排版异常
  Exception? _layoutException;
  Exception? get layoutException => _layoutException;

  /// 章节内容（处理后的）
  String? _content;
  String? get content => _content;

  /// 最后阅读位置（字符索引）
  int get lastReadLength {
    if (_pages.isEmpty) return 0;
    return _pages.last.chapterPosition + _pages.last.charSize;
  }

  /// 页面数量
  int get pageSize => _pages.length;

  /// 最后页面索引
  int get lastIndex => _pages.isEmpty ? -1 : _pages.length - 1;

  TextChapter({
    required this.chapter,
    required this.displayTitle,
    required this.chapterIndex,
    required this.chaptersSize,
    this.sameTitleRemoved = false,
    this.isVip = false,
    this.isPay = false,
  });

  /// 添加页面（参考项目：onPageCompleted）
  /// [notifyStream] 是否通知Stream（用于渐进式渲染）
  void addPage(TextPage page, {bool notifyStream = false}) {
    page.index = _pages.length;
    page.chapterIndex = chapterIndex;
    page.chapterSize = chaptersSize;
    page.title = displayTitle;
    page.isCompleted = true;
    _pages.add(page);

    // 发送到Stream（渐进式渲染）
    if (notifyStream && !_pageStreamController.isClosed) {
      _pageStreamController.add(page);
    }
  }

  /// 标记排版完成（参考项目：onLayoutCompleted）
  void markCompleted() {
    isCompleted = true;
    if (!_pageStreamController.isClosed) {
      _pageStreamController.close();
    }
  }

  /// 标记排版异常（参考项目：onLayoutException）
  void markException(Exception e) {
    _layoutException = e;
    if (!_pageStreamController.isClosed) {
      _pageStreamController.addError(e);
      _pageStreamController.close();
    }
  }

  /// 取消排版
  void cancelLayout() {
    if (!_pageStreamController.isClosed) {
      _pageStreamController.close();
    }
  }

  /// 释放资源
  void dispose() {
    cancelLayout();
  }

  /// 获取指定索引的页面
  TextPage? getPage(int index) {
    if (index < 0 || index >= _pages.length) return null;
    return _pages[index];
  }

  /// 根据字符位置获取页面索引
  int getPageIndexByCharIndex(int charIndex) {
    if (_pages.isEmpty) return -1;
    
    // 二分查找
    int left = 0;
    int right = _pages.length - 1;
    
    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final page = _pages[mid];
      final pageStart = page.chapterPosition;
      final pageEnd = pageStart + page.charSize;
      
      if (charIndex >= pageStart && charIndex < pageEnd) {
        return mid;
      } else if (charIndex < pageStart) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    
    // 如果未完成排版且字符位置超出最后一页，返回-1
    if (!isCompleted && left == _pages.length) {
      final lastPage = _pages.last;
      final lastPageEnd = lastPage.chapterPosition + lastPage.charSize;
      if (charIndex > lastPageEnd) {
        return -1;
      }
    }
    
    // 返回最接近的页面索引
    return left.clamp(0, _pages.length - 1);
  }

  /// 获取指定页面的阅读位置（字符索引）
  int getReadLength(int pageIndex) {
    if (pageIndex < 0) return 0;
    if (pageIndex >= _pages.length) {
      return lastReadLength;
    }
    return _pages[pageIndex].chapterPosition;
  }

  /// 获取下一页的位置，如果没有下一页返回-1
  int getNextPageLength(int currentPos) {
    final pageIndex = getPageIndexByCharIndex(currentPos);
    if (pageIndex < 0 || pageIndex + 1 >= _pages.length) {
      return -1;
    }
    return getReadLength(pageIndex + 1);
  }

  /// 获取上一页的位置，如果没有上一页返回-1
  int getPrevPageLength(int currentPos) {
    final pageIndex = getPageIndexByCharIndex(currentPos);
    if (pageIndex <= 0) {
      return -1;
    }
    return getReadLength(pageIndex - 1);
  }

  /// 设置内容
  void setContent(String content) {
    _content = content;
  }

  /// 清除搜索结果显示
  void clearSearchResult() {
    for (final page in _pages) {
      page.clearSearchResult();
    }
  }

  /// 判断是否是最后一页
  bool isLastIndex(int index) {
    return isCompleted && index >= _pages.length - 1;
  }

  /// 判断是否是当前最后一页（即使未完成排版）
  bool isLastIndexCurrent(int index) {
    return index >= _pages.length - 1;
  }
}

