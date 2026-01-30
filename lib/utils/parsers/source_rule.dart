import '../js_engine.dart';
import 'rule_parser.dart';

/// 源规则类（参考项目：AnalyzeRule.SourceRule）
/// 用于解析和处理单个规则，支持变量替换、正则分组引用等
class SourceRule {
  String rule;
  String replaceRegex = '';
  String replacement = '';
  bool replaceFirst = false;
  final Map<String, String> putMap = {};
  final List<String> ruleParam = [];
  final List<int> ruleType = [];
  
  // 规则类型常量
  static const int getRuleType = -2;  // @get:{key}
  static const int jsRuleType = -1;   // {{js}}
  static const int defaultRuleType = 0; // 普通文本
  // regType > defaultRuleType 表示正则分组引用（$1, $2等）

  SourceRule(this.rule);

  /// 获取参数数量
  int getParamSize() => ruleParam.length;

  /// 判断是否是规则字符串
  bool isRule(String ruleStr) {
    return ruleStr.startsWith('@') ||
           ruleStr.startsWith('\$.') ||
           ruleStr.startsWith('\$[') ||
           ruleStr.startsWith('//');
  }

  /// 构建规则（参考项目：makeUpRule）
  /// 替换@get, {{js}}, $1, $2等
  Future<String> makeUpRule(dynamic result) async {
    final parts = <String>[];
    
    if (ruleParam.isNotEmpty) {
      // 从后往前处理（参考项目逻辑）
      for (int index = ruleParam.length - 1; index >= 0; index--) {
        final regType = ruleType[index];
        final param = ruleParam[index];
        
        if (regType > defaultRuleType) {
          // 正则分组引用（$1, $2等）
          // regType 是分组索引（1, 2, 3...）
          if (result is List) {
            if (result.length > regType) {
              final groupValue = result[regType];
              if (groupValue != null) {
                parts.insert(0, groupValue.toString());
              } else {
                parts.insert(0, param);
              }
            } else {
              parts.insert(0, param);
            }
          } else {
            parts.insert(0, param);
          }
        } else if (regType == jsRuleType) {
          // {{js}} JavaScript代码
          try {
            // 提取 JavaScript 代码（去除 {{js: 和 }}）
            final jsCode = param.replaceAll(RegExp(r'^\{\{js:\s*'), '').replaceAll(RegExp(r'\}\}$'), '').trim();
            if (jsCode.isNotEmpty) {
              // 执行 JavaScript 代码
              final jsResult = await JSEngine.evalJS(jsCode);
              if (jsResult != null) {
                parts.insert(0, jsResult.toString());
              } else {
                parts.insert(0, param);
              }
            } else {
              parts.insert(0, param);
            }
          } catch (e) {
            // JavaScript 执行失败，使用原参数
            parts.insert(0, param);
          }
        } else if (regType == getRuleType) {
          // @get:{key}
          // 从 RuleParser 获取变量
          final key = param.replaceAll(RegExp(r'^@get:\s*'), '').replaceAll(RegExp(r'\{|\}'), '').trim();
          if (key.isNotEmpty) {
            final value = RuleParser.getVariable(key);
            if (value != null && value.isNotEmpty) {
              parts.insert(0, value);
            } else {
              parts.insert(0, param);
            }
          } else {
            parts.insert(0, param);
          }
        } else {
          // 普通文本
          parts.insert(0, param);
        }
      }
      rule = parts.join('');
    }
    
    // 分离正则替换规则
    final ruleStrS = rule.split('##');
    rule = ruleStrS[0].trim();
    if (ruleStrS.length > 1) {
      replaceRegex = ruleStrS[1];
    }
    if (ruleStrS.length > 2) {
      replacement = ruleStrS[2];
    }
    if (ruleStrS.length > 3) {
      replaceFirst = true;
    }
    
    return rule;
  }
}

