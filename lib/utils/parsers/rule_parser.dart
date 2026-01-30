import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:json_path/json_path.dart';
import 'html_parser.dart';
import '../../data/models/book_source_rule.dart';
import '../../data/models/replace_rule.dart';
import '../../data/models/book_source.dart';
import '../../data/models/book.dart';
import '../../services/network/network_service.dart';
import '../../services/replace_rule_service.dart';
import '../app_log.dart';
import 'rule_analyzer.dart';
import '../js_engine.dart';
import '../js_extensions.dart';
import 'elements_single.dart';
import 'analyze_by_regex.dart';

/// 规则片段类型
enum _RuleFragmentType {
  normal, // 普通规则（CSS/XPath/JSONPath）
  javascript, // JavaScript 代码
}

/// 规则片段
class _RuleFragment {
  final _RuleFragmentType type;
  final String content;

  _RuleFragment({
    required this.type,
    required this.content,
  });
}

/// 规则解析器
/// 参考项目：io.legado.app.model.analyzeRule.AnalyzeRule
///
/// 主要差异说明：
/// 1. JavaScript 引擎：参考项目使用 Rhino（Java），当前项目使用 flutter_js（QuickJS）
///    - 参考项目可以直接调用 Java 类和方法，当前项目需要通过桥接函数
///    - 部分同步函数在参考项目中是同步的，但当前项目实现为异步（返回 Promise）
///
/// 2. HTML 解析库：参考项目使用 JSoup（Java），当前项目使用 html + xpath_selector（Dart）
///    - CSS 选择器功能基本一致，但某些高级特性可能不同
///    - XPath 实现基于 xpath_selector，与 JXPath 的行为可能略有差异
///
/// 3. 卷名处理：已完善，支持 isVolume 规则解析
///
/// 4. URL 处理：使用 NetworkService.joinUrl，逻辑与参考项目基本一致
///
/// 5. 规则组合：支持 &&、||、%% 组合，实现逻辑与参考项目一致
class RuleParser {
  // 变量存储（用于@get:和@put:）
  static final Map<String, String> _variables = {};

