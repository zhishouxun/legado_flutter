import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'rule_parser.dart';
import '../../data/models/book_source.dart';
import '../../data/models/book_source_rule.dart';
import '../app_log.dart';

/// Legado规则解析器 (参考Gemini文档: 书源解析器原型.md)
///
/// 这是一个高层封装,简化RuleParser的使用,完全兼容Legado规则
///
/// **核心特性**:
/// 1. 支持CSS选择器、XPath、JSONPath、JavaScript规则
/// 2. 支持Legado特有的"##"格式正则替换
/// 3. 支持嵌套规则递归解析
/// 4. 支持异步处理(compute函数后台执行)
/// 5. 完全兼容BookSource模型
///
/// **使用示例**:
/// ```dart
/// final parser = LegadoParser();
///
/// // 解析搜索列表
/// final books = await parser.parseSearchList(
///   htmlContent: response.data,
///   bookSource: source,
///   baseUrl: searchUrl,
/// );
///
/// // 解析书籍详情
/// final bookInfo = await parser.parseBookInfo(
///   htmlContent: response.data,
///   bookSource: source,
///   baseUrl: bookUrl,
/// );
/// ```
class LegadoParser {
  /// 解析搜索结果列表
  ///
  /// [htmlContent] HTML内容或JSON字符串
  /// [bookSource] 书源
  /// [baseUrl] 基础URL(用于相对路径转换)
  /// [variables] 自定义变量
  ///
  /// Returns: 解析后的书籍列表(Map格式)
  Future<List<Map<String, dynamic>>> parseSearchList({
    required String htmlContent,
    required BookSource bookSource,
    String? baseUrl,
    Map<String, String>? variables,
  }) async {
    if (bookSource.ruleSearch == null) {
      AppLog.instance.put('LegadoParser: 书源没有搜索规则');
      return [];
    }

    final rule = bookSource.ruleSearch!;

    return await _parseList(
      content: htmlContent,
      listRule: rule.bookList,
      fieldRules: {
        'name': rule.name,
        'author': rule.author,
        'kind': rule.kind,
        'wordCount': rule.wordCount,
        'lastChapter': rule.lastChapter,
        'intro': rule.intro,
        'coverUrl': rule.coverUrl,
        'bookUrl': rule.bookUrl,
      },
      baseUrl: baseUrl,
      variables: variables,
    );
  }

  /// 解析发现(探索)列表
  ///
  /// [htmlContent] HTML内容或JSON字符串
  /// [bookSource] 书源
  /// [baseUrl] 基础URL
  /// [variables] 自定义变量
  ///
  /// Returns: 解析后的书籍列表
  Future<List<Map<String, dynamic>>> parseExploreList({
    required String htmlContent,
    required BookSource bookSource,
    String? baseUrl,
    Map<String, String>? variables,
  }) async {
    if (bookSource.ruleExplore == null) {
      AppLog.instance.put('LegadoParser: 书源没有发现规则');
      return [];
    }

    final rule = bookSource.ruleExplore!;

    return await _parseList(
      content: htmlContent,
      listRule: rule.bookList,
      fieldRules: {
        'name': rule.name,
        'author': rule.author,
        'kind': rule.kind,
        'wordCount': rule.wordCount,
        'lastChapter': rule.lastChapter,
        'intro': rule.intro,
        'coverUrl': rule.coverUrl,
        'bookUrl': rule.bookUrl,
      },
      baseUrl: baseUrl,
      variables: variables,
    );
  }

  /// 解析书籍详情
  ///
  /// [htmlContent] HTML内容
  /// [bookSource] 书源
  /// [baseUrl] 基础URL
  /// [variables] 自定义变量
  ///
  /// Returns: 书籍详情Map
  Future<Map<String, dynamic>> parseBookInfo({
    required String htmlContent,
    required BookSource bookSource,
    String? baseUrl,
    Map<String, String>? variables,
  }) async {
    if (bookSource.ruleBookInfo == null) {
      AppLog.instance.put('LegadoParser: 书源没有详情规则');
      return {};
    }

    final rule = bookSource.ruleBookInfo!;

    // 处理init规则(初始化JS代码)
    String content = htmlContent;
    if (rule.init != null && rule.init!.isNotEmpty) {
      try {
        final initResult = await RuleParser.parseRuleAsync(
          content,
          rule.init,
          baseUrl: baseUrl,
          variables: variables,
        );
        if (initResult != null) {
          content = initResult;
        }
      } catch (e) {
        AppLog.instance.put('LegadoParser: init规则执行失败', error: e);
      }
    }

    return await _parseFields(
      content: content,
      fieldRules: {
        'name': rule.name,
        'author': rule.author,
        'kind': rule.kind,
        'wordCount': rule.wordCount,
        'lastChapter': rule.lastChapter,
        'intro': rule.intro,
        'coverUrl': rule.coverUrl,
        'tocUrl': rule.tocUrl,
        'canReName': rule.canReName,
      },
      baseUrl: baseUrl,
      variables: variables,
    );
  }

