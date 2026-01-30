import 'dart:convert';

/// 书籍基础接口
/// 参考项目：io.legado.app.data.entities.BaseBook
/// 
/// 提供书籍相关的通用功能，包括变量管理和分类处理
abstract class BaseBook {
  /// 书籍名称
  String get name;
  set name(String value);

  /// 作者名称
  String get author;
  set author(String value);

  /// 书籍URL
  String get bookUrl;
  set bookUrl(String value);

  /// 分类信息
  String? get kind;
  set kind(String? value);

  /// 字数
  String? get wordCount;
  set wordCount(String? value);

  /// 变量（JSON字符串）
  String? get variable;
  set variable(String? value);

  /// 详情页HTML
  String? get infoHtml;
  set infoHtml(String? value);

  /// 目录页HTML
  String? get tocHtml;
  set tocHtml(String? value);

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

  /// 设置自定义变量
  void putCustomVariable(String? value) {
    putVariable('custom', value);
  }

  /// 获取自定义变量
  String getCustomVariable() {
    return getVariable('custom');
  }

  /// 获取分类列表
  /// 合并 wordCount 和 kind 字段
  List<String> getKindList() {
    final kindList = <String>[];
    
    // 添加字数
    if (wordCount != null && wordCount!.isNotEmpty) {
      kindList.add(wordCount!);
    }
    
    // 添加分类（支持逗号和换行分隔）
    if (kind != null && kind!.isNotEmpty) {
      final kinds = kind!
          .split(RegExp(r'[,,\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      kindList.addAll(kinds);
    }
    
    return kindList;
  }
}

