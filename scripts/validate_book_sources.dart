#!/usr/bin/env dart
/// 书源校验和生成工具
/// 根据参考项目的校验规则校验书源，生成可用的书源文件

import 'dart:convert';
import 'dart:io';

/// 基础书源模型（简化版，用于解析）
class SimpleBookSource {
  final String bookSourceUrl;
  final String bookSourceName;
  final String? bookSourceGroup;
  final int bookSourceType;
  final bool enabled;
  final bool enabledExplore;
  final String? searchUrl;
  final Map<String, dynamic>? ruleSearch;
  final Map<String, dynamic>? ruleBookInfo;
  final Map<String, dynamic>? ruleToc;
  final Map<String, dynamic>? ruleContent;
  final Map<String, dynamic>? ruleExplore;
  final String? exploreUrl;
  final Map<String, dynamic>? rawData;

  SimpleBookSource({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    this.bookSourceType = 0,
    this.enabled = true,
    this.enabledExplore = true,
    this.searchUrl,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.ruleExplore,
    this.exploreUrl,
    this.rawData,
  });

  factory SimpleBookSource.fromJson(Map<String, dynamic> json) {
    // 处理 bookSourceType 可能是字符串或整数
    int bookSourceType = 0;
    if (json['bookSourceType'] != null) {
      if (json['bookSourceType'] is int) {
        bookSourceType = json['bookSourceType'];
      } else if (json['bookSourceType'] is String) {
        bookSourceType = int.tryParse(json['bookSourceType']) ?? 0;
      }
    }

    // 处理布尔值（可能是字符串）
    bool enabled = true;
    if (json['enabled'] != null) {
      if (json['enabled'] is bool) {
        enabled = json['enabled'];
      } else if (json['enabled'] is String) {
        enabled = json['enabled'].toString().toLowerCase() == 'true' ||
            json['enabled'].toString() == '1';
      }
    }

    bool enabledExplore = true;
    if (json['enabledExplore'] != null) {
      if (json['enabledExplore'] is bool) {
        enabledExplore = json['enabledExplore'];
      } else if (json['enabledExplore'] is String) {
        enabledExplore = json['enabledExplore'].toString().toLowerCase() == 'true' ||
            json['enabledExplore'].toString() == '1';
      }
    }

    return SimpleBookSource(
      bookSourceUrl: json['bookSourceUrl']?.toString() ?? '',
      bookSourceName: json['bookSourceName']?.toString() ?? '',
      bookSourceGroup: json['bookSourceGroup']?.toString(),
      bookSourceType: bookSourceType,
      enabled: enabled,
      enabledExplore: enabledExplore,
      searchUrl: json['searchUrl'],
      ruleSearch: json['ruleSearch'] is Map
          ? Map<String, dynamic>.from(json['ruleSearch'])
          : null,
      ruleBookInfo: json['ruleBookInfo'] is Map
          ? Map<String, dynamic>.from(json['ruleBookInfo'])
          : null,
      ruleToc: json['ruleToc'] is Map
          ? Map<String, dynamic>.from(json['ruleToc'])
          : null,
      ruleContent: json['ruleContent'] is Map
          ? Map<String, dynamic>.from(json['ruleContent'])
          : null,
      ruleExplore: json['ruleExplore'] is Map
          ? Map<String, dynamic>.from(json['ruleExplore'])
          : null,
      exploreUrl: json['exploreUrl'],
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => rawData ?? {};
}

/// 校验结果
class ValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.valid,
    this.errors = const [],
    this.warnings = const [],
  });

  String getSummary() {
    if (valid) {
      if (warnings.isNotEmpty) {
        return '✓ 通过 (警告: ${warnings.join(', ')})';
      }
      return '✓ 通过';
    }
    return '✗ 失败: ${errors.join(', ')}';
  }
}

