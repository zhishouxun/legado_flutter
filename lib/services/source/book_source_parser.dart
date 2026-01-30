import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';

/// 基于Isolate的高效率JSON书源解析器
/// 
/// 设计目标:
/// 1. ✅ 在Isolate中执行JSON解析,彻底避免UI线程阻塞
/// 2. ✅ 支持批量解析,避免内存峰值
/// 3. ✅ 使用Stream流式返回结果,支持进度反馈
/// 4. ✅ 完善的错误处理和内存管理
/// 5. ✅ 与现有BookSource模型完全兼容
/// 
/// 符合项目规范: Memory要求"书源JSON文件的解析必须在Dart Isolate中执行"
class BookSourceParser {
  /// 默认批量大小(每批处理多少个书源)
  static const int defaultBatchSize = 50;

  /// 在Isolate中解析书源JSON字符串
  /// 
  /// 适用场景: 一次性解析完整的JSON,不需要进度反馈
  /// 
  /// [jsonString] JSON字符串(可以是数组或单个对象)
  /// 返回: BookSource列表
  static Future<List<BookSource>> parseInBackground(String jsonString) async {
    try {
      // 使用compute在独立Isolate中执行解析
      return await compute(_parseBookSourcesIsolate, jsonString);
    } catch (e) {
      AppLog.instance.put('在Isolate中解析书源失败', error: e);
      return [];
    }
  }

  /// 在Isolate中批量解析书源JSON(带进度反馈)
  /// 
  /// 适用场景: 大量书源解析,需要实时进度反馈和内存优化
  /// 
  /// `[jsonString]` JSON字符串
  /// `[batchSize]` 每批处理的书源数量(默认50个)
  /// 返回: `Stream<ParseResult>` 流式返回解析结果
  static Stream<ParseResult> parseInBatches({
    required String jsonString,
    int batchSize = defaultBatchSize,
  }) async* {
    try {
      // 第一步: 在Isolate中快速解析JSON结构(只解析到List<Map>)
      final rawData = await compute(_parseJsonStructure, jsonString);
      
      if (rawData.isEmpty) {
        yield ParseResult(
          sources: [],
          progress: 1.0,
          totalCount: 0,
          parsedCount: 0,
          isComplete: true,
        );
        return;
      }

      final totalCount = rawData.length;
      int parsedCount = 0;

      // 第二步: 分批在Isolate中解析BookSource对象
      for (int i = 0; i < rawData.length; i += batchSize) {
        final end = (i + batchSize < rawData.length) ? i + batchSize : rawData.length;
        final batch = rawData.sublist(i, end);

        // 在Isolate中解析当前批次
        final batchSources = await compute(_parseBatchBookSources, batch);
        
        parsedCount += batchSources.length;
        final progress = parsedCount / totalCount;

        // 流式emit结果
        yield ParseResult(
          sources: batchSources,
          progress: progress,
          totalCount: totalCount,
          parsedCount: parsedCount,
          isComplete: parsedCount >= totalCount,
        );
      }
    } catch (e) {
      AppLog.instance.put('批量解析书源失败', error: e);
      yield ParseResult(
        sources: [],
        progress: 1.0,
        totalCount: 0,
        parsedCount: 0,
        isComplete: true,
        error: e.toString(),
      );
    }
  }

  /// 从Assets加载并在Isolate中解析书源
  /// 
  /// 适用场景: 从assets目录加载默认书源
  /// 
  /// [jsonString] 已经读取的JSON字符串(由外部通过rootBundle.loadString获取)
  /// [onProgress] 进度回调(可选)
  /// 返回: BookSource列表
  static Future<List<BookSource>> parseFromAssetsString({
    required String jsonString,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (onProgress != null) {
        // 使用批量解析,支持进度回调
        final allSources = <BookSource>[];
        await for (final result in parseInBatches(jsonString: jsonString)) {
          allSources.addAll(result.sources);
          onProgress(result.progress);
        }
        return allSources;
      } else {
        // 直接解析,不需要进度反馈
        return await parseInBackground(jsonString);
      }
    } catch (e) {
      AppLog.instance.put('从Assets解析书源失败', error: e);
      return [];
    }
  }

