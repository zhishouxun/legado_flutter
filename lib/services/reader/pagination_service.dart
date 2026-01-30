import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models/page_range.dart';
import 'paginator.dart';
import 'reading_position_manager.dart';

/// 分页服务 (参考Gemini文档: 分页引擎 Paginator.md)
///
/// 使用Flutter的compute函数在Isolate中执行分页，避免阻塞UI线程
class PaginationService {
  /// 在Isolate中执行分页计算
  ///
  /// [content] 章节内容
  /// [config] 阅读配置
  ///
  /// Returns: 分页范围列表
  static Future<List<PageRange>> computePages({
    required String content,
    required ReadingConfig config,
  }) async {
    // 使用Flutter提供的compute函数在后台Isolate执行
    return await compute(
        _internalPaginate,
        _PaginationParams(
          content: content,
          config: config,
        ));
  }

  /// 内部分页函数(在Isolate中执行)
  static List<PageRange> _internalPaginate(_PaginationParams params) {
    return Paginator.paginate(
      content: params.content,
      maxWidth: params.config.renderWidth,
      maxHeight: params.config.renderHeight,
      style: params.config.textStyle,
    );
  }

  /// 批量分页(多章节)
  ///
  /// [chapters] 章节内容列表
  /// [config] 阅读配置
  ///
  /// Returns: 每章的分页结果列表
  static Future<List<List<PageRange>>> computeBatchPages({
    required List<String> chapters,
    required ReadingConfig config,
  }) async {
    return await compute(
        _internalBatchPaginate,
        _BatchPaginationParams(
          chapters: chapters,
          config: config,
        ));
  }

  /// 批量分页的内部实现
  static List<List<PageRange>> _internalBatchPaginate(
      _BatchPaginationParams params) {
    return params.chapters.map((content) {
      return Paginator.paginate(
        content: content,
        maxWidth: params.config.renderWidth,
        maxHeight: params.config.renderHeight,
        style: params.config.textStyle,
      );
    }).toList();
  }

  /// 增量分页(渐进式渲染)
  ///
  /// 适用于长章节，先快速分出前几页显示，后续页面在后台继续计算
  ///
  /// [content] 章节内容
  /// [config] 阅读配置
  /// [initialPageCount] 初始页面数量(默认5页)
  /// [onProgress] 进度回调
  ///
  /// Returns: 完整的分页结果
  static Future<List<PageRange>> computePagesIncremental({
    required String content,
    required ReadingConfig config,
    int initialPageCount = 5,
    void Function(List<PageRange> pages)? onProgress,
  }) async {
    final List<PageRange> allPages = [];
    final List<PageRange> existingPages = [];

    // 第一轮：快速分出前几页
    final initialPages = await compute(
        _internalPaginateIncremental,
        _IncrementalParams(
          content: content,
          config: config,
          existingPages: existingPages,
          maxPages: initialPageCount,
        ));

    allPages.addAll(initialPages);
    existingPages.addAll(initialPages);
    onProgress?.call(List.from(allPages));

    // 如果还没分页完成，继续在后台分页
    while (
        existingPages.isNotEmpty && existingPages.last.end < content.length) {
      final morePages = await compute(
          _internalPaginateIncremental,
          _IncrementalParams(
            content: content,
            config: config,
            existingPages: existingPages,
            maxPages: 10, // 每次增加10页
          ));

      if (morePages.isEmpty) break;

      allPages.addAll(morePages);
      existingPages.addAll(morePages);
      onProgress?.call(List.from(allPages));
    }

    return allPages;
  }

  /// 增量分页的内部实现
  static List<PageRange> _internalPaginateIncremental(
      _IncrementalParams params) {
    return Paginator.paginateIncremental(
      existingPages: params.existingPages,
      content: params.content,
      maxWidth: params.config.renderWidth,
      maxHeight: params.config.renderHeight,
      style: params.config.textStyle,
      maxPages: params.maxPages,
    );
  }

  /// 内容清洗(段落缩进)
  ///
  /// Legado风格的阅读器需要首行缩进
  /// 参考Gemini文档建议：在每段开头添加两个全角空格
  ///
  /// [content] 原始内容
  ///
  /// Returns: 清洗后的内容
  static String cleanContent(String content) {
    return content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => '\u3000\u3000$line') // 添加两个全角空格
        .join('\n\n'); // 段落间距
  }
}

/// 分页参数(用于Isolate传递)
class _PaginationParams {
  final String content;
  final ReadingConfig config;

  _PaginationParams({
    required this.content,
    required this.config,
  });
}

/// 批量分页参数
class _BatchPaginationParams {
  final List<String> chapters;
  final ReadingConfig config;

  _BatchPaginationParams({
    required this.chapters,
    required this.config,
  });
}

/// 增量分页参数
class _IncrementalParams {
  final String content;
  final ReadingConfig config;
  final List<PageRange> existingPages;
  final int maxPages;

  _IncrementalParams({
    required this.content,
    required this.config,
    required this.existingPages,
    required this.maxPages,
  });
}