/// 校验书源
/// 根据参考项目的校验规则
ValidationResult validateSource(SimpleBookSource source) {
  final errors = <String>[];
  final warnings = <String>[];

  // 1. 必需字段校验
  if (source.bookSourceUrl.isEmpty) {
    errors.add('缺少 bookSourceUrl');
  } else {
    // 验证 URL 格式
    if (!source.bookSourceUrl.startsWith('http://') &&
        !source.bookSourceUrl.startsWith('https://')) {
      errors.add('bookSourceUrl 格式错误（必须以 http:// 或 https:// 开头）');
    }
  }

  if (source.bookSourceName.isEmpty) {
    errors.add('缺少 bookSourceName');
  }

  // 2. 搜索功能校验（参考项目：必须至少有一项成功）
  // 检查是否有搜索URL和规则
  if (source.searchUrl == null || source.searchUrl!.isEmpty) {
    warnings.add('缺少搜索URL（searchUrl）');
  } else if (source.ruleSearch == null || source.ruleSearch!.isEmpty) {
    warnings.add('缺少搜索规则（ruleSearch）');
  } else {
    // 检查搜索规则是否有必需的字段
    final bookList = source.ruleSearch!['bookList'];
    final name = source.ruleSearch!['name'];
    if (bookList == null || bookList.toString().isEmpty) {
      warnings.add('搜索规则缺少 bookList');
    }
    if (name == null || name.toString().isEmpty) {
      warnings.add('搜索规则缺少 name');
    }
  }

  // 3. 详情功能校验
  if (source.ruleBookInfo == null || source.ruleBookInfo!.isEmpty) {
    warnings.add('缺少详情规则（ruleBookInfo）');
  } else {
    final name = source.ruleBookInfo!['name'];
    if (name == null || name.toString().isEmpty) {
      warnings.add('详情规则缺少 name');
    }
  }

  // 4. 目录功能校验
  if (source.ruleToc == null || source.ruleToc!.isEmpty) {
    warnings.add('缺少目录规则（ruleToc）');
  } else {
    final chapterList = source.ruleToc!['chapterList'];
    final name = source.ruleToc!['name'];
    if (chapterList == null || chapterList.toString().isEmpty) {
      warnings.add('目录规则缺少 chapterList');
    }
    if (name == null || name.toString().isEmpty) {
      warnings.add('目录规则缺少 name');
    }
  }

  // 5. 正文功能校验
  if (source.ruleContent == null || source.ruleContent!.isEmpty) {
    warnings.add('缺少正文规则（ruleContent）');
  } else {
    final content = source.ruleContent!['content'];
    if (content == null || content.toString().isEmpty) {
      warnings.add('正文规则缺少 content');
    }
  }

  // 6. 判断是否通过
  // 参考项目：至少有一项功能可用（搜索/发现/详情等）
  final hasSearch = source.searchUrl != null &&
      source.searchUrl!.isNotEmpty &&
      source.ruleSearch != null &&
      source.ruleSearch!.isNotEmpty;
  
  final hasInfo = source.ruleBookInfo != null && source.ruleBookInfo!.isNotEmpty;
  final hasToc = source.ruleToc != null && source.ruleToc!.isNotEmpty;
  final hasContent = source.ruleContent != null && source.ruleContent!.isNotEmpty;
  final hasExplore = source.exploreUrl != null &&
      source.exploreUrl!.isNotEmpty &&
      source.ruleExplore != null &&
      source.ruleExplore!.isNotEmpty;

  final hasAnyFunction = hasSearch || hasInfo || hasToc || hasContent || hasExplore;

  // 如果没有必需字段，直接失败
  if (errors.isNotEmpty) {
    return ValidationResult(valid: false, errors: errors, warnings: warnings);
  }

  // 如果没有任何可用功能，标记为警告但允许通过（可能是发现专用书源）
  if (!hasAnyFunction && warnings.isNotEmpty) {
    warnings.insert(0, '没有可用的功能（搜索/详情/目录/正文/发现）');
  }

  return ValidationResult(valid: true, errors: errors, warnings: warnings);
}

/// 读取并解析书源文件
List<SimpleBookSource> parseSourceFile(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('警告: 文件不存在: $filePath');
    return [];
  }

  try {
    final content = file.readAsStringSync();
    final jsonData = jsonDecode(content) as dynamic;

    final sources = <SimpleBookSource>[];

    if (jsonData is List) {
      // 数组格式
      for (final item in jsonData) {
        if (item is Map) {
          try {
            final source = SimpleBookSource.fromJson(
                Map<String, dynamic>.from(item));
            if (source.bookSourceUrl.isNotEmpty) {
              sources.add(source);
            }
          } catch (e) {
            print('警告: 解析书源失败: $e');
          }
        }
      }
    } else if (jsonData is Map) {
      // 单个书源对象
      try {
        final source = SimpleBookSource.fromJson(
            Map<String, dynamic>.from(jsonData));
        if (source.bookSourceUrl.isNotEmpty) {
          sources.add(source);
        }
      } catch (e) {
        print('警告: 解析书源失败: $e');
      }
    }

    return sources;
  } catch (e) {
    print('错误: 解析文件失败 $filePath: $e');
    return [];
  }
}