  /// 从文件内容字符串解析书源
  /// 
  /// 适用场景: 用户导入本地书源文件
  /// 
  /// [jsonString] 已经读取的JSON字符串(由外部通过File.readAsString获取)
  /// [onProgress] 进度回调(可选)
  /// 返回: BookSource列表
  static Future<List<BookSource>> parseFromFileString({
    required String jsonString,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (onProgress != null) {
        // 使用批量解析,支持进度回调
        final allSources = <BookSource>[];
        await for (final result in parseInBatches(jsonString: jsonString)) {
          allSources.addAll(result.sources);
          onProgress(result.progress);
        }
        return allSources;
      } else {
        // 直接解析,不需要进度反馈
        return await parseInBackground(jsonString);
      }
    } catch (e) {
      AppLog.instance.put('从文件解析书源失败', error: e);
      return [];
    }
  }

  // ==================== Isolate执行的顶层/静态函数 ====================
  
  /// Isolate执行函数: 完整解析书源JSON
  /// 
  /// 必须是顶层函数或静态方法才能被compute调用
  static List<BookSource> _parseBookSourcesIsolate(String jsonString) {
    try {
      final jsonData = jsonDecode(jsonString);
      final sources = <BookSource>[];

      if (jsonData is List) {
        // 数组格式: [{"bookSourceUrl": "..."}]
        for (final item in jsonData) {
          if (item is Map<String, dynamic>) {
            try {
              final source = BookSource.fromJson(item);
              // 验证必填字段
              if (source.bookSourceUrl.isNotEmpty) {
                sources.add(source);
              }
            } catch (e) {
              // 单个书源解析失败不影响其他书源
              // 在Isolate中无法使用AppLog,只能静默处理
              continue;
            }
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        // 单个对象格式: {"bookSourceUrl": "..."}
        try {
          final source = BookSource.fromJson(jsonData);
          if (source.bookSourceUrl.isNotEmpty) {
            sources.add(source);
          }
        } catch (e) {
          // 解析失败返回空列表
        }
      }

      return sources;
    } catch (e) {
      // JSON解析失败返回空列表
      return [];
    }
  }

  /// Isolate执行函数: 仅解析JSON结构到List<Map>
  /// 
  /// 第一阶段: 快速解析JSON结构,不构造BookSource对象
  static List<Map<String, dynamic>> _parseJsonStructure(String jsonString) {
    try {
      final jsonData = jsonDecode(jsonString);
      final rawData = <Map<String, dynamic>>[];

      if (jsonData is List) {
        for (final item in jsonData) {
          if (item is Map<String, dynamic>) {
            rawData.add(item);
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        rawData.add(jsonData);
      }

      return rawData;
    } catch (e) {
      return [];
    }
  }

  /// Isolate执行函数: 解析一批BookSource对象
  /// 
  /// 第二阶段: 将Map转换为BookSource对象
  static List<BookSource> _parseBatchBookSources(List<Map<String, dynamic>> batch) {
    final sources = <BookSource>[];
    
    for (final item in batch) {
      try {
        final source = BookSource.fromJson(item);
        // 验证必填字段
        if (source.bookSourceUrl.isNotEmpty) {
          sources.add(source);
        }
      } catch (e) {
        // 单个书源解析失败不影响其他书源
        continue;
      }
    }

    return sources;
  }

  // ==================== 辅助方法 ====================
  // (实际使用时,由调用方提供jsonString,无需这些辅助方法)
}

/// 解析结果(用于流式返回)
class ParseResult {
  /// 本批次解析的书源列表
  final List<BookSource> sources;

  /// 当前进度(0.0 - 1.0)
  final double progress;

  /// 总书源数量
  final int totalCount;

  /// 已解析数量
  final int parsedCount;

  /// 是否完成
  final bool isComplete;

  /// 错误信息(如果有)
  final String? error;

  ParseResult({
    required this.sources,
    required this.progress,
    required this.totalCount,
    required this.parsedCount,
    required this.isComplete,
    this.error,
  });

  /// 是否成功
  bool get isSuccess => error == null;

  @override
  String toString() {
    return 'ParseResult(sources: ${sources.length}, progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'parsedCount: $parsedCount/$totalCount, isComplete: $isComplete, error: $error)';
  }
}
