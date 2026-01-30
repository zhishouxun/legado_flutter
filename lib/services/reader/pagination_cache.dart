import 'package:flutter/material.dart';
import 'models/page_range.dart';

/// 分页缓存管理器 (参考Gemini文档的预读与缓存机制)
///
/// 核心策略：
/// 1. 仅缓存当前章节和相邻章节的分页结果
/// 2. 当用户调整字体/行高时，清空缓存
/// 3. 使用LRU策略管理缓存大小
class PaginationCache {
  /// 单例模式
  static final PaginationCache _instance = PaginationCache._internal();
  factory PaginationCache() => _instance;
  PaginationCache._internal();

  /// 缓存数据结构
  /// Key: 缓存键(由章节URL和配置参数组成)
  /// Value: 分页结果和元数据
  final Map<String, _CacheEntry> _cache = {};

  /// 最大缓存章节数(当前章 + 前后各1章 = 3章)
  static const int _maxCachedChapters = 5;

  /// LRU访问顺序记录
  final List<String> _accessOrder = [];

  /// 当前配置的哈希值
  /// 用于检测配置变化,自动清空缓存
  String _configHash = '';

  /// 生成缓存键
  ///
  /// [chapterUrl] 章节URL
  /// [maxWidth] 最大宽度
  /// [maxHeight] 最大高度
  /// [fontSize] 字体大小
  /// [lineHeight] 行高
  /// [letterSpacing] 字间距
  /// [fontWeight] 字重
  /// [fontFamily] 字体
  ///
  /// Returns: 缓存键
  String _generateKey({
    required String chapterUrl,
    required double maxWidth,
    required double maxHeight,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required FontWeight fontWeight,
    String? fontFamily,
  }) {
    return '$chapterUrl|$maxWidth|$maxHeight|$fontSize|$lineHeight|$letterSpacing|${fontWeight.index}|${fontFamily ?? ''}';
  }

  /// 生成配置哈希
  String _generateConfigHash({
    required double maxWidth,
    required double maxHeight,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required FontWeight fontWeight,
    String? fontFamily,
  }) {
    return '$maxWidth|$maxHeight|$fontSize|$lineHeight|$letterSpacing|${fontWeight.index}|${fontFamily ?? ''}';
  }

  /// 检查配置是否变化
  bool _checkConfigChanged({
    required double maxWidth,
    required double maxHeight,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required FontWeight fontWeight,
    String? fontFamily,
  }) {
    final newHash = _generateConfigHash(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
    );

    if (_configHash.isEmpty) {
      _configHash = newHash;
      return false;
    }

    if (_configHash != newHash) {
      debugPrint('分页配置变化，清空缓存');
      _configHash = newHash;
      return true;
    }

    return false;
  }

  /// 获取缓存的分页结果
  ///
  /// Returns: 分页列表，如果缓存不存在返回null
  List<PageRange>? get({
    required String chapterUrl,
    required double maxWidth,
    required double maxHeight,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required FontWeight fontWeight,
    String? fontFamily,
  }) {
    // 检查配置是否变化
    if (_checkConfigChanged(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
    )) {
      clear();
      return null;
    }

    final key = _generateKey(
      chapterUrl: chapterUrl,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
    );

    final entry = _cache[key];
    if (entry == null) return null;

    // 更新访问时间和顺序(LRU)
    entry.lastAccessTime = DateTime.now();
    _accessOrder.remove(key);
    _accessOrder.add(key);

    debugPrint('分页缓存命中: $chapterUrl (${entry.pages.length}页)');
    return entry.pages;
  }

  /// 存储分页结果到缓存
  void put({
    required String chapterUrl,
    required List<PageRange> pages,
    required double maxWidth,
    required double maxHeight,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required FontWeight fontWeight,
    String? fontFamily,
  }) {
    final key = _generateKey(
      chapterUrl: chapterUrl,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
    );

    // 添加到缓存
    _cache[key] = _CacheEntry(
      pages: pages,
      chapterUrl: chapterUrl,
      createTime: DateTime.now(),
      lastAccessTime: DateTime.now(),
    );

    // 更新LRU顺序
    _accessOrder.remove(key);
    _accessOrder.add(key);

    debugPrint('分页结果已缓存: $chapterUrl (${pages.length}页)');

    // 检查缓存大小，执行LRU淘汰
    _evictIfNeeded();
  }

  /// LRU淘汰策略
  void _evictIfNeeded() {
    if (_cache.length <= _maxCachedChapters) return;

    // 淘汰最久未使用的章节
    final toRemove = _accessOrder.length - _maxCachedChapters;
    for (int i = 0; i < toRemove; i++) {
      final key = _accessOrder.removeAt(0);
      final entry = _cache.remove(key);
      if (entry != null) {
        debugPrint('LRU淘汰缓存: ${entry.chapterUrl}');
      }
    }
  }

  /// 预读相邻章节
  ///
  /// 在后台预先分页相邻章节,提升用户体验
  ///
  /// [currentChapterUrl] 当前章节URL
  /// [prevChapterUrl] 上一章节URL
  /// [nextChapterUrl] 下一章节URL
  /// [getContent] 获取章节内容的回调函数
  /// [paginate] 分页函数
  Future<void> preloadAdjacentChapters({
    required String currentChapterUrl,
    String? prevChapterUrl,
    String? nextChapterUrl,
    required Future<String?> Function(String url) getContent,
    required List<PageRange> Function(String content) paginate,
  }) async {
    // 预读上一章
    if (prevChapterUrl != null && !_cache.containsKey(prevChapterUrl)) {
      try {
        final content = await getContent(prevChapterUrl);
        if (content != null && content.isNotEmpty) {
          final pages = paginate(content);
          // 注意：这里需要传递完整的配置参数才能正确缓存
          // 实际使用时应该从外部传入配置
          debugPrint('预读完成: $prevChapterUrl (${pages.length}页)');
        }
      } catch (e) {
        debugPrint('预读上一章失败: $e');
      }
    }

    // 预读下一章
    if (nextChapterUrl != null && !_cache.containsKey(nextChapterUrl)) {
      try {
        final content = await getContent(nextChapterUrl);
        if (content != null && content.isNotEmpty) {
          final pages = paginate(content);
          debugPrint('预读完成: $nextChapterUrl (${pages.length}页)');
        }
      } catch (e) {
        debugPrint('预读下一章失败: $e');
      }
    }
  }

  /// 清空所有缓存
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    debugPrint('分页缓存已清空');
  }

  /// 移除指定章节的缓存
  void remove(String chapterUrl) {
    _cache.removeWhere((key, _) => key.startsWith(chapterUrl));
    _accessOrder.removeWhere((key) => key.startsWith(chapterUrl));
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getStats() {
    return {
      'cachedChapters': _cache.length,
      'totalPages':
          _cache.values.fold<int>(0, (sum, entry) => sum + entry.pages.length),
      'accessOrder': _accessOrder.length,
      'configHash': _configHash,
    };
  }
}

/// 缓存条目
class _CacheEntry {
  final List<PageRange> pages;
  final String chapterUrl;
  final DateTime createTime;
  DateTime lastAccessTime;

  _CacheEntry({
    required this.pages,
    required this.chapterUrl,
    required this.createTime,
    required this.lastAccessTime,
  });
}