  /// 处理规则（变量替换、put规则、正则替换等）
  /// 参考项目：AnalyzeRule.splitSourceRule 和 SourceRule.makeUpRule
  static String _processRule(String rule, Map<String, String> variables) {
    String result = rule;

    // 1. 处理 @put:{key:value} 规则
    final putPattern = RegExp(r'@put:\s*(\{[^}]+\})', caseSensitive: false);
    result = result.replaceAllMapped(putPattern, (match) {
      try {
        // 解析JSON对象
        final jsonStr = match.group(1)!;
        // 简单的JSON解析（只支持简单的key:value格式）
        final keyValuePattern = RegExp(r'"([^"]+)":\s*"([^"]*)"');
        keyValuePattern.allMatches(jsonStr).forEach((m) {
          final key = m.group(1)!;
          final value = m.group(2) ?? '';
          _variables[key] = value;
          variables[key] = value;
        });
      } catch (e) {
        AppLog.instance.put('_processRule: 解析@put规则失败: $e');
      }
      return ''; // 移除@put规则
    });

    // 2. 处理变量替换 {{key}} 和 @{{key}}
    variables.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
      result = result.replaceAll('@{{$key}}', value);
    });

    // 3. 处理 @get:{key} 规则
    final getPattern = RegExp(r'@get:\s*\{([^}]+)\}', caseSensitive: false);
    result = result.replaceAllMapped(getPattern, (match) {
      final key = match.group(1)!.trim();
      return variables[key] ?? _variables[key] ?? '';
    });

    // 4. 处理 {{js}} JavaScript代码
    // 注意：{{js}} 的处理在 SourceRule.makeUpRule 中实现

    // 5. 处理正则替换 ##match##replace 或 ##match##replace###
    // 这部分在解析后处理，这里只提取规则部分

    return result;
  }

  /// 处理变量替换（向后兼容）
  static String _replaceVariables(String rule, Map<String, String>? variables) {
    if (variables == null || variables.isEmpty) return rule;

    String result = rule;
    variables.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
      result = result.replaceAll('@{{$key}}', value);
    });
    return result;
  }

  /// 解析规则并提取内容（同步版本，不支持JavaScript执行）
  /// [isUrl] 如果为true，表示解析的是URL，需要特殊处理（参考 AnalyzeRule.getString with isUrl=true）
  /// 支持规则组合（&&/||）和变量替换
  /// 注意：如果规则包含{{js}}代码，请使用parseRuleAsync
  static String? parseRule(
    String html,
    String? rule, {
    String? baseUrl,
    Map<String, String>? variables,
    bool isUrl = false,
  }) {
    if (rule == null || rule.isEmpty) {
      // 如果是URL且为空，返回baseUrl（参考项目逻辑）
      if (isUrl && baseUrl != null) {
        return baseUrl;
      }
      return null;
    }

    // 检查是否包含JavaScript代码
    if (rule.contains('{{') && rule.contains('}}')) {
      AppLog.instance.put('parseRule: 警告 - 规则包含{{js}}代码，请使用parseRuleAsync');
      // 同步版本不支持JS执行，跳过JS部分
    }

    try {
      // 合并外部变量和内部变量
      final allVariables = <String, String>{..._variables};
      if (variables != null) {
        allVariables.addAll(variables);
      }

      // 处理变量替换和put规则
      String processedRule = _processRule(rule, allVariables);
      AppLog.instance.put('parseRule: 规则="$rule", 处理后="$processedRule"');

      // 判断是否包含规则组合（&&/||）
      final analyzer = RuleAnalyzer(processedRule);
      final splitRules = analyzer.splitRule(['&&', '||', '%%']);
      final elementsType = analyzer.elementsType;

      if (splitRules.length > 1) {
        // 有规则组合，需要分别解析每个规则
        AppLog.instance.put(
            'parseRule: 检测到规则组合，类型=$elementsType, 规则数=${splitRules.length}');
        return _parseRuleCombinationSync(
            html, splitRules, elementsType, baseUrl, allVariables,
            isUrl: isUrl);
      } else {
        // 单个规则，直接解析
        return _parseSingleRuleSync(html, processedRule, baseUrl, allVariables,
            isUrl: isUrl);
      }
    } catch (e, stackTrace) {
      AppLog.instance.put('parseRule: 解析失败', error: e);
      AppLog.instance.put('parseRule: 错误堆栈: $stackTrace');
      // 如果是URL且解析失败，返回baseUrl
      if (isUrl && baseUrl != null) {
        return baseUrl;
      }
      return null;
    }
  }

  /// 解析规则并提取内容（异步版本，支持JavaScript执行）
  /// [isUrl] 如果为true，表示解析的是URL，需要特殊处理（参考 AnalyzeRule.getString with isUrl=true）
  /// 支持规则组合（&&/||）、变量替换和JavaScript执行
  static Future<String?> parseRuleAsync(
    String html,
    String? rule, {
    String? baseUrl,
    Map<String, String>? variables,
    bool isUrl = false,
  }) async {
    return _parseRuleAsync(html, rule,
        baseUrl: baseUrl, variables: variables, isUrl: isUrl);
  }

  /// 异步解析规则（内部方法，支持JavaScript执行）
  static Future<String?> _parseRuleAsync(
    String html,
    String? rule, {
    String? baseUrl,
    Map<String, String>? variables,
    bool isUrl = false,
  }) async {
    if (rule == null || rule.isEmpty) {
      // 如果是URL且为空，返回baseUrl（参考项目逻辑）
      if (isUrl && baseUrl != null) {
        return baseUrl;
      }
      return null;
    }

    try {
      // 合并外部变量和内部变量
      final allVariables = <String, String>{..._variables};
      if (variables != null) {
        allVariables.addAll(variables);
      }

      // 处理变量替换和put规则
      String processedRule = _processRule(rule, allVariables);
      AppLog.instance.put('_parseRuleAsync: 规则="$rule", 处理后="$processedRule"');

      // 判断是否包含规则组合（&&/||）
      final analyzer = RuleAnalyzer(processedRule);
      final splitRules = analyzer.splitRule(['&&', '||', '%%']);
      final elementsType = analyzer.elementsType;

      if (splitRules.length > 1) {
        // 有规则组合，需要分别解析每个规则
        AppLog.instance.put(
            '_parseRuleAsync: 检测到规则组合，类型=$elementsType, 规则数=${splitRules.length}');
        return await _parseRuleCombination(
            html, splitRules, elementsType, baseUrl, allVariables,
            isUrl: isUrl);
      } else {
        // 单个规则，直接解析
        return await _parseSingleRule(
            html, processedRule, baseUrl, allVariables,
            isUrl: isUrl);
      }
    } catch (e, stackTrace) {
      AppLog.instance.put('_parseRuleAsync: 解析失败', error: e);
      AppLog.instance.put('_parseRuleAsync: 错误堆栈: $stackTrace');
      // 如果是URL且解析失败，返回baseUrl
      if (isUrl && baseUrl != null) {
        return baseUrl;
      }
      return null;
    }
  }

  /// 解析单个规则（同步版本，不包含组合，不支持JavaScript执行）
  static String? _parseSingleRuleSync(
    String html,
    String rule,
    String? baseUrl,
    Map<String, String> variables, {
    bool isUrl = false,
  }) {
    // 检查是否包含正则替换规则
    String? replaceRule;
    String actualRule = rule;

    if (rule.contains('##')) {
      final parts = rule.split('##');
      if (parts.length >= 3) {
        // 提取实际规则和替换规则
        actualRule = parts[0];
        replaceRule = rule.substring(parts[0].length); // 保留 ##match##replace 部分
      }
    }

    String? result;

    // 判断是 XPath 还是 CSS 选择器
    // 参考项目：SourceRule 构造函数中的模式识别逻辑
    String processedRule = actualRule;

    // 处理 Regex 模式（以 : 开头，但注意与伪类选择器冲突）
    // 参考项目：if (allInOne && ruleStr.startsWith(":")) { mMode = Mode.Regex }
    if (actualRule.startsWith(':') && actualRule.length > 1) {
      final afterColon = actualRule.substring(1).trim();
      final isPseudoClass = RegExp(r'^[a-zA-Z-]').hasMatch(afterColon);

      if (!isPseudoClass) {
        // Regex 模式：移除开头的 :，然后按 && 分割正则表达式
        processedRule = afterColon;
        final regexList = processedRule
            .split('&&')
            .map((r) => r.trim())
            .where((r) => r.isNotEmpty)
            .toList();
        if (regexList.isNotEmpty) {
          final regexResult = AnalyzeByRegex.getElement(html, regexList);
          if (regexResult != null && regexResult.isNotEmpty) {
            // 返回第一个分组（$0），如果有多个分组，用换行符连接
            result = regexResult.join('\n');
          }
        }
      } else {
        // 伪类选择器，按CSS处理
        result = _parseCss(html, actualRule, baseUrl, isUrl: isUrl);
      }
    }
    // 处理 @CSS: 前缀（强制使用CSS选择器）
    else if (actualRule.startsWith('@CSS:') || actualRule.startsWith('@css:')) {
      processedRule = actualRule.substring(5).trim();
      // 强制使用CSS选择器，即使规则看起来像XPath或JSONPath
      result = _parseCss(html, processedRule, baseUrl, isUrl: isUrl);
    }
    // 处理 @@ 前缀（转义，使用Default模式）
    else if (actualRule.startsWith('@@')) {
      processedRule = actualRule.substring(2);
      // 强制使用CSS选择器（Default模式）
      result = _parseCss(html, processedRule, baseUrl, isUrl: isUrl);
    }
    // 处理 @XPath: 前缀
    else if (actualRule.startsWith('@XPath:') ||
        actualRule.startsWith('@xpath:')) {
      processedRule = actualRule.substring(7).trim();
      result = _parseXPath(html, processedRule, baseUrl, isUrl: isUrl);
    }
    // 处理 @Json: 前缀
    else if (actualRule.startsWith('@Json:') ||
        actualRule.startsWith('@json:')) {
      processedRule = actualRule.substring(6).trim();
      result = _parseJsonPath(html, processedRule, baseUrl, isUrl: isUrl);
    }
    // 判断规则类型
    else if (processedRule.startsWith('//') || processedRule.startsWith('/')) {
      // XPath模式
      result = _parseXPath(html, processedRule, baseUrl, isUrl: isUrl);
    } else if (processedRule.startsWith('\$.') ||
        processedRule.startsWith('\$[')) {
      // JSONPath模式
      result = _parseJsonPath(html, processedRule, baseUrl, isUrl: isUrl);
    } else {
      // CSS选择器模式（默认）
      result = _parseCss(html, processedRule, baseUrl, isUrl: isUrl);
    }

    // 如果结果为空且是URL，返回baseUrl
    if (isUrl && (result == null || result.isEmpty) && baseUrl != null) {
      result = baseUrl;
    }

    // 应用正则替换规则
    if (result != null && replaceRule != null && replaceRule.isNotEmpty) {
      result = _applyReplaceRegexInternal(result, replaceRule);
    }

    AppLog.instance.put('_parseSingleRuleSync: 解析结果长度=${result?.length ?? 0}');
    return result;
  }

  /// 解析单个规则（异步版本，不包含组合，支持JavaScript执行）
  /// 参考项目：AnalyzeRule.getString
  /// 支持正则替换：##match##replace 或 ##match##replace###
  /// 支持JavaScript执行：{{js代码}} 或 <js>代码</js> 或 @js:代码
  /// 关键：按 {{js}} 分割规则，顺序执行每个片段，每个片段的结果作为下一个片段的输入
  static Future<String?> _parseSingleRule(
    String html,
    String rule,
    String? baseUrl,
    Map<String, String> variables, {
    bool isUrl = false,
  }) async {
    // 分离正则替换规则（##match##replace）
    String? replaceRule;
    String actualRule = rule;

    if (rule.contains('##')) {
      final parts = rule.split('##');
      if (parts.length >= 3) {
        actualRule = parts[0];
        replaceRule = rule.substring(parts[0].length); // 保留 ##match##replace 部分
      }
    }

    // 检查是否包含明确的 JavaScript 标记（<js>...</js> 或 @js:...）
    // 注意：{{...}} 格式需要更谨慎处理，因为变量替换也使用这个格式
    // 只有在规则中明确包含 <js> 或 @js: 时才进行分割处理
    final hasExplicitJs = actualRule.contains('<js>') ||
        actualRule.contains('</js>') ||
        actualRule.toLowerCase().contains('@js:');

    // 如果没有明确的 JavaScript 标记，直接按普通规则处理
    if (!hasExplicitJs) {
      // 检查是否包含 {{...}} 格式（可能是变量替换或 JavaScript）
      // 如果包含 {{...}}，先尝试作为变量替换处理，如果变量不存在，再作为 JavaScript
      if (actualRule.contains('{{') && actualRule.contains('}}')) {
        // 先尝试变量替换
        String processedRule = actualRule;
        bool hasJsCode = false;

        // 检查 {{...}} 是否是变量替换
        final varPattern = RegExp(r'\{\{([^}]+)\}\}');
        for (final match in varPattern.allMatches(actualRule)) {
          final key = match.group(1)?.trim();
          if (key != null && variables.containsKey(key)) {
            // 是变量替换
            processedRule =
                processedRule.replaceAll(match.group(0)!, variables[key]!);
          } else {
            // 不是变量替换，可能是 JavaScript 代码
            hasJsCode = true;
            break;
          }
        }

        if (!hasJsCode) {
          // 所有 {{...}} 都是变量替换，使用处理后的规则
          actualRule = processedRule;
        }
        // 如果有 JavaScript 代码，继续下面的分割处理
      } else {
        // 没有 {{...}}，直接按普通规则处理
        return _parseSingleRuleSync(html, actualRule, baseUrl, variables,
            isUrl: isUrl);
      }
    }

    // 有明确的 JavaScript 标记或包含 {{...}} 且不是变量替换，进行分割处理
    // 匹配 <js>...</js> 或 @js:... 或 {{...}}（但排除变量替换）
    final jsPattern = RegExp(
      r'<js>([\w\W]*?)</js>|@js:([\w\W]*?)(?=\s|$)|(?<!\\)\{\{([\w\W]*?)\}\}',
      caseSensitive: false,
    );

    // 分割规则片段
    final ruleFragments = <_RuleFragment>[];
    int lastEnd = 0;

    for (final match in jsPattern.allMatches(actualRule)) {
      // 添加 JavaScript 之前的普通规则片段
      if (match.start > lastEnd) {
        final normalRule = actualRule.substring(lastEnd, match.start).trim();
        if (normalRule.isNotEmpty) {
          ruleFragments.add(_RuleFragment(
            type: _RuleFragmentType.normal,
            content: normalRule,
          ));
        }
      }

      // 提取 JavaScript 代码
      String? jsCode;
      if (match.group(1) != null) {
        // <js>...</js> 格式
        jsCode = match.group(1);
      } else if (match.group(2) != null) {
        // @js:... 格式
        jsCode = match.group(2);
      } else if (match.group(3) != null) {
        // {{...}} 格式，检查是否是变量替换
        final key = match.group(3)?.trim();
        if (key != null && variables.containsKey(key)) {
          // 是变量替换，作为普通文本处理
          ruleFragments.add(_RuleFragment(
            type: _RuleFragmentType.normal,
            content: variables[key]!,
          ));
          lastEnd = match.end;
          continue;
        } else {
          // 不是变量替换，作为 JavaScript 代码
          jsCode = match.group(3);
        }
      }

      if (jsCode != null && jsCode.isNotEmpty) {
        ruleFragments.add(_RuleFragment(
          type: _RuleFragmentType.javascript,
          content: jsCode,
        ));
      }

      lastEnd = match.end;
    }

    // 添加最后一个普通规则片段
    if (lastEnd < actualRule.length) {
      final normalRule = actualRule.substring(lastEnd).trim();
      if (normalRule.isNotEmpty) {
        ruleFragments.add(_RuleFragment(
          type: _RuleFragmentType.normal,
          content: normalRule,
        ));
      }
    }

    // 如果没有找到任何片段，整个规则作为普通规则
    if (ruleFragments.isEmpty) {
      return _parseSingleRuleSync(html, actualRule, baseUrl, variables,
          isUrl: isUrl);
    }

    // 参考项目：顺序执行每个规则片段，每个片段的结果作为下一个片段的输入
    dynamic result = html;

    // 检查整个规则是否包含JavaScript代码（用于决定是否在CSS解析时自动拼接URL）
    final hasJsInRule =
        ruleFragments.any((f) => f.type == _RuleFragmentType.javascript);

    if (ruleFragments.isNotEmpty) {
      for (int i = 0; i < ruleFragments.length; i++) {
        final frag = ruleFragments[i];
      }
    }

    for (final fragment in ruleFragments) {
      if (result == null) break;

      try {
        if (fragment.type == _RuleFragmentType.javascript) {
          // 执行 JavaScript 代码
          // 参考项目：evalJS(jsCode, result)
          final jsResult = await _executeJs(
            result.toString(),
            fragment.content,
            baseUrl: baseUrl,
            variables: variables,
          );
          if (jsResult != null) {
            result = jsResult;
          } else {
            result = result.toString();
          }
        } else {
          // 解析普通规则（CSS/XPath/JSONPath）
          final ruleStr = fragment.content;
          if (ruleStr.isEmpty) {
            continue;
          }

          // 判断规则类型
          // 参考项目：SourceRule 构造函数中的模式识别逻辑
          String actualRuleStr = ruleStr;
          bool forceCss = false;

          // 处理 Regex 模式（以 : 开头）
          if (ruleStr.startsWith(':') && ruleStr.length > 1) {
            final afterColon = ruleStr.substring(1).trim();
            final isPseudoClass = RegExp(r'^[a-zA-Z-]').hasMatch(afterColon);

            if (!isPseudoClass) {
              // Regex 模式
              actualRuleStr = afterColon;
              final regexList = actualRuleStr
                  .split('&&')
                  .map((r) => r.trim())
                  .where((r) => r.isNotEmpty)
                  .toList();
              if (regexList.isNotEmpty) {
                final regexResult =
                    AnalyzeByRegex.getElement(result.toString(), regexList);
                if (regexResult != null && regexResult.isNotEmpty) {
                  result = regexResult.join('\n');
                } else {
                  result = null;
                }
              }
              if (result == null || (result is String && result.isEmpty)) {
                continue;
              }
              continue;
            }
          }
          // 处理 @CSS: 前缀（强制使用CSS选择器）
          else if (ruleStr.startsWith('@CSS:') || ruleStr.startsWith('@css:')) {
            actualRuleStr = ruleStr.substring(5).trim();
            forceCss = true;
          }
          // 处理 @@ 前缀（转义，使用Default模式）
          else if (ruleStr.startsWith('@@')) {
            actualRuleStr = ruleStr.substring(2);
            forceCss = true;
          }
          // 处理 @XPath: 前缀
          else if (ruleStr.startsWith('@XPath:') ||
              ruleStr.startsWith('@xpath:')) {
            actualRuleStr = ruleStr.substring(7).trim();
            result = _parseXPath(result.toString(), actualRuleStr, baseUrl,
                isUrl: isUrl);
            if (result == null || (result is String && result.isEmpty)) {
              continue;
            }
            continue;
          }
          // 处理 @Json: 前缀
          else if (ruleStr.startsWith('@Json:') ||
              ruleStr.startsWith('@json:')) {
            actualRuleStr = ruleStr.substring(6).trim();
            result = _parseJsonPath(result.toString(), actualRuleStr, baseUrl,
                isUrl: isUrl);
            if (result == null || (result is String && result.isEmpty)) {
              continue;
            }
            continue;
          }

          // 根据规则类型选择解析方法
          if (forceCss ||
              actualRuleStr.startsWith('//') == false &&
                  actualRuleStr.startsWith('/') == false) {
            // CSS 选择器或强制CSS模式
            if (actualRuleStr.startsWith('\$.') ||
                actualRuleStr.startsWith('\$[')) {
              // JSONPath（以$.或$[开头）
              result = _parseJsonPath(result.toString(), actualRuleStr, baseUrl,
                  isUrl: isUrl);
            } else {
              // CSS 选择器
              // 如果规则包含JavaScript代码，不应该在 _parseCss 中自动拼接URL
              // 因为JavaScript代码会处理URL拼接
              final shouldAutoJoinUrl = isUrl && !hasJsInRule;
              result = _parseCss(result.toString(), actualRuleStr, baseUrl,
                  isUrl: shouldAutoJoinUrl);
            }
          } else {
            // XPath（以//或/开头）
            result = _parseXPath(result.toString(), actualRuleStr, baseUrl,
                isUrl: isUrl);
          }

          if (result == null || (result is String && result.isEmpty)) {
            // 如果结果为空，继续处理下一个片段（参考项目逻辑）
            continue;
          }
        }
      } catch (e) {
        AppLog.instance
            .put('_parseSingleRule: 规则片段执行失败: ${fragment.content}', error: e);
        // 继续处理下一个片段
        continue;
      }
    }

    // 如果结果为空且是URL，返回baseUrl
    if (isUrl &&
        (result == null || (result is String && result.isEmpty)) &&
        baseUrl != null) {
      result = baseUrl;
    }

    // 应用正则替换规则
    if (result != null && replaceRule != null && replaceRule.isNotEmpty) {
      result = _applyReplaceRegexInternal(result.toString(), replaceRule);
    }

    final resultStr = result?.toString();
    AppLog.instance.put('_parseSingleRule: 解析结果长度=${resultStr?.length ?? 0}');
    return resultStr;
  }

  /// 解析规则组合（同步版本）
  static String? _parseRuleCombinationSync(
    String html,
    List<String> rules,
    String elementsType,
    String? baseUrl,
    Map<String, String> variables, {
    bool isUrl = false,
  }) {
    final results = <String>[];

    for (final rule in rules) {
      final result = _parseSingleRuleSync(html, rule.trim(), baseUrl, variables,
          isUrl: isUrl);
      if (result != null && result.isNotEmpty) {
        results.add(result);
        // 如果是 || 组合，找到第一个非空结果就返回
        if (elementsType == '||') {
          return result;
        }
      }
    }

    if (results.isEmpty) {
      return null;
    }

    // && 组合：返回所有结果的连接
    if (elementsType == '&&') {
      return results.join('\n');
    }

    // %% 组合：按索引交叉组合（参考项目逻辑）
    if (elementsType == '%%') {
      final maxLength = results
          .map((r) => r.split('\n').length)
          .reduce((a, b) => a > b ? a : b);
      final combined = <String>[];
      for (int i = 0; i < maxLength; i++) {
        for (final result in results) {
          final lines = result.split('\n');
          if (i < lines.length) {
            combined.add(lines[i]);
          }
        }
      }
      return combined.join('\n');
    }

    // 默认：返回所有结果的连接
    return results.join('\n');
  }

  /// 解析规则组合（异步版本，&&/||/%%）
  static Future<String?> _parseRuleCombination(
    String html,
    List<String> rules,
    String elementsType,
    String? baseUrl,
    Map<String, String> variables, {
    bool isUrl = false,
  }) async {
    final results = <String>[];

    for (final rule in rules) {
      final result = await _parseSingleRule(
          html, rule.trim(), baseUrl, variables,
          isUrl: isUrl);
      if (result != null && result.isNotEmpty) {
        results.add(result);
        // 如果是 || 组合，找到第一个非空结果就返回
        if (elementsType == '||') {
          return result;
        }
      }
    }

    if (results.isEmpty) {
      return null;
    }

    // && 组合：返回所有结果的连接
    if (elementsType == '&&') {
      return results.join('\n');
    }

    // %% 组合：按索引交叉组合（参考项目逻辑）
    if (elementsType == '%%') {
      final maxLength = results
          .map((r) => r.split('\n').length)
          .reduce((a, b) => a > b ? a : b);
      final combined = <String>[];
      for (int i = 0; i < maxLength; i++) {
        for (final result in results) {
          final lines = result.split('\n');
          if (i < lines.length) {
            combined.add(lines[i]);
          }
        }
      }
      return combined.join('\n');
    }

    // 默认：返回所有结果的连接
    return results.join('\n');
  }

  /// 解析 CSS 选择器规则（参考 AnalyzeByJSoup）
  static String? _parseCss(String html, String selector, String? baseUrl,
      {bool isUrl = false}) {
    final document = html_parser.parse(html);

    // 规范化CSS选择器（处理JSoup格式）
    final originalSelector = selector;
    selector = _normalizeCssSelector(selector);
    if (originalSelector != selector) {
      AppLog.instance
          .put('_parseCss: 选择器规范化: "$originalSelector" -> "$selector"');
    }

    // 检查是否包含 @ 分隔符（例如：img@src, a@href, class.title@text, id.pic@img@src）
    // 支持嵌套选择器：id.pic@img@src -> 先选择id.pic，再选择img，最后获取src属性
    final allAtIndices = <int>[];
    for (int i = 0; i < selector.length; i++) {
      if (selector[i] == '@') {
        allAtIndices.add(i);
      }
    }

    if (allAtIndices.isNotEmpty) {
      // 如果有多个@，最后一个@后面的部分是属性名，前面的是选择器链
      // 例如：id.pic@img@src -> elementSelectorChain=["id.pic", "img"], attributeName="src"
      final lastAtIndex = allAtIndices.last;
      final elementSelectorChain = selector.substring(0, lastAtIndex).trim();
      final attributeName = selector.substring(lastAtIndex + 1).trim();

      AppLog.instance.put(
          '_parseCss: 分离选择器: elementSelectorChain="$elementSelectorChain", attributeName="$attributeName"');

      if (elementSelectorChain.isNotEmpty && attributeName.isNotEmpty) {
        // 检查是否包含多个@，即嵌套选择器（如 id.pic@img@src）
        html_dom.Element? element;
        if (allAtIndices.length > 1) {
          // 嵌套选择器：先选择第一个元素，再在该元素内选择第二个元素
          // 例如：id.pic@img -> 先选择#pic，再在#pic内选择img
          final selectorParts = elementSelectorChain.split('@');
          if (selectorParts.length >= 2) {
            // 第一步：选择根元素（如 id.pic -> #pic）
            final rootSelector = selectorParts[0].trim();
            String normalizedRootSelector;
            if (rootSelector.startsWith('class.')) {
              normalizedRootSelector = '.${rootSelector.substring(6)}';
            } else if (rootSelector.startsWith('id.')) {
              normalizedRootSelector = '#${rootSelector.substring(3)}';
            } else {
              normalizedRootSelector = rootSelector;
            }

            AppLog.instance.put(
                '_parseCss: 嵌套选择器第一步: "$rootSelector" -> "$normalizedRootSelector"');
            element =
                HtmlParser.selectElement(document, normalizedRootSelector);

            if (element != null) {
              AppLog.instance.put('_parseCss: 找到根元素: ${element.localName}');

              // 第二步：在根元素内选择子元素（如 img）
              for (int i = 1; i < selectorParts.length; i++) {
                final childSelector = selectorParts[i].trim();
                if (childSelector.isNotEmpty && element != null) {
                  AppLog.instance.put(
                      '_parseCss: 嵌套选择器第${i + 1}步: 在 ${element.localName} 内查找 "$childSelector"');
                  final childElement =
                      HtmlParser.selectElement(element, childSelector);
                  if (childElement != null) {
                    element = childElement;
                    AppLog.instance
                        .put('_parseCss: 找到子元素: ${element.localName}');
                  } else {
                    AppLog.instance.put('_parseCss: 未找到子元素: $childSelector');
                    element = null;
                    break;
                  }
                }
              }
            } else {
              AppLog.instance.put('_parseCss: 未找到根元素: $normalizedRootSelector');
            }
          }
        } else {
          // 单个选择器（如 img@src, id.pic@text）
          // 检查是否包含特殊前缀（tag., class., id., children., text.）
          final hasSpecialPrefix = elementSelectorChain.startsWith('tag.') ||
              elementSelectorChain.startsWith('class.') ||
              elementSelectorChain.startsWith('id.') ||
              elementSelectorChain.startsWith('children.') ||
              elementSelectorChain.startsWith('text.');

          if (hasSpecialPrefix) {
            // 对于 class.xxx 和 id.xxx，优先使用 CSS 选择器（更可靠）
            // 对于 tag.xxx 和 children.xxx，使用 ElementsSingle
            final useCssSelector = elementSelectorChain.startsWith('class.') ||
                elementSelectorChain.startsWith('id.');

            if (useCssSelector) {
              // 手动规范化 class.xxx 和 id.xxx
              String normalizedSelector;
              if (elementSelectorChain.startsWith('class.')) {
                normalizedSelector = '.${elementSelectorChain.substring(6)}';
              } else if (elementSelectorChain.startsWith('id.')) {
                normalizedSelector = '#${elementSelectorChain.substring(3)}';
              } else {
                normalizedSelector = elementSelectorChain;
              }
              AppLog.instance.put(
                  '_parseCss: 规范化选择器 "$elementSelectorChain" -> "$normalizedSelector"');
              element = HtmlParser.selectElement(document, normalizedSelector);
              if (element != null) {
                AppLog.instance
                    .put('_parseCss: CSS选择器找到元素: ${element.localName}');
              } else {
                AppLog.instance
                    .put('_parseCss: CSS选择器未找到元素: $normalizedSelector');
              }
            } else {
              // 使用 ElementsSingle 处理 tag.xxx 和 children.xxx
              try {
                // 对于HTML片段，应该使用body或documentElement作为根元素
                // 但是如果documentElement是html标签，应该使用body或第一个子元素
                html_dom.Element? searchRoot;
                if (document.body != null) {
                  searchRoot = document.body;
                } else if (document.documentElement != null) {
                  // 如果documentElement是html标签，尝试使用第一个子元素或整个documentElement
                  final docElement = document.documentElement!;
                  if (docElement.children.isNotEmpty) {
                    // 对于HTML片段，第一个子元素通常是实际的根元素
                    searchRoot = docElement.children.first;
                  } else {
                    searchRoot = docElement;
                  }
                } else {
                  searchRoot = null;
                }

                if (searchRoot != null) {
                  final elements = ElementsSingle.getElementsSingle(
                      searchRoot, elementSelectorChain);
                  if (elements.isNotEmpty) {
                    element = elements[0];
                    AppLog.instance.put(
                        '_parseCss: ElementsSingle 找到 ${elements.length} 个元素，使用第一个');
                  } else {
                    // 回退到普通CSS选择器：将 tag.a.0 转换为 a（移除tag.前缀和索引）
                    // tag.a.0 -> a.0 -> a（移除所有数字后缀）
                    var fallbackSelector =
                        elementSelectorChain.replaceFirst('tag.', '');
                    // 移除索引后缀（如 .0, .1, .-1 等）
                    fallbackSelector =
                        fallbackSelector.replaceAll(RegExp(r'\.-?\d+$'), '');
                    element =
                        HtmlParser.selectElement(document, fallbackSelector);

                    AppLog.instance.put(
                        '_parseCss: ElementsSingle 未找到元素: $elementSelectorChain');
                  }
                }
              } catch (e) {
                AppLog.instance.put(
                    '_parseCss: ElementsSingle 处理失败: $elementSelectorChain, 错误: $e');
                // 回退到普通CSS选择器
                final fallbackSelector =
                    elementSelectorChain.replaceFirst('tag.', '');
                element = HtmlParser.selectElement(document, fallbackSelector);
              }
            }
          } else {
            // 普通CSS选择器
            element = HtmlParser.selectElement(document, elementSelectorChain);
          }
        }

        if (element != null) {
          AppLog.instance.put('_parseCss: 找到元素: ${element.localName}');
          // 特殊处理：@text, @html, @textNodes, @ownText, @all 等
          // 参考项目：AnalyzeByJSoup.getResultLast
          final attrLower = attributeName.toLowerCase();
          if (attrLower == 'text') {
            final text = HtmlParser.getText(element);
            AppLog.instance.put('_parseCss: 获取文本内容，长度=${text?.length ?? 0}');
            return text;
          } else if (attrLower == 'html') {
            // 参考项目：移除script和style标签后再返回
            final html = HtmlParser.getHtmlWithoutScriptAndStyle(element);
            AppLog.instance.put(
                '_parseCss: 获取HTML内容（已移除script/style），长度=${html?.length ?? 0}');
            return html;
          } else if (attrLower == 'textnodes') {
            // 参考项目：获取文本节点（不包括子元素的文本）
            final textNodes = HtmlParser.getTextNodes(element);
            AppLog.instance
                .put('_parseCss: 获取文本节点，长度=${textNodes?.length ?? 0}');
            return textNodes;
          } else if (attrLower == 'owntext') {
            // 参考项目：获取元素自身的文本（不包括子元素）
            final ownText = HtmlParser.getOwnText(element);
            AppLog.instance.put('_parseCss: 获取自身文本，长度=${ownText?.length ?? 0}');
            return ownText;
          } else if (attrLower == 'all') {
            // 参考项目：获取完整的outerHTML（不删除script和style）
            final allHtml = HtmlParser.getAllHtml(element);
            AppLog.instance
                .put('_parseCss: 获取完整HTML，长度=${allHtml?.length ?? 0}');
            return allHtml;
          }

          // 获取属性值
          final attrValue = HtmlParser.getAttribute(element, attributeName);
          if (attrValue != null && attrValue.isNotEmpty) {
            AppLog.instance
                .put('_parseCss: 获取属性值: $attributeName="$attrValue"');
            // 如果是URL相关的属性（href, src, data-src等），且isUrl=true，使用baseUrl处理
            // 注意：如果规则包含@js:，不应该在这里拼接URL，应该让JavaScript代码处理
            if (isUrl &&
                baseUrl != null &&
                (attributeName == 'href' ||
                    attributeName == 'src' ||
                    attributeName == 'data-src' ||
                    attributeName.startsWith('data-'))) {
              final joinedUrl = NetworkService.joinUrl(baseUrl, attrValue);
              return joinedUrl;
            }
            return attrValue;
          } else {
            AppLog.instance.put('_parseCss: 属性 $attributeName 为空或不存在');
          }
        } else {
          AppLog.instance.put('_parseCss: 未找到元素: $elementSelectorChain');
        }
      }
      return null;
    }

    // 没有 @ 分隔符，按普通选择器处理
    final element = HtmlParser.selectElement(document, selector);
    if (element == null) {
      AppLog.instance.put('_parseCss: 未找到元素: $selector');
      return null;
    }

    AppLog.instance.put('_parseCss: 找到元素: ${element.localName}');

    // 如果是URL解析，优先尝试获取链接属性
    if (isUrl) {
      // 尝试获取 href 属性（链接）
      final href = HtmlParser.getAttribute(element, 'href');
      if (href != null && href.isNotEmpty) {
        return baseUrl != null ? NetworkService.joinUrl(baseUrl, href) : href;
      }
      // 尝试获取其他可能的URL属性
      final src = HtmlParser.getAttribute(element, 'src');
      if (src != null && src.isNotEmpty) {
        return baseUrl != null ? NetworkService.joinUrl(baseUrl, src) : src;
      }
      // 如果都没有，返回文本内容（可能是相对路径）
      final text = HtmlParser.getText(element);
      if (text != null && text.isNotEmpty && baseUrl != null) {
        return NetworkService.joinUrl(baseUrl, text);
      }
      return text;
    }

    // 如果是链接元素，尝试获取 href 属性
    if (element.localName == 'a') {
      final href = HtmlParser.getAttribute(element, 'href');
      if (href != null && href.isNotEmpty && baseUrl != null) {
        return NetworkService.joinUrl(baseUrl, href);
      }
      return href ?? HtmlParser.getText(element);
    }

    // 如果是图片元素，尝试获取 src 或 data-src 属性
    if (element.localName == 'img') {
      var src = HtmlParser.getAttribute(element, 'src');
      if (src == null || src.isEmpty) {
        src = HtmlParser.getAttribute(element, 'data-src');
      }
      if (src != null && src.isNotEmpty && baseUrl != null) {
        return NetworkService.joinUrl(baseUrl, src);
      }
      return src ?? HtmlParser.getText(element);
    }

    // 默认返回文本内容
    return HtmlParser.getText(element);
  }

  /// 解析 XPath 规则（参考 AnalyzeByXPath）
  /// 支持属性选择（@href, @src等）和文本提取
  /// 参考项目：AnalyzeByXPath.getString - 使用 JXNode.asString() 获取节点值
  static String? _parseXPath(String html, String xpath, String? baseUrl,
      {bool isUrl = false}) {
    try {
      final document = html_parser.parse(html);
      final nodes = HtmlParser.selectXPath(document, xpath);

      if (nodes.isEmpty) return null;

      // 参考项目：AnalyzeByXPath.getString - 使用 TextUtils.join("\n", it) 连接多个结果
      // 参考项目：getResult(rule)?.let { return TextUtils.join("\n", it) }
      // 其中 it 是 List<JXNode>，每个节点调用 asString() 获取字符串表示
      final results = <String>[];

      for (final node in nodes) {
        String? value;

        // 参考项目：JXNode.asString() 会自动处理属性和文本
        // 如果 XPath 查询的是属性节点（如 //a/@href），asString() 返回属性值
        // 如果 XPath 查询的是元素节点（如 //a），asString() 返回文本内容

        // 检查 XPath 是否包含属性选择（@attributeName）
        if (xpath.contains('@')) {
          // 尝试从 XPath 表达式中提取属性名
          // 支持格式：//a/@href, //img/@src, //div/@data-id 等
          final attrMatch = RegExp(r'@(\w+(?:-\w+)*)').firstMatch(xpath);
          if (attrMatch != null) {
            final attrName = attrMatch.group(1);
            if (attrName != null) {
              // 如果 XPath 查询的是属性节点，node.text 应该就是属性值
              // 参考项目：JXNode.asString() 对于属性节点返回属性值
              value = HtmlParser.getXPathNodeString(node);

              // 如果获取失败，尝试使用专门的属性获取方法
              if (value == null || value.isEmpty) {
                value = HtmlParser.getXPathNodeAttribute(node, attrName);
              }
            }
          }
        }

        // 如果不是属性选择或属性获取失败，使用 asString() 的等价方法
        if (value == null || value.isEmpty) {
          // 参考项目：JXNode.asString() 对于元素节点返回文本内容
          value = HtmlParser.getXPathNodeString(node);
        }

        if (value != null && value.isNotEmpty) {
          // 如果是URL相关的属性，使用baseUrl处理
          // 参考项目：在 AnalyzeRule.getString 中，如果 isUrl=true，会进行 URL 处理
          if (baseUrl != null &&
              (isUrl ||
                  (xpath.contains('@href') ||
                      xpath.contains('@src') ||
                      xpath.contains('@data-src') ||
                      xpath.contains('@data-')))) {
            value = NetworkService.joinUrl(baseUrl, value);
          }
          results.add(value);
        }
      }

      if (results.isEmpty) return null;

      // 参考项目：多个结果用换行符连接
      // TextUtils.join("\n", it) 等价于 results.join('\n')
      final result = results.join('\n');

      // 如果是URL解析，尝试从文本内容构建URL
      // 参考项目：在 AnalyzeRule.getString 中，如果 isUrl=true 且结果不是完整URL，会使用 baseUrl 拼接
      if (isUrl &&
          result.isNotEmpty &&
          baseUrl != null &&
          !result.startsWith('http')) {
        return NetworkService.joinUrl(baseUrl, result);
      }

      return result;
    } catch (e) {
      AppLog.instance.put('_parseXPath: XPath解析失败: $xpath', error: e);
      return null;
    }
  }

  /// 规范化CSS选择器（将JSoup格式转换为标准CSS格式）
  /// 例如：class.hot_sale -> .hot_sale, id.main -> #main
  /// 注意：如果选择器包含 @ 分隔符，只规范化 @ 之前的部分
  /// 注意：如果选择器包含特殊前缀（tag., class., id., children., text.），不进行规范化
  static String _normalizeCssSelector(String selector) {
    // 如果包含 @ 分隔符，分别处理选择器部分和属性部分
    final lastAtIndex = selector.lastIndexOf('@');
    if (lastAtIndex > 0 && lastAtIndex < selector.length - 1) {
      final elementSelector = selector.substring(0, lastAtIndex).trim();
      final attributeName = selector.substring(lastAtIndex + 1).trim();

      // 检查是否包含特殊前缀，如果包含则不规范化（这些规则需要使用 ElementsSingle 处理）
      final hasSpecialPrefix = elementSelector.startsWith('tag.') ||
          elementSelector.startsWith('class.') ||
          elementSelector.startsWith('id.') ||
          elementSelector.startsWith('children.') ||
          elementSelector.startsWith('text.');

      if (hasSpecialPrefix) {
        // 不规范化，保持原样
        return '$elementSelector@$attributeName';
      }

      // 只规范化选择器部分
      final normalizedSelector = _normalizeSelectorPart(elementSelector);
      return '$normalizedSelector@$attributeName';
    }

    // 检查是否包含特殊前缀，如果包含则不规范化
    final hasSpecialPrefix = selector.startsWith('tag.') ||
        selector.startsWith('class.') ||
        selector.startsWith('id.') ||
        selector.startsWith('children.') ||
        selector.startsWith('text.');

    if (hasSpecialPrefix) {
      // 不规范化，保持原样
      return selector;
    }

    // 没有 @ 分隔符，直接规范化整个选择器
    return _normalizeSelectorPart(selector);
  }

  /// 规范化选择器部分（不包含 @ 的部分）
  static String _normalizeSelectorPart(String selector) {
    // 处理 class.xxx 格式 -> .xxx
    selector = selector.replaceAllMapped(
      RegExp(r'\bclass\.([\w-]+)'),
      (match) => '.${match.group(1)}',
    );
    // 处理 id.xxx 格式 -> #xxx
    selector = selector.replaceAllMapped(
      RegExp(r'\bid\.([\w-]+)'),
      (match) => '#${match.group(1)}',
    );
    // 处理 tag.xxx 格式 -> xxx（标签名直接使用）
    selector = selector.replaceAllMapped(
      RegExp(r'\btag\.([\w-]+)'),
      (match) => match.group(1)!,
    );
    return selector;
  }

  /// 解析列表规则
  /// [returnHtml] 如果为true，返回元素的HTML内容（innerHTML），否则返回文本内容
  static List<String> parseListRule(
    String html,
    String? rule, {
    Map<String, String>? variables,
    String? baseUrl,
    bool returnHtml = false,
  }) {
    if (rule == null || rule.isEmpty) return [];

    try {
      String processedRule = _replaceVariables(rule, variables);

      final document = html_parser.parse(html);
      List<String> results = [];

      if (processedRule.startsWith('//') || processedRule.startsWith('/')) {
        final nodes = HtmlParser.selectXPath(document, processedRule);
        if (returnHtml) {
          // 对于XPath，返回HTML内容（outerHTML）
          // 参考项目：JXNode.asString() 返回字符串表示
          // 使用 HtmlParser.getXPathNodeOuterHtml 获取节点的完整HTML
          results = nodes
              .map((node) {
                try {
                  final html = HtmlParser.getXPathNodeOuterHtml(node);
                  return html?.trim() ?? '';
                } catch (e) {
                  // 如果获取失败，尝试使用 toString() 作为后备
                  try {
                    return node.toString().trim();
                  } catch (e2) {
                    return '';
                  }
                }
              })
              .where((html) => html.isNotEmpty)
              .toList();
        } else {
          // 返回文本内容
          // 参考项目：JXNode.asString() 对于元素节点返回文本内容
          results = nodes
              .map((node) {
                // 使用 getXPathNodeString 获取节点字符串表示
                // 参考项目：JXNode.asString() 的行为
                final text = HtmlParser.getXPathNodeString(node);
                return text?.trim() ?? '';
              })
              .where((text) => text.isNotEmpty)
              .toList();
        }
      } else {
        // 参考项目：如果规则包含 @ 分隔符，需要区分两种情况：
        // 1. 元素选择器链：id.list@tag.dd（选择 id.list，然后在结果中选择 tag.dd）
        // 2. 属性选择器：tag.a@text, tag.a@href（选择 tag.a，然后获取 text 或 href 属性）
        //
        // 判断规则是元素选择器链还是属性选择器：
        // - 如果最后一个 @ 后面是属性名（text, html, href, src等），则是属性选择器，不应该分割
        // - 否则是元素选择器链，需要分割

        // 检查是否是属性选择器（@text, @html, @href, @src等）
        final lastAtIndex = processedRule.lastIndexOf('@');
        bool isAttributeSelector = false;
        if (lastAtIndex > 0 && lastAtIndex < processedRule.length - 1) {
          final afterAt = processedRule.substring(lastAtIndex + 1).trim();
          // 常见的属性名（包括特殊属性）
          final attributeNames = [
            'text',
            'html',
            'textnodes',
            'owntext',
            'all',
            'href',
            'src',
            'data-src',
            'alt',
            'title',
            'class',
            'id'
          ];
          isAttributeSelector = attributeNames.contains(afterAt.toLowerCase());
          AppLog.instance.put(
              'parseListRule: 检查属性选择器 - afterAt="$afterAt", isAttributeSelector=$isAttributeSelector');
        }

        if (isAttributeSelector) {
          // 属性选择器，不分割，直接使用 _parseCss 处理
          // 但 parseListRule 需要返回元素列表，所以需要先选择元素，再获取属性
          final elementSelector =
              processedRule.substring(0, lastAtIndex).trim();
          final attributeName = processedRule.substring(lastAtIndex + 1).trim();

          final normalizedRule = _normalizeCssSelector(elementSelector);
          final elements = HtmlParser.selectElements(document, normalizedRule);

          for (final element in elements) {
            final attrLower = attributeName.toLowerCase();
            String? value;

            // 参考项目：AnalyzeByJSoup.getResultLast - 处理特殊属性
            if (attrLower == 'text') {
              value = HtmlParser.getText(element);
            } else if (attrLower == 'html') {
              // 移除script和style标签
              value = HtmlParser.getHtmlWithoutScriptAndStyle(element);
            } else if (attrLower == 'textnodes') {
              value = HtmlParser.getTextNodes(element);
            } else if (attrLower == 'owntext') {
              value = HtmlParser.getOwnText(element);
            } else if (attrLower == 'all') {
              value = HtmlParser.getAllHtml(element);
            } else {
              // 其他属性（href, src等）
              value = HtmlParser.getAttribute(element, attributeName);
            }

            if (value != null && value.isNotEmpty) {
              results.add(value);
            }
          }
        } else {
          // 元素选择器链，按 @ 分割，依次应用每个规则片段
          // 例如：id.list@tag.dd 会被分割为 ["id.list", "tag.dd"]
          // 先选择 id.list，然后在结果中选择 tag.dd
          final ruleParts = processedRule.split('@');

          if (ruleParts.length > 1) {
            // 包含 @ 分隔符，需要依次应用每个规则片段

            AppLog.instance
                .put('parseListRule: 检测到元素选择器链，规则片段数=${ruleParts.length}');

            // 从 document 开始，依次应用每个规则片段
            // 参考项目：从 temp（当前上下文）开始，依次应用每个规则片段
            List<html_dom.Element> currentElements = [];
            final rootElement = document.documentElement ?? document.body;
            if (rootElement != null) {
              currentElements.add(rootElement);
            }

            for (int i = 0; i < ruleParts.length; i++) {
              final rulePart = ruleParts[i].trim();
              if (rulePart.isEmpty) continue;
              AppLog.instance.put(
                  'parseListRule: 应用规则片段 ${i + 1}/${ruleParts.length}: $rulePart');
              AppLog.instance
                  .put('parseListRule: 当前上下文元素数=${currentElements.length}');

              // 参考项目：AnalyzeByJSoup.getElements - 对于非CSS规则，总是使用 ElementsSingle
              // 检查规则是否包含特殊前缀（tag., class., id., children., text.）
              // 这些规则应该使用 ElementsSingle 处理，即使没有索引
              final hasSpecialPrefix = rulePart.startsWith('tag.') ||
                  rulePart.startsWith('class.') ||
                  rulePart.startsWith('id.') ||
                  rulePart.startsWith('children.') ||
                  rulePart.startsWith('text.');

              // 检查规则是否包含索引选择（例如：tag.div.0:3 或 tag.div[-1, 2]）
              final hasIndex = rulePart.contains('.') &&
                  (RegExp(r'[:\-\[\]!]').hasMatch(rulePart) ||
                      RegExp(r'\.\d').hasMatch(rulePart));

              AppLog.instance.put(
                  'parseListRule: 规则片段 $rulePart - hasSpecialPrefix=$hasSpecialPrefix, hasIndex=$hasIndex');

              final nextElements = <html_dom.Element>[];
              for (final element in currentElements) {
                // 参考项目：如果规则包含特殊前缀或索引，使用 ElementsSingle
                if (hasSpecialPrefix || hasIndex) {
                  // 对于 id. 和 class. 前缀，优先使用 CSS 选择器（更可靠）
                  // 对于 tag. 和 children. 前缀，使用 ElementsSingle
                  final useCssSelector = rulePart.startsWith('id.') ||
                      rulePart.startsWith('class.');

                  if (useCssSelector) {
                    // 使用 CSS 选择器处理 id. 和 class.
                    // 手动规范化 id.xxx -> #xxx, class.xxx -> .xxx
                    String normalizedRule;
                    if (rulePart.startsWith('id.')) {
                      normalizedRule = '#${rulePart.substring(3)}';
                    } else if (rulePart.startsWith('class.')) {
                      normalizedRule = '.${rulePart.substring(6)}';
                    } else {
                      normalizedRule = _normalizeCssSelector(rulePart);
                    }
                    final selected =
                        HtmlParser.selectElements(element, normalizedRule);
                    nextElements.addAll(selected);
                    AppLog.instance
                        .put('parseListRule: CSS选择器找到 ${selected.length} 个元素');
                  } else {
                    // 使用 ElementsSingle 处理 tag. 和 children.
                    // 对于 tag.dd 这种简单规则，也可以尝试直接使用 CSS 选择器
                    try {
                      final selected =
                          ElementsSingle.getElementsSingle(element, rulePart);
                      nextElements.addAll(selected);
                      if (selected.isEmpty) {
                        // 回退到 CSS 选择器：tag.dd -> dd
                        String normalizedRule;
                        if (rulePart.startsWith('tag.')) {
                          normalizedRule =
                              rulePart.substring(4); // tag.dd -> dd
                        } else {
                          normalizedRule = _normalizeCssSelector(rulePart);
                        }
                        final cssSelected =
                            HtmlParser.selectElements(element, normalizedRule);
                        nextElements.addAll(cssSelected);
                        AppLog.instance.put(
                            'parseListRule: CSS选择器找到 ${cssSelected.length} 个元素');
                      }
                      AppLog.instance.put(
                          'parseListRule: ElementsSingle 找到 ${selected.length} 个元素');
                    } catch (e) {
                      // 如果 ElementsSingle 失败，回退到普通CSS选择器
                      AppLog.instance.put(
                          'parseListRule: ElementsSingle 失败，回退到CSS选择器: $rulePart, 错误: $e');
                      // 回退到 CSS 选择器：tag.dd -> dd
                      String normalizedRule;
                      if (rulePart.startsWith('tag.')) {
                        normalizedRule = rulePart.substring(4); // tag.dd -> dd
                      } else {
                        normalizedRule = _normalizeCssSelector(rulePart);
                      }
                      AppLog.instance
                          .put('parseListRule: 规范化后的规则: "$normalizedRule"');
                      final selected =
                          HtmlParser.selectElements(element, normalizedRule);
                      nextElements.addAll(selected);
                      AppLog.instance.put(
                          'parseListRule: CSS选择器找到 ${selected.length} 个元素');
                    }
                  }
                } else {
                  // 普通CSS选择器
                  final normalizedRule = _normalizeCssSelector(rulePart);

                  AppLog.instance.put(
                      'parseListRule: 规范化规则片段 "$rulePart" -> "$normalizedRule"');
                  final selected =
                      HtmlParser.selectElements(element, normalizedRule);
                  nextElements.addAll(selected);
                  AppLog.instance.put(
                      'parseListRule: 从元素中找到 ${selected.length} 个子元素（规则: $normalizedRule）');
                }
              }
              AppLog.instance.put(
                  'parseListRule: 规则片段 $rulePart 找到 ${nextElements.length} 个元素');
              currentElements = nextElements;

              // 如果某个规则片段没有找到元素，停止处理
              if (currentElements.isEmpty) {
                AppLog.instance.put('parseListRule: 规则片段 $rulePart 未找到元素，停止处理');
                break;
              }
            }

            // 处理最终结果
            for (final element in currentElements) {
              if (returnHtml) {
                // 返回 outerHTML（包含元素本身的标签），以便后续可以解析属性（如 href）
                final html = HtmlParser.getOuterHtml(element) ?? '';
                if (html.isNotEmpty) {
                  results.add(html);
                }
              } else {
                final text = HtmlParser.getText(element) ?? '';
                if (text.isNotEmpty) {
                  results.add(text);
                }
              }
            }
          } else {
            // 没有 @ 分隔符，检查是否是特殊前缀规则
            final hasSpecialPrefix = processedRule.startsWith('tag.') ||
                processedRule.startsWith('class.') ||
                processedRule.startsWith('id.') ||
                processedRule.startsWith('children.') ||
                processedRule.startsWith('text.');

            if (hasSpecialPrefix) {
              // 对于 class.xxx 和 id.xxx，优先使用 CSS 选择器（更可靠）
              // 对于 tag.xxx 和 children.xxx，使用 ElementsSingle
              final useCssSelector = processedRule.startsWith('class.') ||
                  processedRule.startsWith('id.');

              if (useCssSelector) {
                // 使用 CSS 选择器
                // 对于 class.xxx 和 id.xxx，直接规范化（不使用 _normalizeCssSelector，因为它会跳过特殊前缀）
                String normalizedRule;
                if (processedRule.startsWith('class.')) {
                  // class.hot_sale -> .hot_sale
                  normalizedRule = '.${processedRule.substring(6)}';
                } else if (processedRule.startsWith('id.')) {
                  // id.main -> #main
                  normalizedRule = '#${processedRule.substring(3)}';
                } else {
                  normalizedRule = _normalizeCssSelector(processedRule);
                }
                AppLog.instance.put(
                    'parseListRule: 规范化规则 "$processedRule" -> "$normalizedRule"');
                final elements =
                    HtmlParser.selectElements(document, normalizedRule);
                AppLog.instance
                    .put('parseListRule: CSS选择器找到 ${elements.length} 个元素');

                if (returnHtml) {
                  results = elements
                      .map((e) => HtmlParser.getOuterHtml(e) ?? '')
                      .toList();
                } else {
                  results =
                      elements.map((e) => HtmlParser.getText(e) ?? '').toList();
                }
              } else {
                // 使用 ElementsSingle 处理 tag.xxx 和 children.xxx
                AppLog.instance.put(
                    'parseListRule: 检测到特殊前缀规则，使用 ElementsSingle 处理: $processedRule');
                try {
                  final rootElement = document.documentElement ?? document.body;
                  if (rootElement != null) {
                    final selectedElements = ElementsSingle.getElementsSingle(
                        rootElement, processedRule);
                    AppLog.instance.put(
                        'parseListRule: ElementsSingle 找到 ${selectedElements.length} 个元素（规则: $processedRule）');

                    if (returnHtml) {
                      results = selectedElements
                          .map((e) => HtmlParser.getOuterHtml(e) ?? '')
                          .toList();
                    } else {
                      results = selectedElements
                          .map((e) => HtmlParser.getText(e) ?? '')
                          .toList();
                    }
                  } else {
                    AppLog.instance.put('parseListRule: 未找到根元素');
                  }
                } catch (e) {
                  // 如果 ElementsSingle 失败，回退到普通CSS选择器
                  AppLog.instance.put(
                      'parseListRule: ElementsSingle 失败，回退到CSS选择器: $processedRule, 错误: $e');
                  final normalizedRule = _normalizeCssSelector(processedRule);
                  AppLog.instance.put(
                      'parseListRule: 规范化规则 "$processedRule" -> "$normalizedRule"');
                  final elements =
                      HtmlParser.selectElements(document, normalizedRule);
                  AppLog.instance
                      .put('parseListRule: CSS选择器找到 ${elements.length} 个元素');
                  if (returnHtml) {
                    results = elements
                        .map((e) => HtmlParser.getOuterHtml(e) ?? '')
                        .toList();
                  } else {
                    results = elements
                        .map((e) => HtmlParser.getText(e) ?? '')
                        .toList();
                  }
                }
              }
            } else {
              // 普通CSS选择器
              final normalizedRule = _normalizeCssSelector(processedRule);
              AppLog.instance.put(
                  'parseListRule: 规范化规则 "$processedRule" -> "$normalizedRule"');
              final elements =
                  HtmlParser.selectElements(document, normalizedRule);
              AppLog.instance
                  .put('parseListRule: CSS选择器找到 ${elements.length} 个元素');
              if (returnHtml) {
                // 返回 outerHTML（包含元素本身的标签），以便后续可以解析属性（如 href）
                results = elements
                    .map((e) => HtmlParser.getOuterHtml(e) ?? '')
                    .toList();
              } else {
                // 返回文本内容
                results =
                    elements.map((e) => HtmlParser.getText(e) ?? '').toList();
              }
            }
          }
        }
      }

      final filtered = results.where((r) => r.isNotEmpty).toList();

      // 添加调试日志
      if (filtered.isEmpty) {
        AppLog.instance.put('parseListRule: 规则未匹配到任何元素');
        AppLog.instance
            .put('parseListRule: 规则=$processedRule, returnHtml=$returnHtml');
        // 尝试查找是否有类似的类名
        if (!processedRule.startsWith('//') && !processedRule.startsWith('/')) {
          // 查找HTML中的class属性（支持单引号和双引号）
          final classPattern1 = RegExp(r'class\s*=\s*"([^"]+)"');
          final classPattern2 = RegExp(r"class\s*=\s*'([^']+)'");
          final matches1 = classPattern1.allMatches(html);
          final matches2 = classPattern2.allMatches(html);
          final allMatches = [...matches1, ...matches2];
          if (allMatches.isNotEmpty) {
            final classNames = <String>{};
            for (final match in allMatches) {
              final classValue = match.group(1);
              if (classValue != null && classValue.isNotEmpty) {
                // 分割多个类名
                final names = classValue.split(RegExp(r'\s+'));
                classNames.addAll(names.where((n) => n.isNotEmpty));
              }
            }
            AppLog.instance.put(
                'parseListRule: HTML中找到的class名称（前10个）: ${classNames.take(10).join(", ")}');
          }
        }
      } else {
        AppLog.instance.put('parseListRule: 规则匹配成功，找到 ${filtered.length} 个元素');
        if (returnHtml && filtered.isNotEmpty) {
          // 返回HTML内容
          AppLog.instance.put(
              'parseListRule: 第一个元素的HTML（前200字符）: ${filtered[0].substring(0, filtered[0].length > 200 ? 200 : filtered[0].length)}');
        }
      }
      return filtered;
    } catch (e) {
      return [];
    }
  }

  /// 解析搜索规则
  static Future<List<Map<String, String?>>> parseSearchRule(
    String html,
    SearchRule? rule, {
    Map<String, String>? variables,
    String? baseUrl,
  }) async {
    if (rule == null || rule.bookList == null) return [];

    // 对于bookList，需要返回HTML内容（returnHtml=true），以便后续解析子元素
    final bookListHtml = parseListRule(html, rule.bookList,
        variables: variables, baseUrl: baseUrl, returnHtml: true);
    final results = <Map<String, String?>>[];

    for (int i = 0; i < bookListHtml.length; i++) {
      final bookHtml = bookListHtml[i];

      // 解析bookUrl时使用isUrl=true，参考项目逻辑
      final bookUrl = await parseRuleAsync(bookHtml, rule.bookUrl,
          variables: variables, baseUrl: baseUrl, isUrl: true);
      final nameRaw = await parseRuleAsync(bookHtml, rule.name,
          variables: variables, baseUrl: baseUrl);
      final authorRaw = await parseRuleAsync(bookHtml, rule.author,
          variables: variables, baseUrl: baseUrl);
      final kindRaw = await parseRuleAsync(bookHtml, rule.kind,
          variables: variables, baseUrl: baseUrl);
      final wordCount = await parseRuleAsync(bookHtml, rule.wordCount,
          variables: variables, baseUrl: baseUrl);
      final lastChapter = await parseRuleAsync(bookHtml, rule.lastChapter,
          variables: variables, baseUrl: baseUrl);
      final intro = await parseRuleAsync(bookHtml, rule.intro,
          variables: variables, baseUrl: baseUrl);
      final coverUrl = await parseRuleAsync(bookHtml, rule.coverUrl,
          variables: variables, baseUrl: baseUrl);
      final checkKeyWord = await parseRuleAsync(bookHtml, rule.checkKeyWord,
          variables: variables, baseUrl: baseUrl);

      // 处理 name、author、kind：trim 并清理 HTML 标签（如果存在）
      final name = nameRaw?.trim();
      final author = authorRaw?.trim();
      String? kind = kindRaw?.trim();
      // 如果 kind 包含 HTML 标签，清理它们（参考项目：kind 字段应该只包含纯文本）
      if (kind != null && kind.isNotEmpty && kind.contains('<')) {
        kind = HtmlParser.cleanHtml(kind).trim();
      }

      // 添加调试日志（仅前3个结果）
      if (i < 3) {
        AppLog.instance.put(
            'parseSearchRule: 书籍 ${i + 1} - name=$name, author=$author, kind=$kind, kind规则=${rule.kind}');
      }

      results.add({
        'name': name,
        'author': author,
        'kind': kind,
        'wordCount': wordCount,
        'lastChapter': lastChapter,
        'intro': intro,
        'coverUrl': coverUrl,
        'bookUrl': bookUrl, // 使用isUrl=true解析的结果
        'checkKeyWord': checkKeyWord, // 用于验证搜索结果是否包含关键词
      });
    }

    return results;
  }

  /// 解析书籍详情规则
  static Future<Map<String, String?>> parseBookInfoRule(
    String html,
    BookInfoRule? rule, {
    Map<String, String>? variables,
    String? baseUrl,
  }) async {
    if (rule == null) return {};

    // 执行初始化脚本（如果有）
    if (rule.init != null && rule.init!.isNotEmpty) {
      html = await _executeJs(html, rule.init!, variables: variables) ?? html;
    }

    // 解析各个字段
    final nameRaw = await parseRuleAsync(html, rule.name,
        variables: variables, baseUrl: baseUrl);
    final authorRaw = await parseRuleAsync(html, rule.author,
        variables: variables, baseUrl: baseUrl);
    final kindRaw = await parseRuleAsync(html, rule.kind,
        variables: variables, baseUrl: baseUrl);

    // 处理 name、author、kind：trim 并清理 HTML 标签（如果存在）
    final name = nameRaw?.trim();
    final author = authorRaw?.trim();
    String? kind = kindRaw?.trim();
    // 如果 kind 包含 HTML 标签，清理它们（参考项目：kind 字段应该只包含纯文本）
    if (kind != null && kind.isNotEmpty && kind.contains('<')) {
      kind = HtmlParser.cleanHtml(kind).trim();
    }

    // 添加调试日志
    AppLog.instance.put(
        'parseBookInfoRule: 解析结果 - name=$name, author=$author, kind=$kind, kind规则=${rule.kind}');

    return {
      'name': name,
      'author': author,
      'kind': kind,
      'wordCount': await parseRuleAsync(html, rule.wordCount,
          variables: variables, baseUrl: baseUrl),
      'lastChapter': await parseRuleAsync(html, rule.lastChapter,
          variables: variables, baseUrl: baseUrl),
      'intro': await parseRuleAsync(html, rule.intro,
          variables: variables, baseUrl: baseUrl),
      'coverUrl': await parseRuleAsync(html, rule.coverUrl,
          variables: variables, baseUrl: baseUrl, isUrl: true),
      'tocUrl': await parseRuleAsync(html, rule.tocUrl,
          variables: variables, baseUrl: baseUrl, isUrl: true),
      'canReName': await parseRuleAsync(html, rule.canReName,
          variables: variables, baseUrl: baseUrl), // 用于判断书籍是否可以重命名
    };
  }

  /// 解析章节列表规则
  /// 参考项目：BookChapterList.analyzeChapterList
  /// 注意：preUpdateJs 应该在调用此方法之前执行，但为了兼容性，这里也检查并执行
  static List<Map<String, String?>> parseTocRule(
    String html,
    TocRule? rule, {
    Map<String, String>? variables,
    String? baseUrl,
  }) {
    if (rule == null || rule.chapterList == null) {
      AppLog.instance.put('parseTocRule: 规则为空或chapterList为空');
      return [];
    }

    // 参考项目：preUpdateJs 在解析目录前执行（虽然参考项目中没有明确显示，但根据字段名推测）
    // 注意：这里使用同步方法，因为 parseTocRule 是同步的
    // 如果 preUpdateJs 需要异步执行，应该在调用 parseTocRule 之前执行
    // 但为了确保兼容性，这里先不执行（因为同步方法无法执行异步JS）

    // 对于chapterList，需要返回HTML内容（returnHtml=true），以便后续解析子元素
    final chapterListHtml = parseListRule(html, rule.chapterList,
        variables: variables, baseUrl: baseUrl, returnHtml: true);

    AppLog.instance.put(
        'parseTocRule: 解析chapterList规则，找到 ${chapterListHtml.length} 个章节元素');

    if (chapterListHtml.isEmpty) {
      AppLog.instance.put('parseTocRule: 警告 - chapterList规则未匹配到任何元素');
      AppLog.instance.put('parseTocRule: 规则=${rule.chapterList}');
    } else {
      // 输出前几个元素的HTML，用于调试
      final sampleCount =
          chapterListHtml.length > 3 ? 3 : chapterListHtml.length;
      for (int i = 0; i < sampleCount; i++) {
        final htmlPreview = chapterListHtml[i].length > 200
            ? chapterListHtml[i].substring(0, 200)
            : chapterListHtml[i];
        AppLog.instance
            .put('parseTocRule: 章节元素 ${i + 1} HTML（前200字符）: $htmlPreview');
      }
    }

    final results = <Map<String, String?>>[];

    for (int i = 0; i < chapterListHtml.length; i++) {
      final chapterHtml = chapterListHtml[i];

      // 参考项目：先解析所有字段
      // 参考项目：getString 在规则为空时返回空字符串，而不是 null
      // 参考项目：getString0 会先获取列表再取第一个元素
      // 注意：参考项目的 getString 返回 String（非空），当前项目返回 String?（可空）
      // 为了保持一致，将 null 转换为空字符串
      final chapterName = parseRule(chapterHtml, rule.chapterName,
              variables: variables, baseUrl: baseUrl) ??
          '';
      final chapterUrl = parseRule(chapterHtml, rule.chapterUrl,
              variables: variables, baseUrl: baseUrl, isUrl: true) ??
          '';
      final isVip = parseRule(chapterHtml, rule.isVip,
              variables: variables, baseUrl: baseUrl) ??
          '';
      final isVolumeStr = parseRule(chapterHtml, rule.isVolume,
              variables: variables, baseUrl: baseUrl) ??
          '';
      final updateTime = parseRule(chapterHtml, rule.updateTime,
              variables: variables, baseUrl: baseUrl) ??
          '';
      final nextTocUrl = parseRule(chapterHtml, rule.nextTocUrl,
              variables: variables, baseUrl: baseUrl, isUrl: true) ??
          '';

      // 判断是否是卷名（参考项目逻辑）
      // isVolume 规则如果返回非空值（通常是 "true"、"1" 或非空字符串），则认为是卷名
      final isVolume = isVolumeStr.isNotEmpty &&
          (isVolumeStr.toLowerCase() == 'true' ||
              isVolumeStr == '1' ||
              isVolumeStr.trim().isNotEmpty);

      // 参考项目：如果 chapterUrl 为空，根据情况设置默认值
      String? finalChapterUrl = chapterUrl;
      if (finalChapterUrl.isEmpty) {
        // 参考项目逻辑：
        // 1. 如果是卷名（isVolume），URL 可以为空（卷名不需要链接）
        // 2. 如果不是卷名且URL为空，使用baseUrl作为默认值
        if (!isVolume) {
          finalChapterUrl = baseUrl;
          AppLog.instance
              .put('parseTocRule: 章节 ${i + 1} 未获取到URL，使用baseUrl: $baseUrl');
        } else {
          // 卷名不需要URL，设置为空字符串或null
          finalChapterUrl = null;
          AppLog.instance.put('parseTocRule: 章节 ${i + 1} 是卷名，URL为空');
        }
      }

      // 参考项目：只添加 title.isNotEmpty 的章节
      // 注意：参考项目会检查 title.isNotEmpty，即使 URL 为空也会添加（使用 baseUrl）
      // 对于卷名，即使没有URL也会添加
      if (chapterName.isNotEmpty) {
        results.add({
          'chapterName': chapterName,
          'chapterUrl': finalChapterUrl,
          'isVip': isVip,
          'isVolume': isVolume ? '1' : '0', // 转换为字符串格式，与数据库存储一致
          'updateTime': updateTime,
          'nextTocUrl': nextTocUrl,
        });
      } else {
        // 如果既没有URL也没有标题，记录警告
        AppLog.instance.put(
            'parseTocRule: 章节 ${i + 1} 无标题，跳过。HTML: ${chapterHtml.substring(0, chapterHtml.length > 100 ? 100 : chapterHtml.length)}');
      }
    }

    AppLog.instance.put(
        'parseTocRule: 最终返回 ${results.length} 个有效章节（从 ${chapterListHtml.length} 个元素中解析）');

    return results;
  }

  /// 解析章节列表规则，并返回章节列表和下一页URL列表
  /// 参考项目：BookChapterList.analyzeChapterList (私有方法)
  /// 返回：Pair<List<Map<String, String?>>, List<String>> (章节列表, 下一页URL列表)
  static Map<String, dynamic> parseTocRuleWithNextUrl(
    String html,
    TocRule? rule, {
    Map<String, String>? variables,
    String? baseUrl,
    bool getNextUrl = true,
  }) {
    // 先解析章节列表
    final chapterList = parseTocRule(
      html,
      rule,
      variables: variables,
      baseUrl: baseUrl,
    );

    // 获取下一页URL列表
    final nextUrlList = <String>[];
    if (getNextUrl &&
        rule?.nextTocUrl != null &&
        rule!.nextTocUrl!.isNotEmpty) {
      AppLog.instance.put('parseTocRuleWithNextUrl: 获取目录下一页列表');

      // 参考项目：使用 getStringList(nextTocRule, isUrl = true) 获取URL列表
      // 检查规则是否包含属性选择器（@href, @src等）
      if (rule.nextTocUrl!.contains('@')) {
        // 规则包含属性选择器，直接使用parseListRule获取属性值
        final urls = parseListRule(
          html,
          rule.nextTocUrl!,
          variables: variables,
          baseUrl: baseUrl,
          returnHtml: false, // 获取属性值（URL）
        );
        nextUrlList.addAll(urls);
      } else {
        // 规则不包含属性选择器，需要先获取HTML，然后提取href
        final linkHtmlList = parseListRule(
          html,
          rule.nextTocUrl!,
          variables: variables,
          baseUrl: baseUrl,
          returnHtml: true, // 获取HTML内容
        );

        // 从HTML中提取href属性
        for (final linkHtml in linkHtmlList) {
          final hrefPattern = RegExp(
            'href\\s*=\\s*["\']([^"\']+)["\']',
            caseSensitive: false,
          );
          final match = hrefPattern.firstMatch(linkHtml);
          if (match != null) {
            final href = match.group(1);
            if (href != null && href.isNotEmpty) {
              nextUrlList.add(href);
            }
          }
        }
      }

      // 过滤掉与当前URL相同的URL，并拼接完整URL
      final filteredUrls = nextUrlList
          .where((url) => url.isNotEmpty && url != baseUrl)
          .map((url) {
            try {
              return NetworkService.joinUrl(baseUrl ?? '', url);
            } catch (e) {
              AppLog.instance
                  .put('parseTocRuleWithNextUrl: 拼接URL失败: $url, 错误: $e');
              return url;
            }
          })
          .where((url) => url != baseUrl && url.isNotEmpty)
          .toList();

      nextUrlList.clear();
      nextUrlList.addAll(filteredUrls);

      AppLog.instance
          .put('parseTocRuleWithNextUrl: 找到 ${nextUrlList.length} 个下一页URL');
      for (int i = 0; i < nextUrlList.length; i++) {
        AppLog.instance.put('  下一页URL ${i + 1}: ${nextUrlList[i]}');
      }
    }

    return {
      'chapterList': chapterList,
      'nextUrlList': nextUrlList,
    };
  }

  /// 解析正文内容规则
  /// [applyReplaceRegex] 是否应用replaceRegex规则，默认为true
  /// 参考项目：replaceRegex是在所有页面内容合并后统一应用的，而不是每页单独应用
  static Future<String?> parseContentRule(
    String html,
    ContentRule? rule, {
    Map<String, String>? variables,
    String? baseUrl,
    String? bookName,
    String? bookOrigin,
    bool applyReplaceRegex = true,
  }) async {
    if (rule == null || rule.content == null) {
      AppLog.instance.put('parseContentRule: 规则为空或content为空');
      return null;
    }

    try {
      AppLog.instance.put('parseContentRule: 开始解析，content规则=${rule.content}');
      AppLog.instance.put('parseContentRule: HTML长度=${html.length}');

      // 执行网页 JavaScript（如果有）
      if (rule.webJs != null && rule.webJs!.isNotEmpty) {
        AppLog.instance.put('parseContentRule: 执行webJs');
        html =
            await _executeJs(html, rule.webJs!, variables: variables) ?? html;
      }

      // 提取正文内容
      // 参考项目：使用 unescape = false，先获取HTML内容，然后再处理转义
      String? content = await parseRuleAsync(html, rule.content,
          variables: variables, baseUrl: baseUrl);
      AppLog.instance
          .put('parseContentRule: parseRule返回结果长度=${content?.length ?? 0}');

      // 如果原始规则失败，尝试智能降级（类似目录获取的降级机制）
      if (content == null || content.isEmpty) {
        AppLog.instance.put('parseContentRule: 警告 - content规则未匹配到任何内容，尝试智能降级');
        AppLog.instance.put('parseContentRule: 规则=${rule.content}');

        // 检查HTML中是否有常见的content容器
        // 参考目录获取的降级机制：动态查找内容容器
        final contentPattern = RegExp(
            'id\\s*=\\s*["\']([^"\']*content[^"\']*)["\']',
            caseSensitive: false);
        final contentMatches = contentPattern.allMatches(html);
        final contentIds = contentMatches
            .map((m) => m.group(1))
            .whereType<String>()
            .take(10)
            .toList();
        if (contentIds.isNotEmpty) {
          AppLog.instance.put(
              'parseContentRule: HTML中找到包含"content"的id: ${contentIds.join(", ")}');
        }

        final contentClassPattern = RegExp(
            'class\\s*=\\s*["\']([^"\']*content[^"\']*)["\']',
            caseSensitive: false);
        final contentClassMatches = contentClassPattern.allMatches(html);
        final contentClassesList = <String>[];
        for (final match in contentClassMatches) {
          final classAttr = match.group(1);
          if (classAttr != null) {
            final classes = classAttr.split(RegExp(r'\s+'));
            for (final cls in classes) {
              if (cls.contains('content') &&
                  !contentClassesList.contains(cls)) {
                contentClassesList.add(cls);
              }
            }
          }
        }
        final contentClasses = contentClassesList.take(10).toList();
        if (contentClasses.isNotEmpty) {
          AppLog.instance.put(
              'parseContentRule: HTML中找到包含"content"的class: ${contentClasses.join(", ")}');
        }

        // 尝试查找其他可能的内容容器（如nr1, text, article等）
        final otherIdPattern = RegExp(
            'id\\s*=\\s*["\']([^"\']*(?:nr|text|article|main|body|read|book)[^"\']*)["\']',
            caseSensitive: false);
        final otherIdMatches = otherIdPattern.allMatches(html);
        final otherIds = otherIdMatches
            .map((m) => m.group(1))
            .whereType<String>()
            .take(10)
            .toList();
        if (otherIds.isNotEmpty) {
          AppLog.instance.put(
              'parseContentRule: HTML中找到其他可能的内容容器id: ${otherIds.join(", ")}');
        }

        final otherClassPattern = RegExp(
            'class\\s*=\\s*["\']([^"\']*(?:nr|text|article|main|body|read|book)[^"\']*)["\']',
            caseSensitive: false);
        final otherClassMatches = otherClassPattern.allMatches(html);
        final otherClassesList = <String>[];
        for (final match in otherClassMatches) {
          final classAttr = match.group(1);
          if (classAttr != null) {
            final classes = classAttr.split(RegExp(r'\s+'));
            for (final cls in classes) {
              if ((cls.contains('nr') ||
                      cls.contains('text') ||
                      cls.contains('article') ||
                      cls.contains('main') ||
                      cls.contains('body') ||
                      cls.contains('read') ||
                      cls.contains('book')) &&
                  !otherClassesList.contains(cls) &&
                  !contentClassesList.contains(cls)) {
                otherClassesList.add(cls);
              }
            }
          }
        }
        final otherClasses = otherClassesList.take(10).toList();
        if (otherClasses.isNotEmpty) {
          AppLog.instance.put(
              'parseContentRule: HTML中找到其他可能的内容容器class: ${otherClasses.join(", ")}');
        }

        // 尝试常见的content容器选择器
        final fallbackRules = <String>[];

        // 优先尝试找到的包含"content"的ID和class
        for (final id in contentIds) {
          fallbackRules.add('id.$id@html');
          fallbackRules.add('id.$id@text');
        }
        for (final cls in contentClasses) {
          fallbackRules.add('class.$cls@html');
          fallbackRules.add('class.$cls@text');
        }

        // 然后尝试其他可能的内容容器
        for (final id in otherIds) {
          fallbackRules.add('id.$id@html');
          fallbackRules.add('id.$id@text');
        }
        for (final cls in otherClasses) {
          fallbackRules.add('class.$cls@html');
          fallbackRules.add('class.$cls@text');
        }

        // 最后尝试常见的正文容器（即使没有找到）
        fallbackRules.addAll([
          'id.content@html',
          'id.content@text',
          'class.content@html',
          'class.content@text',
          'id.nr1@html',
          'id.nr1@text',
          'class.nr1@html',
          'class.nr1@text',
          'id.text@html',
          'id.text@text',
          'class.text@html',
          'class.text@text',
          'div.content@html',
          'div.content@text',
          'div#content@html',
          'div#content@text',
        ]);

        // 尝试每个降级规则
        for (final fallbackRule in fallbackRules) {
          AppLog.instance.put('parseContentRule: 尝试降级规则: $fallbackRule');
          final fallbackContent = parseRule(html, fallbackRule,
              variables: variables, baseUrl: baseUrl);
          if (fallbackContent != null && fallbackContent.isNotEmpty) {
            AppLog.instance.put(
                'parseContentRule: 降级规则 $fallbackRule 匹配成功，内容长度=${fallbackContent.length}');
            content = fallbackContent;
            break;
          }
        }

        if (content == null || content.isEmpty) {
          AppLog.instance.put('parseContentRule: 所有降级规则都失败');
          // 输出HTML的前1000字符用于调试
          AppLog.instance.put(
              'parseContentRule: HTML前1000字符: ${html.substring(0, html.length > 1000 ? 1000 : html.length)}');
          return null;
        }
      }

      // 此时 content 已确定不为 null 且不为空（前面已经检查过）
      // 编译器已识别 content 不为 null，直接使用
      String processedContent = content;

      AppLog.instance
          .put('parseContentRule: 提取到内容，长度=${processedContent.length}');

      // 应用 sourceRegex 规则（如果存在，在清理HTML之前应用）
      // 参考项目：sourceRegex 用于从HTML中提取特定内容，通常在清理HTML之前应用
      final sourceRegexValue = rule.sourceRegex;
      if (sourceRegexValue != null && sourceRegexValue.isNotEmpty) {
        try {
          AppLog.instance
              .put('parseContentRule: 应用sourceRegex规则: $sourceRegexValue');
          final regex = RegExp(sourceRegexValue, multiLine: true);
          final matches = regex.allMatches(processedContent);
          if (matches.isNotEmpty) {
            // 提取所有匹配的内容
            final extractedContent =
                matches.map((m) => m.group(0) ?? '').join('\n');
            if (extractedContent.isNotEmpty) {
              processedContent = extractedContent;
              AppLog.instance.put(
                  'parseContentRule: sourceRegex提取后，内容长度=${processedContent.length}');
            }
          }
        } catch (e) {
          AppLog.instance.put(
              'parseContentRule: sourceRegex规则错误: $sourceRegexValue',
              error: e);
        }
      }

      // 参考项目：HtmlFormatter.formatKeepImg(content, rUrl)
      // 格式化图片URL，确保图片URL是绝对URL
      // 参考项目：formatKeepImg 会处理图片的src属性，确保是绝对URL
      if (baseUrl != null && baseUrl.isNotEmpty) {
        // 匹配img标签，支持单引号和双引号
        final imgPattern1 = RegExp(r'<img([^>]*?)src=["]([^"]*?)"([^>]*?)>',
            caseSensitive: false);
        final imgPattern2 = RegExp(r"<img([^>]*?)src=[']([^']*?)'([^>]*?)>",
            caseSensitive: false);

        processedContent =
            processedContent.replaceAllMapped(imgPattern1, (match) {
          final beforeSrc = match.group(1) ?? '';
          final imgSrc = match.group(2) ?? '';
          final afterSrc = match.group(3) ?? '';

          // 如果是相对URL，转换为绝对URL
          String absoluteSrc = imgSrc;
          if (imgSrc.isNotEmpty &&
              !imgSrc.startsWith('http') &&
              !imgSrc.startsWith('data:')) {
            absoluteSrc = NetworkService.joinUrl(baseUrl, imgSrc);
          }

          return '<img$beforeSrc src="$absoluteSrc"$afterSrc>';
        });

        processedContent =
            processedContent.replaceAllMapped(imgPattern2, (match) {
          final beforeSrc = match.group(1) ?? '';
          final imgSrc = match.group(2) ?? '';
          final afterSrc = match.group(3) ?? '';

          // 如果是相对URL，转换为绝对URL
          String absoluteSrc = imgSrc;
          if (imgSrc.isNotEmpty &&
              !imgSrc.startsWith('http') &&
              !imgSrc.startsWith('data:')) {
            absoluteSrc = NetworkService.joinUrl(baseUrl, imgSrc);
          }

          return "<img$beforeSrc src='$absoluteSrc'$afterSrc>";
        });

        AppLog.instance
            .put('parseContentRule: 格式化图片URL后，内容长度=${processedContent.length}');
      }

      // 参考项目：如果内容包含 &，进行HTML解码
      // 参考项目：if (content.indexOf('&') > -1) { content = StringEscapeUtils.unescapeHtml4(content) }
      if (processedContent.contains('&')) {
        // #region agent log
        final ampCount = '&'.allMatches(processedContent).length;
        final entities = <String, int>{};
        for (final entity in [
          '&amp;',
          '&lt;',
          '&gt;',
          '&quot;',
          '&#39;',
          '&nbsp;',
          '&mdash;',
          '&ldquo;',
          '&rdquo;',
          '&copy;'
        ]) {
          final count = entity.allMatches(processedContent).length;
          if (count > 0) entities[entity] = count;
        }
        try {
          final f = File(
              '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
          f.writeAsStringSync(
              '${jsonEncode({
                    "location": "rule_parser.dart:2246",
                    "message": "HTML实体解码前",
                    "data": {
                      "ampCount": ampCount,
                      "entities": entities,
                      "contentLength": processedContent.length
                    },
                    "timestamp": DateTime.now().millisecondsSinceEpoch,
                    "sessionId": "debug-session",
                    "hypothesisId": "B"
                  })}\n',
              mode: FileMode.append);
        } catch (_) {}
        // #endregion

        // 使用HTML解析器解码HTML实体
        // 注意：这里只解码常见的HTML实体，如 &amp; -> &, &lt; -> <, &gt; -> >
        final beforeLength = processedContent.length;
        processedContent = processedContent
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&nbsp;', ' ');
        // 处理数字实体，如 &#123; 或 &#x1F;
        processedContent =
            processedContent.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          final code = int.tryParse(match.group(1) ?? '');
          if (code != null) {
            return String.fromCharCode(code);
          }
          return match.group(0) ?? '';
        });
        processedContent = processedContent
            .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
          final code = int.tryParse(match.group(1) ?? '', radix: 16);
          if (code != null) {
            return String.fromCharCode(code);
          }
          return match.group(0) ?? '';
        });

        // #region agent log
        final remainingAmpCount = '&'.allMatches(processedContent).length;
        final changedLength = beforeLength - processedContent.length;
        try {
          final f = File(
              '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
          f.writeAsStringSync(
              '${jsonEncode({
                    "location": "rule_parser.dart:2284",
                    "message": "HTML实体解码后",
                    "data": {
                      "remainingAmpCount": remainingAmpCount,
                      "changedLength": changedLength,
                      "contentLength": processedContent.length
                    },
                    "timestamp": DateTime.now().millisecondsSinceEpoch,
                    "sessionId": "debug-session",
                    "hypothesisId": "B"
                  })}\n',
              mode: FileMode.append);
        } catch (_) {}
        // #endregion

        AppLog.instance
            .put('parseContentRule: HTML解码后，内容长度=${processedContent.length}');
      }

      // 应用 imageStyle 规则（如果存在，在清理HTML之前应用）
      // 参考项目：imageStyle 用于设置图片样式，如宽度、高度等
      final imageStyleValue = rule.imageStyle;
      if (imageStyleValue != null && imageStyleValue.isNotEmpty) {
        try {
          AppLog.instance
              .put('parseContentRule: 应用imageStyle规则: $imageStyleValue');
          // imageStyle 规则应该是一个CSS样式字符串，应用到所有img标签
          final imgPattern = RegExp(r'<img([^>]*)>', caseSensitive: false);
          processedContent =
              processedContent.replaceAllMapped(imgPattern, (match) {
            final imgAttrs = match.group(1) ?? '';
            // 检查是否已经有style属性
            if (imgAttrs.contains('style=')) {
              // 如果已有style，追加新的样式
              return '<img$imgAttrs style="$imgAttrs;$imageStyleValue">';
            } else {
              // 如果没有style，添加新的样式
              return '<img$imgAttrs style="$imageStyleValue">';
            }
          });
          AppLog.instance.put(
              'parseContentRule: 应用imageStyle后，内容长度=${processedContent.length}');
        } catch (e) {
          AppLog.instance.put(
              'parseContentRule: imageStyle规则错误: $imageStyleValue',
              error: e);
        }
      }

      // #region agent log
      final imgBeforeClean = RegExp(r'<img[^>]*>', caseSensitive: false)
          .allMatches(processedContent)
          .length;
      final contentPreviewBeforeClean = processedContent.length > 200
          ? processedContent.substring(0, 200)
          : processedContent;
      try {
        final f = File(
            '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
        f.writeAsStringSync(
            '${jsonEncode({
                  "location": "rule_parser.dart:2321",
                  "message": "cleanHtml前",
                  "data": {
                    "imgCount": imgBeforeClean,
                    "contentLength": processedContent.length,
                    "contentPreview": contentPreviewBeforeClean
                  },
                  "timestamp": DateTime.now().millisecondsSinceEpoch,
                  "sessionId": "debug-session",
                  "hypothesisId": "C"
                })}\n',
            mode: FileMode.append);
      } catch (_) {}
      // #endregion

      processedContent = HtmlParser.cleanHtml(processedContent);

      // #region agent log
      final imgAfterClean = RegExp(r'<img[^>]*>', caseSensitive: false)
          .allMatches(processedContent)
          .length;
      final contentPreviewAfterClean = processedContent.length > 200
          ? processedContent.substring(0, 200)
          : processedContent;
      try {
        final f = File(
            '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
        f.writeAsStringSync(
            '${jsonEncode({
                  "location": "rule_parser.dart:2330",
                  "message": "cleanHtml后",
                  "data": {
                    "imgCount": imgAfterClean,
                    "imgRemoved": imgBeforeClean - imgAfterClean,
                    "contentLength": processedContent.length,
                    "contentPreview": contentPreviewAfterClean
                  },
                  "timestamp": DateTime.now().millisecondsSinceEpoch,
                  "sessionId": "debug-session",
                  "hypothesisId": "C"
                })}\n',
            mode: FileMode.append);
      } catch (_) {}
      // #endregion

      // 应用正则替换（书源规则中的替换）
      // 参考项目：replaceRegex是在所有页面内容合并后统一应用的，而不是每页单独应用
      // 如果applyReplaceRegex为false，跳过此步骤（在合并后统一处理）
      if (applyReplaceRegex &&
          rule.replaceRegex != null &&
          rule.replaceRegex!.isNotEmpty) {
        // 参考项目逻辑：先将内容按行分割并trim，应用替换规则，然后在每行前添加全角空格
        // 按行分割并trim每行
        final lines = processedContent.split('\n');
        processedContent = lines.map((line) => line.trim()).join('\n');

        // 应用replaceRegex规则
        processedContent =
            _applyReplaceRegexInternal(processedContent, rule.replaceRegex!);

        // 按行分割并在每行前添加全角空格（段落缩进）
        final processedLines = processedContent.split('\n');
        processedContent = processedLines.map((line) => '　　$line').join('\n');

        AppLog.instance.put(
            'parseContentRule: 应用replaceRegex后，内容长度=${processedContent.length}');
      }

      // 清理多余空白
      processedContent = _cleanWhitespace(processedContent);

      // 应用全局替换规则（净化替换规则）
      // 如果提供了书籍信息，使用作用范围过滤规则
      try {
        List<ReplaceRule>? rules;
        if (bookName != null && bookOrigin != null) {
          rules =
              await ReplaceRuleService.instance.getEnabledRulesByContentScope(
            bookName,
            bookOrigin,
          );
        }
        if (rules != null && rules.isNotEmpty) {
          AppLog.instance.put('parseContentRule: 应用 ${rules.length} 个全局替换规则');
          processedContent = await ReplaceRuleService.instance
              .applyRules(processedContent, rules: rules);
          AppLog.instance.put(
              'parseContentRule: 应用全局替换规则后，内容长度=${processedContent.length}');
        }
      } catch (e) {
        // 如果应用替换规则失败，继续使用原始内容
        AppLog.instance.put('parseContentRule: 应用全局替换规则失败', error: e);
      }

      return processedContent;
    } catch (e) {
      return null;
    }
  }

  /// 应用正则替换规则（公开方法，供外部调用）
  /// 支持格式：##match##replace 或 ##match##replace###（只替换第一个）
  static String applyReplaceRegex(String content, String replaceRule) {
    return _applyReplaceRegexInternal(content, replaceRule);
  }

  /// 处理替换字符串中的分组引用（$1, $2等）
  /// 参考项目：正则替换中的分组引用
  static String _processReplacementGroups(
      String replacement, RegExpMatch match) {
    String result = replacement;
    // 替换$1, $2等分组引用
    final groupPattern = RegExp(r'\$(\d{1,2})');
    result = result.replaceAllMapped(groupPattern, (m) {
      final groupIndex = int.tryParse(m.group(1) ?? '0') ?? 0;
      if (groupIndex > 0 && groupIndex <= match.groupCount) {
        return match.group(groupIndex) ?? '';
      }
      return m.group(0) ?? '';
    });
    return result;
  }

  /// 应用正则替换规则（内部实现）
  /// 参考项目：AnalyzeRule.replaceRegex
  /// 支持格式：
  /// - sourceRegex@replaceRegex：替换所有匹配
  /// - ##match##replace：替换所有匹配
  /// - ##match##replace###：只替换第一个匹配
  /// 支持分组引用：$1, $2等在replacement中使用
  static String _applyReplaceRegexInternal(String content, String replaceRule) {
    if (replaceRule.isEmpty) return content;

    // #region agent log
    try {
      final f =
          File('/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
      f.writeAsStringSync(
          '${jsonEncode({
                "location": "rule_parser.dart:2386",
                "message": "replaceRegex入口",
                "data": {
                  "replaceRule": replaceRule,
                  "contentLength": content.length,
                  "contentPreview": content.substring(
                      0, content.length > 100 ? 100 : content.length)
                },
                "timestamp": DateTime.now().millisecondsSinceEpoch,
                "sessionId": "debug-session",
                "hypothesisId": "A"
              })}\n',
          mode: FileMode.append);
    } catch (_) {}
    // #endregion

    try {
      String sourceRegex;
      String replacement;
      bool replaceFirst = false;

      // 检查是否是 ##match##replace 格式
      if (replaceRule.contains('##')) {
        final parts = replaceRule.split('##');
        if (parts.length >= 3) {
          sourceRegex = parts[1];
          replacement = parts[2];
          // 如果有第四个部分（###），表示只替换第一个
          if (parts.length > 3 && parts[3].isNotEmpty) {
            replaceFirst = true;
          }
        } else {
          // 格式错误，返回原内容
          // #region agent log
          try {
            final f = File(
                '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
            f.writeAsStringSync(
                '${jsonEncode({
                      "location": "rule_parser.dart:2410",
                      "message": "replaceRegex格式错误-##格式",
                      "data": {
                        "replaceRule": replaceRule,
                        "partsLength": parts.length
                      },
                      "timestamp": DateTime.now().millisecondsSinceEpoch,
                      "sessionId": "debug-session",
                      "hypothesisId": "A"
                    })}\n',
                mode: FileMode.append);
          } catch (_) {}
          // #endregion
          return content;
        }
      } else if (replaceRule.contains('@')) {
        // 旧格式：sourceRegex@replaceRegex
        final parts = replaceRule.split('@');
        if (parts.length != 2) return content;
        sourceRegex = parts[0];
        replacement = parts[1];
      } else {
        // 格式错误，返回原内容
        return content;
      }

      // #region agent log
      try {
        final f = File(
            '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
        f.writeAsStringSync(
            '${jsonEncode({
                  "location": "rule_parser.dart:2429",
                  "message": "replaceRegex解析完成",
                  "data": {
                    "sourceRegex": sourceRegex,
                    "replacement": replacement,
                    "replaceFirst": replaceFirst
                  },
                  "timestamp": DateTime.now().millisecondsSinceEpoch,
                  "sessionId": "debug-session",
                  "hypothesisId": "A"
                })}\n',
            mode: FileMode.append);
      } catch (_) {}
      // #endregion

      // 编译正则表达式
      RegExp pattern;
      try {
        pattern = RegExp(sourceRegex, multiLine: true);
      } catch (e) {
        // #region agent log
        try {
          final f = File(
              '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
          f.writeAsStringSync(
              '${jsonEncode({
                    "location": "rule_parser.dart:2441",
                    "message": "replaceRegex正则编译失败",
                    "data": {"sourceRegex": sourceRegex, "error": e.toString()},
                    "timestamp": DateTime.now().millisecondsSinceEpoch,
                    "sessionId": "debug-session",
                    "hypothesisId": "A"
                  })}\n',
              mode: FileMode.append);
        } catch (_) {}
        // #endregion
        AppLog.instance
            .put('_applyReplaceRegexInternal: 正则表达式错误: $sourceRegex, 错误: $e');
        return content;
      }

      // 应用替换（支持$1, $2等分组引用）
      if (replaceFirst) {
        // 只替换第一个匹配
        final match = pattern.firstMatch(content);
        if (match != null) {
          final matchedText = match.group(0)!;
          // 处理分组引用（$1, $2等）
          String processedReplacement =
              _processReplacementGroups(replacement, match);
          final replaced =
              matchedText.replaceFirst(pattern, processedReplacement);
          // #region agent log
          try {
            final f = File(
                '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
            f.writeAsStringSync(
                '${jsonEncode({
                      "location": "rule_parser.dart:2462",
                      "message": "replaceRegex替换第一个匹配",
                      "data": {
                        "matchedText": matchedText,
                        "processedReplacement": processedReplacement
                      },
                      "timestamp": DateTime.now().millisecondsSinceEpoch,
                      "sessionId": "debug-session",
                      "hypothesisId": "A"
                    })}\n',
                mode: FileMode.append);
          } catch (_) {}
          // #endregion
          return content.replaceFirst(matchedText, replaced);
        }
        return content;
      } else {
        // 替换所有匹配（支持分组引用）
        var matchCount = 0;
        final result = content.replaceAllMapped(pattern, (match) {
          matchCount++;
          if (match is RegExpMatch) {
            final processed = _processReplacementGroups(replacement, match);
            // #region agent log
            if (matchCount <= 3) {
              try {
                final f = File(
                    '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
                f.writeAsStringSync(
                    '${jsonEncode({
                          "location": "rule_parser.dart:2479",
                          "message": "replaceRegex替换匹配项",
                          "data": {
                            "matchIndex": matchCount,
                            "matched": match.group(0),
                            "processed": processed
                          },
                          "timestamp": DateTime.now().millisecondsSinceEpoch,
                          "sessionId": "debug-session",
                          "hypothesisId": "A"
                        })}\n',
                    mode: FileMode.append);
              } catch (_) {}
            }
            // #endregion
            return processed;
          }
          return replacement;
        });
        // #region agent log
        try {
          final f = File(
              '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
          f.writeAsStringSync(
              '${jsonEncode({
                    "location": "rule_parser.dart:2491",
                    "message": "replaceRegex完成",
                    "data": {
                      "totalMatches": matchCount,
                      "originalLength": content.length,
                      "resultLength": result.length
                    },
                    "timestamp": DateTime.now().millisecondsSinceEpoch,
                    "sessionId": "debug-session",
                    "hypothesisId": "A"
                  })}\n',
              mode: FileMode.append);
        } catch (_) {}
        // #endregion
        return result;
      }
    } catch (e) {
      // #region agent log
      try {
        final f = File(
            '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
        f.writeAsStringSync(
            '${jsonEncode({
                  "location": "rule_parser.dart:2500",
                  "message": "replaceRegex异常",
                  "data": {"error": e.toString()},
                  "timestamp": DateTime.now().millisecondsSinceEpoch,
                  "sessionId": "debug-session",
                  "hypothesisId": "A"
                })}\n',
            mode: FileMode.append);
      } catch (_) {}
      // #endregion
      AppLog.instance.put('_applyReplaceRegexInternal: 替换失败: $e');
      return content;
    }
  }

  /// 清理多余空白
  static String _cleanWhitespace(String text) {
    // 参考项目：清理多余空白，但保留换行符
    // 将多个连续空格/制表符替换为单个空格（但保留换行符）
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    // 移除行首行尾空白（但保留换行符）
    text = text.replaceAll(RegExp(r'^[ \t]+|[ \t]+$', multiLine: true), '');
    // 移除多余空行（连续多个换行符合并为一个）
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // 移除行首行尾的空白（包括换行符），但保留内容中的换行符
    return text.trim();
  }

  /// 解析JSONPath规则
  /// 参考项目：AnalyzeByJSonPath
  static String? _parseJsonPath(
    String html,
    String rule,
    String? baseUrl, {
    bool isUrl = false,
  }) {
    try {
      // 移除 @Json: 前缀
      if (rule.startsWith('@Json:') || rule.startsWith('@json:')) {
        rule = rule.substring(6).trim();
      }

      // 尝试解析HTML为JSON
      // 注意：这里需要判断HTML是否实际上是JSON
      dynamic jsonData;
      try {
        // 先尝试直接解析为JSON
        jsonData = jsonDecode(html);
      } catch (e) {
        // 如果不是JSON，尝试从HTML中提取JSON
        // 查找 <script> 标签中的JSON数据
        final scriptPattern =
            RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true);
        final matches = scriptPattern.allMatches(html);
        for (final match in matches) {
          final scriptContent = match.group(1)?.trim() ?? '';
          if (scriptContent.startsWith('{') || scriptContent.startsWith('[')) {
            try {
              jsonData = jsonDecode(scriptContent);
              break;
            } catch (e) {
              // 继续尝试下一个
            }
          }
        }
      }

      if (jsonData == null) {
        AppLog.instance.put('_parseJsonPath: 无法解析为JSON');
        return null;
      }

      // 使用json_path包解析JSONPath
      try {
        final jsonPath = JsonPath(rule);
        final results = jsonPath.readValues(jsonData);

        if (results.isEmpty) {
          AppLog.instance.put('_parseJsonPath: JSONPath未找到匹配结果: $rule');
          return null;
        }

        // 如果只有一个结果，返回字符串
        if (results.length == 1) {
          final value = results.first;
          if (value == null) return null;
          return value.toString();
        }

        // 多个结果，用换行符连接
        return results
            .map((v) => v?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .join('\n');
      } catch (e) {
        AppLog.instance.put('_parseJsonPath: JSONPath解析失败: $rule, 错误: $e');
        return null;
      }
    } catch (e) {
      AppLog.instance.put('_parseJsonPath: 解析失败: $e');
      return null;
    }
  }

  /// 执行 JavaScript 代码（公开方法，供外部调用）
  /// 参考项目：AnalyzeRule.evalJS
  ///
  /// 用于执行webJs、preUpdateJs等JavaScript代码
  static Future<String?> executeJs(
    String html,
    String jsCode, {
    Map<String, String>? variables,
    BookSource? source,
    Book? book,
    String? baseUrl,
    String? chapterTitle,
  }) async {
    return _executeJs(html, jsCode,
        variables: variables,
        source: source,
        book: book,
        baseUrl: baseUrl,
        chapterTitle: chapterTitle);
  }

  /// 执行 JavaScript 代码（内部方法）
  /// 参考项目：AnalyzeRule.evalJS
  ///
  /// 用于执行webJs等JavaScript代码
  static Future<String?> _executeJs(
    String html,
    String jsCode, {
    Map<String, String>? variables,
    BookSource? source,
    Book? book,
    String? baseUrl,
    String? chapterTitle,
  }) async {
    try {
      // 参考项目：evalJS(jsCode, result)
      // 提供全局对象：java, cookie, cache, source, book, result, baseUrl等
      final extensions = JSExtensions(
        source: source,
        book: book,
        baseUrl: baseUrl,
        chapterTitle: chapterTitle,
      );
      final jsBindings = extensions.createBindings();
      jsBindings['result'] = html;

      if (variables != null) {
        jsBindings.addAll(variables);
      }

      final jsResult = await JSEngine.evalJS(jsCode, bindings: jsBindings);
      if (jsResult != null) {
        return jsResult.toString();
      }
      return html;
    } catch (e) {
      AppLog.instance.put('_executeJs: JavaScript执行失败: $e');
      return html;
    }
  }

  /// 设置变量（供外部调用）
  static void setVariable(String key, String value) {
    _variables[key] = value;
  }

  /// 获取变量（供外部调用）
  static String? getVariable(String key) {
    return _variables[key];
  }

  /// 清除所有变量（供外部调用）
  static void clearVariables() {
    _variables.clear();
  }

  /// 解析发现规则
  static Future<List<Map<String, String?>>> parseExploreRule(
    String html,
    ExploreRule? rule, {
    Map<String, String>? variables,
    String? baseUrl,
  }) async {
    if (rule == null || rule.bookList == null) {
      AppLog.instance.put('parseExploreRule: 规则为空或bookList为空');
      return [];
    }

    // 对于bookList，需要返回HTML内容（returnHtml=true），以便后续解析子元素
    AppLog.instance.put(
        'parseExploreRule: 开始解析bookList, 规则=${rule.bookList}, HTML长度=${html.length}');

    final bookListHtml = parseListRule(html, rule.bookList,
        variables: variables, baseUrl: baseUrl, returnHtml: true);

    // 添加日志：如果bookList解析结果为空，记录详细信息
    if (bookListHtml.isEmpty) {
      AppLog.instance.put(
          'parseExploreRule: bookList规则未匹配到任何元素, 规则=${rule.bookList}, HTML长度=${html.length}');
      // 尝试输出HTML的前500个字符，帮助调试
      if (html.isNotEmpty) {
        final preview = html.length > 500 ? html.substring(0, 500) : html;
        AppLog.instance.put('parseExploreRule: HTML预览（前500字符）: $preview');
      }
      return [];
    }

    final results = <Map<String, String?>>[];

    for (int i = 0; i < bookListHtml.length; i++) {
      final bookHtml = bookListHtml[i];

      // 解析bookUrl时使用isUrl=true，参考项目逻辑
      final bookUrl = await parseRuleAsync(bookHtml, rule.bookUrl,
          variables: variables, baseUrl: baseUrl, isUrl: true);
      final nameRaw = await parseRuleAsync(bookHtml, rule.name,
          variables: variables, baseUrl: baseUrl);
      final authorRaw = await parseRuleAsync(bookHtml, rule.author,
          variables: variables, baseUrl: baseUrl);
      // 确保 name、author、kind 进行了 trim 处理
      final name = nameRaw?.trim();
      final author = authorRaw?.trim();
      final kindRaw = await parseRuleAsync(bookHtml, rule.kind,
          variables: variables, baseUrl: baseUrl);
      String? kind = kindRaw?.trim();
      // 如果 kind 包含 HTML 标签，清理它们（参考项目：kind 字段应该只包含纯文本）
      if (kind != null && kind.isNotEmpty && kind.contains('<')) {
        kind = HtmlParser.cleanHtml(kind).trim();
      }
      final wordCount = await parseRuleAsync(bookHtml, rule.wordCount,
          variables: variables, baseUrl: baseUrl);
      final lastChapter = await parseRuleAsync(bookHtml, rule.lastChapter,
          variables: variables, baseUrl: baseUrl);
      final intro = await parseRuleAsync(bookHtml, rule.intro,
          variables: variables, baseUrl: baseUrl);
      final coverUrl = await parseRuleAsync(bookHtml, rule.coverUrl,
          variables: variables, baseUrl: baseUrl);

      // 添加调试日志（仅前3个）
      if (i < 3) {
        AppLog.instance.put(
            'parseExploreRule: 书籍 ${i + 1} - name=$name, author=$author, bookUrl=$bookUrl, bookUrl规则=${rule.bookUrl}, name规则=${rule.name}, author规则=${rule.author}');

        if (bookHtml.isNotEmpty) {
          final preview =
              bookHtml.length > 300 ? bookHtml.substring(0, 300) : bookHtml;
          AppLog.instance.put('parseExploreRule: bookHtml预览（前300字符）: $preview');
        }

        // 如果关键字段为空，记录警告
        if (name == null || name.isEmpty) {
          AppLog.instance.put(
              'parseExploreRule: 警告 - 书籍 ${i + 1} 的name为空, bookHtml长度=${bookHtml.length}, name规则=${rule.name}');
          if (bookHtml.isNotEmpty) {
            final preview =
                bookHtml.length > 300 ? bookHtml.substring(0, 300) : bookHtml;
            AppLog.instance
                .put('parseExploreRule: bookHtml预览（前300字符）: $preview');
          }
        }
        if (bookUrl == null || bookUrl.isEmpty) {
          AppLog.instance.put(
              'parseExploreRule: 警告 - 书籍 ${i + 1} 的bookUrl为空, bookUrl规则=${rule.bookUrl}');
        }
      }

      // 只有当至少有一个关键字段（name 或 bookUrl）不为空时才添加结果
      // 这样可以过滤掉完全无效的书籍项
      if ((name != null && name.isNotEmpty) ||
          (bookUrl != null && bookUrl.isNotEmpty)) {
        results.add({
          'name': name,
          'author': author,
          'kind': kind,
          'wordCount': wordCount,
          'lastChapter': lastChapter,
          'intro': intro,
          'coverUrl': coverUrl,
          'bookUrl': bookUrl, // 使用isUrl=true解析的结果
        });
      } else {
        AppLog.instance
            .put('parseExploreRule: 跳过书籍 ${i + 1} - name和bookUrl都为空，书籍项无效');
      }
    }

    AppLog.instance.put(
        'parseExploreRule: 解析完成, 共找到 ${bookListHtml.length} 个书籍元素, 有效书籍 ${results.length} 个');

    return results;
  }
}
