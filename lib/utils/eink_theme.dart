import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// 电子墨水模式主题工具类
/// 统一管理电子墨水模式的样式配置
class EInkTheme {
  /// 检查是否启用电子墨水模式
  static bool get isEInkMode => AppConfig.getBool('eink_mode', defaultValue: false);

  /// 获取背景色
  /// 电子墨水模式：白色
  /// 普通模式：使用主题背景色
  static Color getBackgroundColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.white;
    }
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// 获取卡片背景色
  /// 电子墨水模式：白色或透明
  /// 普通模式：使用主题卡片色
  static Color getCardColor(BuildContext context, {bool transparent = false}) {
    if (isEInkMode) {
      return transparent ? Colors.transparent : Colors.white;
    }
    return Theme.of(context).cardColor;
  }

  /// 获取文本颜色
  /// 电子墨水模式：黑色
  /// 普通模式：使用主题文本色
  static Color getTextColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.black;
    }
    return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  }

  /// 获取次要文本颜色
  /// 电子墨水模式：深灰色
  /// 普通模式：使用主题次要文本色
  static Color getSecondaryTextColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.grey[800]!;
    }
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600]!;
  }

  /// 获取分割线颜色
  /// 电子墨水模式：深灰色
  /// 普通模式：使用主题分割线色
  static Color getDividerColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.grey[300]!;
    }
    return Theme.of(context).dividerColor;
  }

  /// 获取边框圆角
  /// 电子墨水模式：无圆角（0）
  /// 普通模式：使用默认圆角
  static BorderRadius getBorderRadius({double defaultRadius = 8.0}) {
    if (isEInkMode) {
      return BorderRadius.zero;
    }
    return BorderRadius.circular(defaultRadius);
  }

  /// 获取卡片圆角
  static BorderRadius getCardBorderRadius() {
    return getBorderRadius(defaultRadius: 8.0);
  }

  /// 获取对话框圆角
  static BorderRadius getDialogBorderRadius() {
    return getBorderRadius(defaultRadius: 16.0);
  }

  /// 获取底部对话框圆角
  static BorderRadius getBottomSheetBorderRadius() {
    if (isEInkMode) {
      return BorderRadius.zero;
    }
    return const BorderRadius.vertical(top: Radius.circular(16));
  }

  /// 获取阴影
  /// 电子墨水模式：无阴影
  /// 普通模式：使用默认阴影
  static List<BoxShadow>? getBoxShadow({List<BoxShadow>? defaultShadow}) {
    if (isEInkMode) {
      return null;
    }
    return defaultShadow ?? [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// 获取卡片阴影
  static List<BoxShadow>? getCardShadow() {
    return getBoxShadow();
  }

  /// 获取对话框背景色
  /// 电子墨水模式：透明
  /// 普通模式：使用主题背景色
  static Color getDialogBackgroundColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.transparent;
    }
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// 获取 AppBar 背景色
  /// 电子墨水模式：白色
  /// 普通模式：使用主题 AppBar 色
  static Color getAppBarColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.white;
    }
    return Theme.of(context).appBarTheme.backgroundColor ?? 
           Theme.of(context).colorScheme.surface;
  }

  /// 获取 AppBar 图标颜色
  /// 电子墨水模式：黑色
  /// 普通模式：使用主题图标色
  static Color getAppBarIconColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.black;
    }
    return Theme.of(context).appBarTheme.iconTheme?.color ?? 
           Theme.of(context).iconTheme.color ?? Colors.black;
  }

  /// 获取 AppBar 文本颜色
  /// 电子墨水模式：黑色
  /// 普通模式：使用主题文本色
  static Color getAppBarTextColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.black;
    }
    return Theme.of(context).appBarTheme.titleTextStyle?.color ?? 
           Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
  }

  /// 获取列表项背景色
  /// 电子墨水模式：白色或透明
  /// 普通模式：使用主题卡片色
  static Color getListTileColor(BuildContext context, {bool transparent = false}) {
    return getCardColor(context, transparent: transparent);
  }

  /// 获取按钮背景色
  /// 电子墨水模式：浅灰色
  /// 普通模式：使用主题按钮色
  static Color getButtonColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.grey[200]!;
    }
    return Theme.of(context).colorScheme.primary;
  }

  /// 获取按钮文本颜色
  /// 电子墨水模式：黑色
  /// 普通模式：使用主题按钮文本色
  static Color getButtonTextColor(BuildContext context) {
    if (isEInkMode) {
      return Colors.black;
    }
    return Theme.of(context).colorScheme.onPrimary;
  }

  /// 应用电子墨水模式样式到 BoxDecoration
  static BoxDecoration applyEInkDecoration(
    BuildContext context, {
    Color? color,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? getCardColor(context),
      borderRadius: borderRadius ?? getCardBorderRadius(),
      boxShadow: getBoxShadow(defaultShadow: boxShadow),
      border: border,
    );
  }
}

