import 'dart:async';
import 'package:flutter/material.dart';
import 'models/page_range.dart';
import 'paginator.dart';
import 'pagination_cache.dart';
import 'reading_position_manager.dart';

/// 阅读控制器 (整合分页、缓存、位置管理)
///
/// 这是一个高级控制器,集成了Gemini文档推荐的所有功能:
/// 1. 基于TextPainter的精确分页算法
/// 2. LRU缓存机制(当前章+相邻章)
/// 3. 字符偏移量的阅读位置保持
/// 4. 后台预读相邻章节
/// 5. 配置变化时自动重新分页
class ReaderController extends ChangeNotifier {
  /// 当前章节URL
  String? _currentChapterUrl;

  /// 分页状态
  PaginationState _state = const PaginationState();
  PaginationState get state => _state;

  /// 阅读配置
  ReadingConfig _config;
  ReadingConfig get config => _config;

  /// 缓存管理器
  final PaginationCache _cache = PaginationCache();

  /// 字符偏移量(用于位置保持)
  int _charOffset = 0;

  /// 是否启用缓存
  final bool enableCache;

  /// 是否启用预读
  final bool enablePreload;

  ReaderController({
    required ReadingConfig config,
    this.enableCache = true,
    this.enablePreload = true,
  }) : _config = config;

  /// 加载章节并分页
  ///
  /// [chapterUrl] 章节URL
  /// [content] 章节内容
  /// [charOffset] 阅读位置(字符偏移量,用于恢复位置)
  /// [onSavePosition] 保存阅读位置的回调
  Future<void> loadChapter({
    required String chapterUrl,
    required String content,
    int charOffset = 0,
    Future<void> Function(String chapterUrl, int offset)? onSavePosition,
  }) async {
    _currentChapterUrl = chapterUrl;
    _charOffset = charOffset;

    // 设置加载状态
    _state = _state.copyWith(
      content: content,
      isPaginating: true,
      error: null,
    );
    notifyListeners();

    try {
      // 尝试从缓存获取
      List<PageRange>? pages;

      if (enableCache) {
        pages = _cache.get(
          chapterUrl: chapterUrl,
          maxWidth: _config.visibleWidth,
          maxHeight: _config.visibleHeight,
          fontSize: _config.fontSize,
          lineHeight: _config.lineHeight,
          letterSpacing: _config.letterSpacing,
          fontWeight: _config.fontWeight,
          fontFamily: _config.fontFamily,
        );
      }

      // 如果缓存未命中,执行分页
      if (pages == null) {
        pages = await _paginateContent(content);

        // 存入缓存
        if (enableCache && pages.isNotEmpty) {
          _cache.put(
            chapterUrl: chapterUrl,
            pages: pages,
            maxWidth: _config.visibleWidth,
            maxHeight: _config.visibleHeight,
            fontSize: _config.fontSize,
            lineHeight: _config.lineHeight,
            letterSpacing: _config.letterSpacing,
            fontWeight: _config.fontWeight,
            fontFamily: _config.fontFamily,
          );
        }
      }

      // 恢复阅读位置
      final currentPage = ReadingPositionManager.restorePosition(
        chapterUrl: chapterUrl,
        charOffset: charOffset,
        pages: pages,
      );

      // 更新状态
      _state = _state.copyWith(
        pages: pages,
        currentPage: currentPage,
        isPaginating: false,
      );
      notifyListeners();

      debugPrint('章节加载完成: $chapterUrl, 总页数=${pages.length}, 当前页=$currentPage');
    } catch (e) {
      _state = _state.copyWith(
        isPaginating: false,
        error: '分页失败: $e',
      );
      notifyListeners();
      debugPrint('分页错误: $e');
    }
  }

  /// 执行分页(在后台执行)
  Future<List<PageRange>> _paginateContent(String content) async {
    // 可以在Isolate中执行,避免阻塞UI
    // 这里简化实现,直接调用
    return Paginator.paginate(
      content: content,
      maxWidth: _config.visibleWidth,
      maxHeight: _config.visibleHeight,
      style: _config.textStyle,
    );
  }

