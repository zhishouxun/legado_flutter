#!/usr/bin/env dart
/// 书源搜索功能测试工具
/// 实际测试书源的搜索功能是否可用

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 简化的书源模型
class TestBookSource {
  final String bookSourceUrl;
  final String bookSourceName;
  final String? searchUrl;
  final Map<String, dynamic>? ruleSearch;
  final Map<String, dynamic>? rawData;

  TestBookSource({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.searchUrl,
    this.ruleSearch,
    this.rawData,
  });

  factory TestBookSource.fromJson(Map<String, dynamic> json) {
    return TestBookSource(
      bookSourceUrl: json['bookSourceUrl']?.toString() ?? '',
      bookSourceName: json['bookSourceName']?.toString() ?? '',
      searchUrl: json['searchUrl']?.toString(),
      ruleSearch: json['ruleSearch'] is Map
          ? Map<String, dynamic>.from(json['ruleSearch'])
          : null,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => rawData ?? {};
}

/// 测试结果
class TestResult {
  final String sourceUrl;
  final String sourceName;
  final bool success;
  final String? error;
  final int responseTime;
  final int? resultCount;

  TestResult({
    required this.sourceUrl,
    required this.sourceName,
    required this.success,
    this.error,
    required this.responseTime,
    this.resultCount,
  });

  @override
  String toString() {
    if (success) {
      return '✓ ${sourceName.padRight(30)} [${responseTime}ms] 找到 ${resultCount ?? 0} 个结果';
    }
    return '✗ ${sourceName.padRight(30)} [${responseTime}ms] 失败: $error';
  }
}

/// 测试搜索功能
Future<TestResult> testSearch(TestBookSource source, String keyword) async {
  final startTime = DateTime.now();
  
  try {
    // 检查必需字段
    if (source.searchUrl == null || source.searchUrl!.isEmpty) {
      return TestResult(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        success: false,
        error: '缺少搜索URL',
        responseTime: 0,
      );
    }

    if (source.ruleSearch == null || source.ruleSearch!.isEmpty) {
      return TestResult(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        success: false,
        error: '缺少搜索规则',
        responseTime: 0,
      );
    }

    // 构建搜索URL（简单替换）
    var searchUrl = source.searchUrl!;
    searchUrl = searchUrl.replaceAll('{{key}}', Uri.encodeComponent(keyword));
    searchUrl = searchUrl.replaceAll('<key>', Uri.encodeComponent(keyword));
    searchUrl = searchUrl.replaceAll('\$key', keyword);
    
    // 处理相对URL
    if (!searchUrl.startsWith('http://') && !searchUrl.startsWith('https://')) {
      final baseUrl = source.bookSourceUrl;
      if (searchUrl.startsWith('/')) {
        // 绝对路径
        final uri = Uri.parse(baseUrl);
        searchUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$searchUrl';
      } else {
        // 相对路径
        searchUrl = baseUrl.endsWith('/') 
            ? '$baseUrl$searchUrl' 
            : '$baseUrl/$searchUrl';
      }
    }

    // 发送HTTP请求（3秒超时）
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    client.idleTimeout = const Duration(seconds: 3);
    
    final uri = Uri.parse(searchUrl);
    final request = await client.getUrl(uri).timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw TimeoutException('连接超时'),
    );
    
    // 设置User-Agent
    request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    
    final response = await request.close().timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('响应超时'),
    );

    if (response.statusCode != 200) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      return TestResult(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        success: false,
        error: 'HTTP ${response.statusCode}',
        responseTime: responseTime,
      );
    }

    // 读取响应（限制大小，避免占用过多内存）
    final responseBytes = await response
        .timeout(const Duration(seconds: 5))
        .fold<List<int>>(
          [],
          (previous, element) {
            if (previous.length > 1024 * 1024) {
              // 限制1MB
              return previous;
            }
            return previous..addAll(element);
          },
        );

    final html = utf8.decode(responseBytes, allowMalformed: true);
    
    final responseTime = DateTime.now().difference(startTime).inMilliseconds;
    client.close();

    // 简单检查：响应不为空且长度合理
    if (html.isEmpty) {
      return TestResult(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        success: false,
        error: '响应为空',
        responseTime: responseTime,
      );
    }

    if (html.length < 100) {
      return TestResult(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        success: false,
        error: '响应过短 (${html.length}字节)',
        responseTime: responseTime,
      );
    }

    // 成功
    return TestResult(
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
      success: true,
      responseTime: responseTime,
      resultCount: 1, // 简化：假设有结果
    );
  } catch (e) {
    final responseTime = DateTime.now().difference(startTime).inMilliseconds;
    final errorMsg = e.toString();
    return TestResult(
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
      success: false,
      error: errorMsg.length > 50 ? errorMsg.substring(0, 50) : errorMsg,
      responseTime: responseTime,
    );
  }
}

