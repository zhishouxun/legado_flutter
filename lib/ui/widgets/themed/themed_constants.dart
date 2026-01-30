import 'package:flutter/material.dart';

/// 统一的主题常量
/// 基于 reader_settings_page.dart 的设计规范
class ThemedConstants {
  ThemedConstants._();

  // ==================== 颜色常量 ====================

  /// 主题渐变色 - 珊瑚红
  static const Color primaryGradientStart = Color(0xFFFF6B6B);
  static const Color primaryGradientEnd = Color(0xFFFF8E53);

  /// 背景渐变色 - 深色
  static const Color backgroundGradientStart = Color(0xFF1a1a1a);
  static const Color backgroundGradientEnd = Color(0xFF2a2a2a);

  /// 对话框背景色
  static const Color dialogBackground = Color(0xFF2C2C2C);
  static const Color dialogBackgroundAlt = Color(0xFF2a2a2a);

  /// 激活色
  static const Color activeColor = primaryGradientStart;
  static const Color activeColorAlt = Colors.orange;

  /// 文字颜色
  static const Color textPrimary = Colors.white;
  static final Color textSecondary = Colors.white.withOpacity(0.9);
  static final Color textTertiary = Colors.white.withOpacity(0.7);
  static final Color textDisabled = Colors.white.withOpacity(0.5);

  /// 分隔线颜色
  static final Color dividerColor = Colors.white.withOpacity(0.1);
  static const Color dividerColorAlt = Colors.white24;

  /// 按钮颜色
  static final Color buttonBackground = Colors.white.withOpacity(0.05);
  static final Color buttonBorder = Colors.white.withOpacity(0.1);
  static final Color iconColor = Colors.white.withOpacity(0.9);
  static final Color iconColorSecondary = Colors.white70;

  // ==================== 尺寸常量 ====================

  /// 圆角半径
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  /// 间距
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingLarge = 16.0;
  static const double spacingXLarge = 24.0;

  /// 内边距
  static const EdgeInsets paddingSmall = EdgeInsets.all(8.0);
  static const EdgeInsets paddingMedium = EdgeInsets.all(12.0);
  static const EdgeInsets paddingLarge = EdgeInsets.all(16.0);
  static const EdgeInsets paddingHorizontal = EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets paddingVertical = EdgeInsets.symmetric(vertical: 8.0);
  static const EdgeInsets paddingAll = EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);

  // ==================== 滑块样式常量 ====================

  /// 滑块轨道高度
  static const double sliderTrackHeight = 3.0;

  /// 滑块拇指半径
  static const double sliderThumbRadius = 6.0;

  /// 滑块覆盖层半径
  static const double sliderOverlayRadius = 12.0;

  // ==================== 开关样式常量 ====================

  /// 开关尺寸
  static const double switchWidth = 40.0;
  static const double switchHeight = 20.0;
  static const double switchThumbSize = 20.0;

  /// 开关圆角
  static const double switchRadius = 10.0;

  // ==================== 按钮样式常量 ====================

  /// 图标按钮尺寸
  static const double iconButtonSize = 16.0;
  static const double iconButtonSizeMedium = 20.0;
  static const double iconButtonSizeLarge = 24.0;

  /// 图标按钮最小约束
  static const BoxConstraints iconButtonConstraints = BoxConstraints(
    minWidth: 24.0,
    minHeight: 24.0,
  );

  // ==================== 字体样式常量 ====================

  /// 标题字体样式
  static const TextStyle titleStyle = TextStyle(
    color: textPrimary,
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// 节标题字体样式
  static const TextStyle sectionTitleStyle = TextStyle(
    color: textPrimary,
    fontSize: 10.0,
    fontWeight: FontWeight.bold,
  );

  /// 标签字体样式 - 选中
  static const TextStyle tabSelectedStyle = TextStyle(
    color: textPrimary,
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  /// 标签字体样式 - 未选中
  static const TextStyle tabUnselectedStyle = TextStyle(
    color: textPrimary,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );

  /// 正文字体样式
  static const TextStyle bodyStyle = TextStyle(
    color: textPrimary,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
  );

  /// 描述字体样式
  static final TextStyle descriptionStyle = TextStyle(
    color: textTertiary,
    fontSize: 12.0,
  );

  /// 数值字体样式
  static const TextStyle valueStyle = TextStyle(
    color: textPrimary,
    fontSize: 12.0,
    fontWeight: FontWeight.w600,
  );

  // ==================== 阴影常量 ====================

  /// 卡片阴影
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10.0,
          offset: const Offset(0, -2),
        ),
      ];

  /// 标签阴影（选中状态）
  static List<BoxShadow> get tabShadow => [
        BoxShadow(
          color: primaryGradientStart.withOpacity(0.3),
          blurRadius: 8.0,
          offset: const Offset(0, 2),
        ),
      ];

  /// 按钮阴影
  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 2.0,
          offset: const Offset(0, 1),
        ),
      ];

  // ==================== 渐变常量 ====================

  /// 主题渐变（珊瑚红）
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  /// 背景渐变（深色）
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundGradientStart, backgroundGradientEnd],
  );

  // ==================== 辅助方法 ====================

  /// 获取滑块主题数据
  static SliderThemeData getSliderTheme(BuildContext context) {
    return SliderTheme.of(context).copyWith(
      trackHeight: sliderTrackHeight,
      activeTrackColor: primaryGradientStart,
      inactiveTrackColor: Colors.white.withOpacity(0.1),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: sliderThumbRadius,
      ),
      thumbColor: primaryGradientStart,
      overlayShape: const RoundSliderOverlayShape(
        overlayRadius: sliderOverlayRadius,
      ),
      overlayColor: primaryGradientStart.withOpacity(0.2),
    );
  }

  /// 获取对话框圆角
  static RoundedRectangleBorder getDialogShape() {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusLarge),
    );
  }

  /// 获取底部弹窗圆角
  static BorderRadius getBottomSheetRadius() {
    return const BorderRadius.vertical(top: Radius.circular(radiusXLarge));
  }
}
