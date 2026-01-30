import 'dart:convert';

/// RSS文章基础接口
/// 参考项目：io.legado.app.data.entities.BaseRssArticle
/// 
/// 提供RSS文章相关的通用功能，包括变量管理
abstract class BaseRssArticle {
  /// 来源URL
  String get origin;
  set origin(String value);

  /// 文章链接
  String get link;
  set link(String value);

  /// 变量（JSON字符串）
  String? get variable;
  set variable(String? value);

  /// 变量映射（从 variable JSON 解析）
  Map<String, String> get variableMap {
    if (variable == null || variable!.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(variable!) as Map<String, dynamic>?;
      if (decoded == null) return {};
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return {};
    }
  }

  /// 设置变量
  /// [key] 变量键
  /// [value] 变量值
  /// 返回是否成功设置
  bool putVariable(String key, String? value) {
    final map = variableMap;
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
    try {
      variable = jsonEncode(map);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取变量
  /// [key] 变量键
  /// [defaultValue] 默认值
  String getVariable(String key, {String defaultValue = ''}) {
    return variableMap[key] ?? defaultValue;
  }

  /// 设置大变量（存储在单独的表或文件中）
  /// [key] 变量键
  /// [value] 变量值
  /// 注意：需要在具体的实现类中提供存储逻辑
  Future<void> putBigVariable(String key, String? value) async {
    // TODO: 实现大变量存储逻辑
    // RuleBigDataHelp.putRssVariable(origin, link, key, value);
  }

  /// 获取大变量
  /// [key] 变量键
  /// 返回变量值，如果不存在返回null
  Future<String?> getBigVariable(String key) async {
    // TODO: 实现大变量获取逻辑
    // return RuleBigDataHelp.getRssVariable(origin, link, key);
    return null;
  }
}