  /// 解析目录列表
  ///
  /// [htmlContent] HTML内容或JSON字符串
  /// [bookSource] 书源
  /// [baseUrl] 基础URL
  /// [variables] 自定义变量
  ///
  /// Returns: 章节列表
  Future<List<Map<String, dynamic>>> parseTocList({
    required String htmlContent,
    required BookSource bookSource,
    String? baseUrl,
    Map<String, String>? variables,
  }) async {
    if (bookSource.ruleToc == null) {
      AppLog.instance.put('LegadoParser: 书源没有目录规则');
      return [];
    }

    final rule = bookSource.ruleToc!;

    // 处理preUpdateJs(目录解析前执行的JS)
    String content = htmlContent;
    if (rule.preUpdateJs != null && rule.preUpdateJs!.isNotEmpty) {
      try {
        final preResult = await RuleParser.parseRuleAsync(
          content,
          rule.preUpdateJs,
          baseUrl: baseUrl,
          variables: variables,
        );
        if (preResult != null) {
          content = preResult;
        }
      } catch (e) {
        AppLog.instance.put('LegadoParser: preUpdateJs执行失败', error: e);
      }
    }

    final chapters = await _parseList(
      content: content,
      listRule: rule.chapterList,
      fieldRules: {
        'chapterName': rule.chapterName,
        'chapterUrl': rule.chapterUrl,
        'isVip': rule.isVip,
        'isVolume': rule.isVolume,
        'updateTime': rule.updateTime,
      },
      baseUrl: baseUrl,
      variables: variables,
    );

    // 处理formatJs(格式化章节标题)
    if (rule.formatJs != null && rule.formatJs!.isNotEmpty) {
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        if (chapter['chapterName'] != null) {
          try {
            // 将章节信息注入到JS环境中
            final jsVariables = <String, String>{
              ...?variables,
              'chapterName': chapter['chapterName'].toString(),
              'chapterIndex': i.toString(),
            };

            final formatted = await RuleParser.parseRuleAsync(
              chapter['chapterName'].toString(),
              rule.formatJs,
              baseUrl: baseUrl,
              variables: jsVariables,
            );

            if (formatted != null) {
              chapter['chapterName'] = formatted;
            }
          } catch (e) {
            AppLog.instance.put('LegadoParser: formatJs执行失败', error: e);
          }
        }
      }
    }

