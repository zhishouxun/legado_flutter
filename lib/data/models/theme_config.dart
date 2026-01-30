/// 主题配置模型
class ThemeConfig {
  /// 主题名称
  String themeName;

  /// 是否为夜间主题
  bool isNightTheme;

  /// 主色（十六进制颜色字符串，如 #FF0000）
  String primaryColor;

  /// 强调色（十六进制颜色字符串）
  String accentColor;

  /// 背景色（十六进制颜色字符串）
  String backgroundColor;

  /// 底部背景色（十六进制颜色字符串）
  String bottomBackground;

  ThemeConfig({
    required this.themeName,
    required this.isNightTheme,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.bottomBackground,
  });

  /// 从JSON创建
  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      themeName: json['themeName'] as String? ?? '',
      isNightTheme: json['isNightTheme'] == true || json['isNightTheme'] == 1,
      primaryColor: json['primaryColor'] as String? ?? '#795548',
      accentColor: json['accentColor'] as String? ?? '#D32F2F',
      backgroundColor: json['backgroundColor'] as String? ?? '#F5F5F5',
      bottomBackground: json['bottomBackground'] as String? ?? '#EEEEEE',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'themeName': themeName,
      'isNightTheme': isNightTheme,
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'backgroundColor': backgroundColor,
      'bottomBackground': bottomBackground,
    };
  }

  /// 复制
  ThemeConfig copyWith({
    String? themeName,
    bool? isNightTheme,
    String? primaryColor,
    String? accentColor,
    String? backgroundColor,
    String? bottomBackground,
  }) {
    return ThemeConfig(
      themeName: themeName ?? this.themeName,
      isNightTheme: isNightTheme ?? this.isNightTheme,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      bottomBackground: bottomBackground ?? this.bottomBackground,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeConfig &&
        other.themeName == themeName &&
        other.isNightTheme == isNightTheme &&
        other.primaryColor == primaryColor &&
        other.accentColor == accentColor &&
        other.backgroundColor == backgroundColor &&
        other.bottomBackground == bottomBackground;
  }

  @override
  int get hashCode {
    return Object.hash(
      themeName,
      isNightTheme,
      primaryColor,
      accentColor,
      backgroundColor,
      bottomBackground,
    );
  }
}

