import 'dart:convert';

/// 漫画颜色滤镜配置
/// 参考项目：MangaColorFilterConfig.kt
class MangaColorFilterConfig {
  int r; // 红色偏移 (-100 到 100)
  int g; // 绿色偏移 (-100 到 100)
  int b; // 蓝色偏移 (-100 到 100)
  int a; // 透明度偏移 (-100 到 100)
  int l; // 亮度偏移 (-100 到 100)

  MangaColorFilterConfig({
    this.r = 0,
    this.g = 0,
    this.b = 0,
    this.a = 0,
    this.l = 0,
  });

  /// 从JSON创建
  factory MangaColorFilterConfig.fromJson(Map<String, dynamic> json) {
    return MangaColorFilterConfig(
      r: json['r'] ?? 0,
      g: json['g'] ?? 0,
      b: json['b'] ?? 0,
      a: json['a'] ?? 0,
      l: json['l'] ?? 0,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'r': r,
      'g': g,
      'b': b,
      'a': a,
      'l': l,
    };
  }

  /// 转换为JSON字符串
  String toJsonString() {
    if (r == 0 && g == 0 && b == 0 && a == 0 && l == 0) {
      return '';
    }
    return jsonEncode(toJson());
  }

  /// 从JSON字符串创建
  factory MangaColorFilterConfig.fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) {
      return MangaColorFilterConfig();
    }
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MangaColorFilterConfig.fromJson(json);
    } catch (e) {
      return MangaColorFilterConfig();
    }
  }

  /// 是否为空配置
  bool get isEmpty => r == 0 && g == 0 && b == 0 && a == 0 && l == 0;
}