  /// 跳转到指定页
  void goToPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _state.totalPages) {
      debugPrint('无效的页码: $pageIndex');
      return;
    }

    _state = _state.copyWith(currentPage: pageIndex);
    notifyListeners();

    // 保存阅读位置
    _saveCurrentPosition();
  }

  /// 下一页
  void nextPage() {
    if (_state.currentPage < _state.totalPages - 1) {
      goToPage(_state.currentPage + 1);
    }
  }

  /// 上一页
  void previousPage() {
    if (_state.currentPage > 0) {
      goToPage(_state.currentPage - 1);
    }
  }

  /// 是否可以翻到下一页
  bool get canGoNext => _state.currentPage < _state.totalPages - 1;

  /// 是否可以翻到上一页
  bool get canGoPrevious => _state.currentPage > 0;

  /// 更新阅读配置
  ///
  /// **重要：配置变化时会自动重新分页并保持阅读位置**
  Future<void> updateConfig(ReadingConfig newConfig) async {
    if (_config == newConfig) return;

    final oldConfig = _config;
    _config = newConfig;

    // 检查是否需要重新分页
    final needRepaginate = oldConfig.fontSize != newConfig.fontSize ||
        oldConfig.lineHeight != newConfig.lineHeight ||
        oldConfig.letterSpacing != newConfig.letterSpacing ||
        oldConfig.fontWeight != newConfig.fontWeight ||
        oldConfig.fontFamily != newConfig.fontFamily ||
        oldConfig.maxWidth != newConfig.maxWidth ||
        oldConfig.maxHeight != newConfig.maxHeight;

    if (needRepaginate &&
        _currentChapterUrl != null &&
        _state.content.isNotEmpty) {
      debugPrint('配置变化，重新分页');

      // 记录当前字符偏移量
      if (_state.pages.isNotEmpty && _state.currentPage < _state.pages.length) {
        _charOffset = _state.pages[_state.currentPage].start;
      }

      // 重新加载章节(会自动恢复位置)
      await loadChapter(
        chapterUrl: _currentChapterUrl!,
        content: _state.content,
        charOffset: _charOffset,
      );
    } else {
      notifyListeners();
    }
  }

  /// 保存当前阅读位置
  Future<void> _saveCurrentPosition() async {
    if (_currentChapterUrl == null || _state.pages.isEmpty) return;
    if (_state.currentPage < 0 || _state.currentPage >= _state.pages.length)
      return;

    // 更新字符偏移量
    _charOffset = _state.pages[_state.currentPage].start;

    // 这里可以保存到数据库
    debugPrint('阅读位置: $_currentChapterUrl, 字符偏移=$_charOffset');
  }

  /// 获取当前页内容
  String? getCurrentPageContent() {
    if (_state.pages.isEmpty || _state.currentPage >= _state.pages.length) {
      return null;
    }

    return _state.pages[_state.currentPage].getContent(_state.content);
  }

  /// 获取阅读进度(0.0-1.0)
  double get progress {
    if (_state.content.isEmpty) return 0.0;

    return ReadingPositionManager.getProgress(
      currentPage: _state.currentPage,
      pages: _state.pages,
      totalChars: _state.content.length,
    );
  }

  /// 根据进度跳转
  void seekToProgress(double progress) {
    final pageIndex = ReadingPositionManager.getPageByProgress(
      progress: progress.clamp(0.0, 1.0),
      pages: _state.pages,
      totalChars: _state.content.length,
    );

    goToPage(pageIndex);
  }

  /// 预读相邻章节
  Future<void> preloadAdjacentChapters({
    String? prevChapterUrl,
    String? nextChapterUrl,
    required Future<String?> Function(String url) getContent,
  }) async {
    if (!enablePreload || !enableCache) return;

    await _cache.preloadAdjacentChapters(
      currentChapterUrl: _currentChapterUrl ?? '',
      prevChapterUrl: prevChapterUrl,
      nextChapterUrl: nextChapterUrl,
      getContent: getContent,
      paginate: (content) {
        return Paginator.paginate(
          content: content,
          maxWidth: _config.visibleWidth,
          maxHeight: _config.visibleHeight,
          style: _config.textStyle,
        );
      },
    );
  }

  /// 清空缓存
  void clearCache() {
    _cache.clear();
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
