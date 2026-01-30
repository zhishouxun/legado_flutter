import 'dart:convert';
import 'package:json_path/json_path.dart';
import '../data/models/replace_rule.dart';
import '../core/exceptions/app_exceptions.dart';
import '../utils/app_log.dart';

/// 替换规则解析器
/// 参考项目：io.legado.app.help.ReplaceAnalyzer
///
/// 用于解析替换规则的 JSON 格式，支持标准格式和旧格式
class ReplaceAnalyzer {
  ReplaceAnalyzer._();

  /// 将 JSON 字符串解析为替换规则列表
  /// 参考项目：ReplaceAnalyzer.jsonToReplaceRules()
  ///
  /// [json] JSON 字符串（数组格式）
  /// 返回解析后的替换规则列表
  static List<ReplaceRule> jsonToReplaceRules(String json) {
    try {
      final replaceRules = <ReplaceRule>[];
      
      // 先尝试直接解析为数组
      try {
        final decoded = jsonDecode(json) as List<dynamic>?;
        if (decoded != null) {
          for (final item in decoded) {
            try {
              final jsonItem = jsonEncode(item);
              final rule = jsonToReplaceRule(jsonItem);
              if (rule != null && rule.isValid()) {
                replaceRules.add(rule);
              }
            } catch (e) {
              AppLog.instance.put('解析替换规则项失败', error: e);
            }
          }
          return replaceRules;
        }
      } catch (e) {
        // 直接解析失败，尝试使用 jsonPath
      }

      // 使用 jsonPath 解析数组
      try {
        final jsonPath = JsonPath(json);
        final items = jsonPath.read(r'$');
        
        if (items.isNotEmpty) {
          final firstItem = items.first;
          if (firstItem.value is List) {
            final list = firstItem.value as List;
            for (final item in list) {
              try {
                final jsonItem = jsonEncode(item);
                final rule = jsonToReplaceRule(jsonItem);
                if (rule != null && rule.isValid()) {
                  replaceRules.add(rule);
                }
              } catch (e) {
                AppLog.instance.put('解析替换规则项失败', error: e);
              }
            }
          }
        }
      } catch (e) {
        AppLog.instance.put('使用 jsonPath 解析替换规则列表失败', error: e);
      }

      return replaceRules;
    } catch (e) {
      AppLog.instance.put('解析替换规则列表失败', error: e);
      return [];
    }
  }

  /// 将 JSON 字符串解析为单个替换规则
  /// 参考项目：ReplaceAnalyzer.jsonToReplaceRule()
  ///
  /// [json] JSON 字符串（对象格式）
  /// 返回解析后的替换规则，如果解析失败返回 null
  static ReplaceRule? jsonToReplaceRule(String json) {
    try {
      final trimmedJson = json.trim();
      
      // 尝试标准格式解析
      try {
        final decoded = jsonDecode(trimmedJson) as Map<String, dynamic>?;
        if (decoded != null) {
          final rule = ReplaceRule.fromJson(decoded);
          if (rule.pattern.isNotEmpty) {
            return rule;
          }
        }
      } catch (e) {
        // 标准格式解析失败，尝试旧格式
      }

      // 尝试旧格式解析（使用 jsonPath）
      try {
        // 先解析为 Map
        final decoded = jsonDecode(trimmedJson) as Map<String, dynamic>?;
        if (decoded == null) {
          throw NoStackTraceException('格式不对：无法解析为对象');
        }
        
        // 读取各个字段（使用 jsonPath 或直接从 Map 读取）
        int id = decoded['id'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        
        String pattern = decoded['regex'] as String? ?? '';
        if (pattern.isEmpty) {
          // 尝试使用 jsonPath 读取
          try {
            final jsonPath = JsonPath(r'$.regex');
            final results = jsonPath.readValues(decoded);
            if (results.isNotEmpty && results.first is String) {
              pattern = results.first as String;
            }
          } catch (e) {
            // 忽略
          }
        }
        
        if (pattern.isEmpty) {
          throw NoStackTraceException('格式不对：缺少 regex 字段');
        }

        String name = decoded['replaceSummary'] as String? ?? '';
        String replacement = decoded['replacement'] as String? ?? '';
        bool isRegex = decoded['isRegex'] as bool? ?? false;
        String? scope = decoded['useTo'] as String?;
        bool enabled = decoded['enable'] as bool? ?? true;
        int order = decoded['serialNumber'] as int? ?? 0;

        return ReplaceRule(
          id: id,
          name: name,
          pattern: pattern,
          replacement: replacement,
          enabled: enabled,
          sortNumber: order,
          scope: scope,
          isRegex: isRegex,
        );
      } catch (e) {
        if (e is NoStackTraceException) {
          rethrow;
        }
        AppLog.instance.put('解析替换规则失败（旧格式）', error: e);
        return null;
      }
    } catch (e) {
      AppLog.instance.put('解析替换规则失败', error: e);
      return null;
    }
  }
}