    return chapters;
  }

  /// 解析正文内容
  ///
  /// [htmlContent] HTML内容
  /// [bookSource] 书源
  /// [baseUrl] 基础URL
  /// [variables] 自定义变量
  ///
  /// Returns: 正文内容和下一页URL
  Future<Map<String, dynamic>> parseContent({
    required String htmlContent,
    required BookSource bookSource,
    String? baseUrl,
    Map<String, String>? variables,
  }) async {
    if (bookSource.ruleContent == null) {
      AppLog.instance.put('LegadoParser: 书源没有正文规则');
      return {'content': null, 'nextContentUrl': null};
    }

    final rule = bookSource.ruleContent!;

    // 处理webJs(网页加载前执行的JS)
    String content = htmlContent;
    if (rule.webJs != null && rule.webJs!.isNotEmpty) {
      try {
        final webResult = await RuleParser.parseRuleAsync(
          content,
          rule.webJs,
          baseUrl: baseUrl,
          variables: variables,
        );
        if (webResult != null) {
          content = webResult;
        }
      } catch (e) {
        AppLog.instance.put('LegadoParser: webJs执行失败', error: e);
      }
    }

    final result = <String, dynamic>{};

    // 解析正文
    if (rule.content != null && rule.content!.isNotEmpty) {
      final contentText = await RuleParser.parseRuleAsync(
        content,
        rule.content,
        baseUrl: baseUrl,
        variables: variables,
      );
      result['content'] = contentText;

      // 处理sourceRegex(净化规则)
      if (contentText != null &&
          rule.sourceRegex != null &&
          rule.sourceRegex!.isNotEmpty) {
        result['content'] = _applyRegexReplace(
          contentText,
          rule.sourceRegex!,
        );
      }

      // 处理replaceRegex(替换规则)
      if (result['content'] != null &&
          rule.replaceRegex != null &&
          rule.replaceRegex!.isNotEmpty) {
        result['content'] = _applyRegexReplace(
          result['content']!,
          rule.replaceRegex!,
        );
      }
    }

    // 解析下一页URL
    if (rule.nextContentUrl != null && rule.nextContentUrl!.isNotEmpty) {
      result['nextContentUrl'] = await RuleParser.parseRuleAsync(
        content,
        rule.nextContentUrl,
        baseUrl: baseUrl,
        variables: variables,
        isUrl: true,
      );
    }

    return result;
  }

  /// 解析列表(通用方法)
  ///
  /// [content] HTML内容或JSON字符串
  /// [listRule] 列表规则(如 class.item_oc)
  /// [fieldRules] 字段规则Map
  /// [baseUrl] 基础URL
  /// [variables] 自定义变量
  ///
  /// Returns: 解析后的列表
  Future<List<Map<String, dynamic>>> _parseList({
    required String content,
    required String? listRule,
    required Map<String, String?> fieldRules,
    String? baseUrl,
    Map<String, String>? variables,
  }) async {
    if (listRule == null || listRule.isEmpty) {
      AppLog.instance.put('LegadoParser: 列表规则为空');
      return [];
    }

    try {
      // 使用RuleParser的parseListRule获取元素列表HTML
      final elementHtmlList = RuleParser.parseListRule(
        content,
        listRule,
        baseUrl: baseUrl,
        variables: variables,
        returnHtml: true, // 返回元素HTML而非文本
      );

      if (elementHtmlList.isEmpty) {
        AppLog.instance.put('LegadoParser: 未匹配到列表元素');
        return [];
      }

      AppLog.instance.put('LegadoParser: 匹配到${elementHtmlList.length}个元素');

      // 解析每个元素的字段
      final results = <Map<String, dynamic>>[];
      for (final elementHtml in elementHtmlList) {
        final fields = await _parseFields(
          content: elementHtml,
          fieldRules: fieldRules,
          baseUrl: baseUrl,
          variables: variables,
        );

        if (fields.isNotEmpty) {
          results.add(fields);
        }
      }

      return results;
    } catch (e, stackTrace) {
      AppLog.instance.put('LegadoParser: 解析列表失败', error: e);
      AppLog.instance.put('LegadoParser: 错误堆栈: $stackTrace');
      return [];
    }
  }

  /// 解析字段(通用方法)
  ///
  /// [content] HTML内容
  /// [fieldRules] 字段规则Map
  /// [baseUrl] 基础URL
  /// [variables] 自定义变量
  ///
  /// Returns: 解析后的字段Map
  Future<Map<String, dynamic>> _parseFields({
    required String content,
    required Map<String, String?> fieldRules,
    String? baseUrl,
    Map<String, String>? variables,
  }) async {
    final result = <String, dynamic>{};

    for (final entry in fieldRules.entries) {
      final fieldName = entry.key;
      final rule = entry.value;

      if (rule == null || rule.isEmpty) continue;

      try {
        // 判断是否是URL字段
        final isUrl = fieldName.toLowerCase().contains('url');

        // 使用异步解析(支持JavaScript)
        final value = await RuleParser.parseRuleAsync(
          content,
          rule,
          baseUrl: baseUrl,
          variables: variables,
          isUrl: isUrl,
        );

        if (value != null && value.isNotEmpty) {
          result[fieldName] = value;
        }
      } catch (e) {
        AppLog.instance.put('LegadoParser: 解析字段"$fieldName"失败', error: e);
      }
    }

    return result;
  }

  /// 应用正则替换 (支持Legado的##格式)
  ///
  /// 格式: ##match##replace 或 ##match##replace##
  ///
  /// [text] 原始文本
  /// [regexRule] 正则规则
  ///
  /// Returns: 替换后的文本
  String _applyRegexReplace(String text, String regexRule) {
    if (!regexRule.startsWith('##')) {
      return text;
    }

    try {
      // 分割规则: ##match##replace 或 ##match##replace##
      final parts = regexRule.split('##');
      if (parts.length < 3) {
        AppLog.instance.put('LegadoParser: 正则规则格式错误: $regexRule');
        return text;
      }

      final pattern = parts[1];
      final replacement = parts.length > 2 ? parts[2] : '';

      if (pattern.isEmpty) {
        return text;
      }

      // 执行正则替换
      final regex = RegExp(pattern);
      return text.replaceAll(regex, replacement);
    } catch (e) {
      AppLog.instance.put('LegadoParser: 正则替换失败', error: e);
      return text;
    }
  }

  /// 在后台线程执行解析(使用compute函数)
  ///
  /// 适用于大量数据或复杂规则的解析,避免阻塞UI
  ///
  /// [parseFunction] 解析函数
  /// [params] 参数
  ///
  /// Returns: 解析结果
  static Future<T> computeParse<T, P>({
    required Future<T> Function(P params) parseFunction,
    required P params,
  }) async {
    return await compute(
        _computeWrapper<T, P>,
        _ComputeParams(
          function: parseFunction,
          params: params,
        ));
  }

  /// compute函数的包装器
  static Future<T> _computeWrapper<T, P>(
      _ComputeParams<T, P> computeParams) async {
    return await computeParams.function(computeParams.params);
  }
}

/// compute函数参数
class _ComputeParams<T, P> {
  final Future<T> Function(P params) function;
  final P params;

  _ComputeParams({
    required this.function,
    required this.params,
  });
}