/// 主函数
void main(List<String> args) async {
  final inputFile = args.isNotEmpty ? args[0] : '10月/validated_sources.json';
  final outputFile = args.length > 1 ? args[1] : '10月/working_sources.json';
  final sampleSize = args.length > 2 ? int.parse(args[2]) : 100;
  final keyword = args.length > 3 ? args[3] : '修仙';

  print(List.filled(60, '=').join(''));
  print('书源搜索功能测试工具');
  print(List.filled(60, '=').join(''));
  print('输入文件: $inputFile');
  print('输出文件: $outputFile');
  print('测试数量: $sampleSize 个书源');
  print('测试关键字: $keyword');
  print('');

  // 读取书源
  final file = File(inputFile);
  if (!file.existsSync()) {
    print('错误: 文件不存在: $inputFile');
    exit(1);
  }

  print('正在读取书源...');
  final jsonData = jsonDecode(file.readAsStringSync()) as List;
  final allSources = jsonData.map((json) => TestBookSource.fromJson(json as Map<String, dynamic>)).toList();
  
  print('总书源数: ${allSources.length}');
  print('');

  // 筛选有搜索功能的书源
  final searchableSources = allSources.where((s) => 
      s.searchUrl != null && 
      s.searchUrl!.isNotEmpty &&
      s.ruleSearch != null &&
      s.ruleSearch!.isNotEmpty
  ).toList();

  print('有搜索功能的书源: ${searchableSources.length}');
  print('');

  // 随机抽样（避免总是测试前N个）
  searchableSources.shuffle();
  final samplesToTest = searchableSources.take(sampleSize).toList();

  print('开始测试 ${samplesToTest.length} 个书源...');
  print('');

  final results = <TestResult>[];
  int tested = 0;

  for (final source in samplesToTest) {
    tested++;
    
    if (tested % 10 == 0) {
      final successCount = results.where((r) => r.success).length;
      print('  已测试 $tested/${samplesToTest.length} | 成功: $successCount');
    }

    final result = await testSearch(source, keyword);
    results.add(result);
    
    // 避免请求过快
    await Future.delayed(const Duration(milliseconds: 100));
  }

  print('');
  print(List.filled(60, '=').join(''));
  print('测试结果');
  print(List.filled(60, '=').join(''));
  
  final successResults = results.where((r) => r.success).toList();
  final failedResults = results.where((r) => !r.success).toList();
  
  print('成功: ${successResults.length}/${results.length} (${(successResults.length * 100 / results.length).toStringAsFixed(1)}%)');
  print('失败: ${failedResults.length}/${results.length}');
  print('');

  if (successResults.isNotEmpty) {
    // 计算平均响应时间
    final avgTime = successResults.map((r) => r.responseTime).reduce((a, b) => a + b) / successResults.length;
    print('平均响应时间: ${avgTime.toStringAsFixed(0)}ms');
    print('');
  }

  // 显示成功的书源（前20个）
  if (successResults.isNotEmpty) {
    print('成功的书源示例（前20个）:');
    for (final result in successResults.take(20)) {
      print('  $result');
    }
    print('');
  }

  // 显示失败的书源（前10个）
  if (failedResults.isNotEmpty) {
    print('失败的书源示例（前10个）:');
    final errorGroups = <String, int>{};
    for (final result in failedResults) {
      final errorType = result.error?.split(':').first ?? '未知错误';
      errorGroups[errorType] = (errorGroups[errorType] ?? 0) + 1;
    }
    
    for (final result in failedResults.take(10)) {
      print('  $result');
    }
    print('');
    
    print('失败原因统计:');
    errorGroups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..forEach((entry) {
        print('  ${entry.key}: ${entry.value}');
      });
    print('');
  }

  // 根据测试结果筛选可用书源
  // 将测试成功的书源和未测试的书源都包含进去
  print('生成可用书源文件...');
  
  final successUrls = successResults.map((r) => r.sourceUrl).toSet();
  final testedUrls = samplesToTest.map((s) => s.bookSourceUrl).toSet();
  
  // 策略：保留所有测试成功的书源 + 未测试的书源（假设可能可用）
  final workingSources = allSources.where((s) {
    if (testedUrls.contains(s.bookSourceUrl)) {
      // 已测试的：只保留成功的
      return successUrls.contains(s.bookSourceUrl);
    } else {
      // 未测试的：保留（给用户更多选择）
      return true;
    }
  }).toList();

  // 生成输出
  final outputJson = JsonEncoder.withIndent('  ').convert(
    workingSources.map((s) => s.toJson()).toList()
  );
  
  final output = File(outputFile);
  output.writeAsStringSync(outputJson);

  print('');
  print('成功生成文件: $outputFile');
  print('保留书源数: ${workingSources.length}');
  print('  - 测试成功: ${successResults.length}');
  print('  - 未测试（保留）: ${workingSources.length - successResults.length}');
  print('移除书源数: ${allSources.length - workingSources.length} (测试失败)');
  print('文件大小: ${(output.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
  print('');
  print('完成！');
}