/// 主函数
void main(List<String> args) {
  // 输入目录
  final inputDir = args.isNotEmpty ? args[0] : '10月';
  final outputFile = args.length > 1 ? args[1] : '10月/validated_sources.json';

  print(List.filled(60, '=').join(''));
  print('书源校验工具');
  print(List.filled(60, '=').join(''));
  print('输入目录: $inputDir');
  print('输出文件: $outputFile');
  print('');

  final dir = Directory(inputDir);
  if (!dir.existsSync()) {
    print('错误: 目录不存在: $inputDir');
    exit(1);
  }

  // 读取所有文件
  final files = dir
      .listSync()
      .where((entity) =>
          entity is File &&
          (entity.path.endsWith('.json') ||
              entity.path.endsWith('.txt') ||
              entity.path.endsWith('.JSON') ||
              entity.path.endsWith('.TXT')))
      .map((entity) => (entity as File).path)
      .where((path) => !path.contains('validated_sources'))
      .toList();

  if (files.isEmpty) {
    print('错误: 未找到任何书源文件');
    exit(1);
  }

  print('找到 ${files.length} 个文件:');
  for (final file in files) {
    print('  - ${Uri.file(file).pathSegments.last}');
  }
  print('');

  // 解析所有书源
  final allSources = <SimpleBookSource>[];
  final sourceCounts = <String, int>{};

  for (final file in files) {
    print('解析: ${Uri.file(file).pathSegments.last}...');
    final sources = parseSourceFile(file);
    allSources.addAll(sources);
    sourceCounts[Uri.file(file).pathSegments.last] = sources.length;
    print('  找到 ${sources.length} 个书源');
  }

  print('');
  print('总共解析 ${allSources.length} 个书源');
  print('');

  // 去重（基于 bookSourceUrl）
  final uniqueSources = <String, SimpleBookSource>{};
  int duplicateCount = 0;

  for (final source in allSources) {
    if (uniqueSources.containsKey(source.bookSourceUrl)) {
      duplicateCount++;
      // 保留名称更长的（通常更完整）
      final existing = uniqueSources[source.bookSourceUrl]!;
      if (source.bookSourceName.length > existing.bookSourceName.length) {
        uniqueSources[source.bookSourceUrl] = source;
      }
    } else {
      uniqueSources[source.bookSourceUrl] = source;
    }
  }

  print('去重后: ${uniqueSources.length} 个唯一书源 (重复: $duplicateCount)');
  print('');

  // 校验书源
  print('开始校验...');
  print('');

  final validSources = <SimpleBookSource>[];
  final invalidSources = <SimpleBookSource>[];
  int processed = 0;

  for (final source in uniqueSources.values) {
    processed++;
    if (processed % 100 == 0) {
      print('  已处理 $processed/${uniqueSources.length}...');
    }

    final result = validateSource(source);

    if (result.valid) {
      validSources.add(source);
    } else {
      invalidSources.add(source);
    }
  }

  print('');
  print(List.filled(60, '=').join(''));
  print('校验结果');
  print(List.filled(60, '=').join(''));
  print('有效书源: ${validSources.length}');
  print('无效书源: ${invalidSources.length}');
  print('');

  // 生成输出文件
  if (validSources.isEmpty) {
    print('警告: 没有有效的书源，不生成输出文件');
    exit(0);
  }

  // 转换为JSON格式
  final jsonList = validSources.map((s) => s.toJson()).toList();
  final jsonString = JsonEncoder.withIndent('  ').convert(jsonList);

  // 写入文件
  final output = File(outputFile);
  output.writeAsStringSync(jsonString);

  print('成功生成输出文件: $outputFile');
  print('文件大小: ${(output.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
  print('');

  // 如果有无效书源，显示一些示例
  if (invalidSources.isNotEmpty && invalidSources.length <= 10) {
    print('无效书源示例（前10个）:');
    for (final source in invalidSources.take(10)) {
      final result = validateSource(source);
      print('  - ${source.bookSourceName} (${source.bookSourceUrl})');
      print('    ${result.getSummary()}');
    }
  }

  print('');
  print('完成！');
}
