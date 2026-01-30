import 'dart:convert';
import 'package:flutter/material.dart';
import 'book_source_parser.dart';
import 'book_source_service.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';

/// 基于Isolate的书源解析器使用示例
/// 
/// 展示如何在实际场景中使用BookSourceParser

// ==================== 示例1: 从网络导入书源(带进度条) ====================

class ImportBookSourcesWithProgressExample extends StatefulWidget {
  const ImportBookSourcesWithProgressExample({Key? key}) : super(key: key);

  @override
  State<ImportBookSourcesWithProgressExample> createState() =>
      _ImportBookSourcesWithProgressExampleState();
}

class _ImportBookSourcesWithProgressExampleState
    extends State<ImportBookSourcesWithProgressExample> {
  double _progress = 0.0;
  String _statusText = '准备导入...';
  // final int _totalCount = 0;  // 预留字段
  // final int _parsedCount = 0; // 预留字段

  /// 从网络URL导入书源
  Future<void> _importFromUrl(String url) async {
    try {
      setState(() {
        _progress = 0.0;
        _statusText = '正在下载书源...';
      });

      // 第一步: 下载JSON文件(这里需要使用NetworkService)
      // final response = await NetworkService.instance.get(url);
      // final jsonString = response.data as String;
      
      // 示例用的假数据
      const jsonString = '''
      [
        {"bookSourceUrl": "https://example1.com", "bookSourceName": "示例书源1"},
        {"bookSourceUrl": "https://example2.com", "bookSourceName": "示例书源2"}
      ]
      ''';

      setState(() {
        _statusText = '正在解析书源(Isolate)...';
      });

      // 第二步: 在Isolate中解析JSON,并导入数据库
      final result = await BookSourceService.instance.importBookSourcesFromJson(
        jsonString,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
            _statusText = '解析进度: ${(progress * 100).toStringAsFixed(1)}%';
          });
        },
      );

      // 第三步: 显示结果
      setState(() {
        _progress = 1.0;
        _statusText = '导入完成! 成功${result['imported']}个, '
            '过滤${result['blocked']}个, 总共${result['total']}个';
      });

      AppLog.instance.put('书源导入结果: $result');
    } catch (e) {
      setState(() {
        _statusText = '导入失败: $e';
      });
      AppLog.instance.put('导入书源失败', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入书源示例')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 进度条
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 16),
            
            // 状态文本
            Text(
              _statusText,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // 导入按钮
            ElevatedButton(
              onPressed: () => _importFromUrl('https://example.com/sources.json'),
              child: const Text('从网络导入书源'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 示例2: 批量解析大量书源(流式处理) ====================

/// 批量解析示例
/// 展示如何处理大量书源(如10000+个)而不阻塞UI
class BatchParseExample {
  static Future<void> parseLargeBookSourceFile(String jsonString) async {
    final allSources = <BookSource>[];
    int totalCount = 0;
    // int errorCount = 0; // 预留字段用于跟踪错误

    print('开始批量解析书源...');

    // 使用Stream逐批处理
    await for (final result in BookSourceParser.parseInBatches(
      jsonString: jsonString,
      batchSize: 100, // 每批100个,避免内存峰值
    )) {
      // 处理每批结果
      allSources.addAll(result.sources);
      totalCount = result.totalCount;

      // 实时日志
      print('解析进度: ${(result.progress * 100).toStringAsFixed(1)}% '
          '(${result.parsedCount}/$totalCount)');

      // 检查错误
      if (result.error != null) {
        // errorCount++; // 如需跟踪错误,取消注释
        print('警告: 批次解析失败: ${result.error}');
      }

      // 完成
      if (result.isComplete) {
        print('✅ 解析完成! 总共${allSources.length}个书源');
        break;
      }
    }

    // 批量导入数据库
    if (allSources.isNotEmpty) {
      print('开始导入数据库...');
      final importResult = await BookSourceService.instance.importBookSources(allSources);
      print('✅ 导入完成: ${importResult['imported']}个成功, '
          '${importResult['blocked']}个被过滤');
    }
  }
}

// ==================== 示例3: 从本地文件导入 ====================

/// 从本地文件导入书源
class ImportFromFileExample {
  static Future<void> importFromLocalFile(String filePath) async {
    try {
      print('开始从文件导入: $filePath');

      // 第一步: 读取文件内容(需要使用dart:io的File)
      // final file = File(filePath);
      // final jsonString = await file.readAsString();
      
      // 第二步: 使用BookSourceParser解析(内部使用Isolate)
      // final sources = await BookSourceParser.parseFromFileString(
      //   jsonString: jsonString,
      //   onProgress: (progress) {
      //     print('解析进度: ${(progress * 100).toStringAsFixed(1)}%');
      //   },
      // );

      // print('✅ 解析完成: ${sources.length}个书源');

      // 导入数据库
      // if (sources.isNotEmpty) {
      //   final result = await BookSourceService.instance.importBookSources(sources);
      //   print('✅ 导入完成: ${result['imported']}个成功, '
      //       '${result['blocked']}个被过滤');
      // }
      
      print('✅ 示例代码(需要取消注释)');
    } catch (e) {
      print('❌ 导入失败: $e');
    }
  }
}

// ==================== 示例4: 性能对比 ====================

/// 性能对比: Isolate vs UI线程
class PerformanceComparisonExample {
  /// 旧方式: 在UI线程解析(会阻塞)
  static Future<List<BookSource>> parseInUIThread(String jsonString) async {
    final stopwatch = Stopwatch()..start();
    
    // 直接在当前线程解析(危险!)
    final jsonData = jsonDecode(jsonString) as List;
    final sources = jsonData
        .map((item) => BookSource.fromJson(item as Map<String, dynamic>))
        .toList();
    
    stopwatch.stop();
    print('UI线程解析耗时: ${stopwatch.elapsedMilliseconds}ms');
    print('⚠️ 警告: UI线程被阻塞了${stopwatch.elapsedMilliseconds}ms!');
    
    return sources;
  }

  /// 新方式: 在Isolate解析(不阻塞UI)
  static Future<List<BookSource>> parseInIsolate(String jsonString) async {
    final stopwatch = Stopwatch()..start();
    
    // 在Isolate中解析(推荐!)
    final sources = await BookSourceParser.parseInBackground(jsonString);
    
    stopwatch.stop();
    print('Isolate解析耗时: ${stopwatch.elapsedMilliseconds}ms');
    print('✅ UI线程未被阻塞!');
    
    return sources;
  }

  /// 运行性能对比
  static Future<void> runComparison(String jsonString) async {
    print('=' * 60);
    print('性能对比测试');
    print('=' * 60);

    print('\n测试1: UI线程解析(旧方式)');
    await parseInUIThread(jsonString);

    print('\n测试2: Isolate解析(新方式)');
    await parseInIsolate(jsonString);

    print('\n' + '=' * 60);
    print('结论: Isolate解析不会阻塞UI线程,用户体验更好!');
    print('=' * 60);
  }
}

// ==================== 示例5: 错误处理 ====================

/// 错误处理示例
class ErrorHandlingExample {
  static Future<void> parseWithErrorHandling(String jsonString) async {
    try {
      // 方式1: 使用parseInBackground
      final sources = await BookSourceParser.parseInBackground(jsonString);
      
      if (sources.isEmpty) {
        print('⚠️ 警告: 没有解析到任何书源');
        // 检查JSON格式是否正确
        // 检查书源URL是否为空
      } else {
        print('✅ 成功解析${sources.length}个书源');
      }
    } catch (e) {
      print('❌ 解析失败: $e');
      // 处理错误:
      // 1. 检查JSON格式
      // 2. 提示用户
      // 3. 记录日志
    }

    // 方式2: 使用parseInBatches(带详细错误信息)
    await for (final result in BookSourceParser.parseInBatches(
      jsonString: jsonString,
    )) {
      if (result.error != null) {
        print('❌ 批次解析错误: ${result.error}');
        // 记录错误但继续处理
      }

      if (!result.isSuccess) {
        print('⚠️ 部分书源解析失败');
      }

      if (result.isComplete) {
        print('✅ 解析完成(包含错误): ${result.parsedCount}/${result.totalCount}');
      }
    }
  }
}

// ==================== 使用说明 ====================

/// 使用指南:
/// 
/// 1. 简单场景(一次性解析):
///    ```dart
///    final sources = await BookSourceParser.parseInBackground(jsonString);
///    ```
/// 
/// 2. 大量数据场景(需要进度反馈):
///    ```dart
///    await for (final result in BookSourceParser.parseInBatches(jsonString: json)) {
///      print('进度: ${result.progress}');
///      // 处理result.sources
///    }
///    ```
/// 
/// 3. 从Assets加载:
///    ```dart
///    final jsonString = await rootBundle.loadString('assets/defaultData/bookSources.json');
///    final sources = await BookSourceParser.parseFromAssetsString(
///      jsonString: jsonString,
///      onProgress: (progress) => print('$progress'),
///    );
///    ```
/// 
/// 4. 导入到数据库(推荐):
///    ```dart
///    final result = await BookSourceService.instance.importBookSourcesFromJson(
///      jsonString,
///      onProgress: (progress) => updateUI(progress),
///    );
///    print('导入${result['imported']}个,过滤${result['blocked']}个');
///    ```
/// 
/// 性能优势:
/// - ✅ 彻底避免UI线程阻塞
/// - ✅ 支持大文件(10000+书源)
/// - ✅ 内存优化(批量处理)
/// - ✅ 实时进度反馈
/// - ✅ 完善的错误处理
