/// 字典规则模型
/// 参考项目：io.legado.app.data.entities.DictRule
library;

import '../../services/network/network_service.dart';
import '../../utils/parsers/rule_parser.dart';
import '../../utils/app_log.dart';

class DictRule {
  /// 规则名称（主键）
  final String name;

  /// URL规则
  String urlRule;

  /// 显示规则
  String showRule;

  /// 是否启用
  bool enabled;

  /// 排序序号
  int sortNumber;

  DictRule({
    required this.name,
    this.urlRule = '',
    this.showRule = '',
    this.enabled = true,
    this.sortNumber = 0,
  });

  /// 从JSON创建
  factory DictRule.fromJson(Map<String, dynamic> json) {
    return DictRule(
      name: json['name'] as String,
      urlRule: json['urlRule'] as String? ?? '',
      showRule: json['showRule'] as String? ?? '',
      enabled: json['enabled'] == 1 || json['enabled'] == true,
      sortNumber: json['sortNumber'] as int? ?? 0,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'urlRule': urlRule,
      'showRule': showRule,
      'enabled': enabled ? 1 : 0,
      'sortNumber': sortNumber,
    };
  }

  /// 复制
  DictRule copyWith({
    String? name,
    String? urlRule,
    String? showRule,
    bool? enabled,
    int? sortNumber,
  }) {
    return DictRule(
      name: name ?? this.name,
      urlRule: urlRule ?? this.urlRule,
      showRule: showRule ?? this.showRule,
      enabled: enabled ?? this.enabled,
      sortNumber: sortNumber ?? this.sortNumber,
    );
  }

  /// 搜索字典
  /// 参考项目：DictRule.search
  ///
  /// [word] 要查询的词语
  /// 返回查询结果（HTML或文本）
  Future<String> search(String word) async {
    try {
      // 1. 构建URL（替换 {{key}} 为查询词）
      // 参考项目：AnalyzeUrl(urlRule, key = word)
      String url = urlRule.replaceAll('{{key}}', Uri.encodeComponent(word));

      // 2. 发送网络请求
      // 参考项目：analyzeUrl.getStrResponseAwait().body
      final response = await NetworkService.instance.get(url);
      final body = await NetworkService.getResponseText(response);

      // 3. 如果没有显示规则，直接返回响应内容
      // 参考项目：if (showRule.isBlank()) return body!!
      if (showRule.isEmpty) {
        return body;
      }

      // 4. 使用显示规则解析响应内容
      // 参考项目：analyzeRule.getString(showRule, mContent = body)
      final result = await RuleParser.parseRuleAsync(
        body,
        showRule,
        variables: {'key': word},
        baseUrl: url,
      );

      return result ?? body;
    } catch (e) {
      AppLog.instance.put('DictRule.search($word) 失败: $e', error: e);
      return '查询失败: $e';
    }
  }
}
