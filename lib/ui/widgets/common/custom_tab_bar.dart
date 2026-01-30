import 'package:flutter/material.dart';

/// 自定义TabBar组件
/// 解决原生TabBar在某些主题下选中状态文字颜色与背景颜色相同的问题
class CustomTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget> tabs;
  final bool isScrollable;
  final EdgeInsetsGeometry? labelPadding;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TabAlignment? tabAlignment;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;

  const CustomTabBar({
    super.key,
    this.controller,
    required this.tabs,
    this.isScrollable = false,
    this.labelPadding,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.tabAlignment,
    this.labelStyle,
    this.unselectedLabelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 根据主题自动选择合适的颜色
    final effectiveLabelColor = labelColor ?? 
        (isDark ? Colors.white : theme.primaryColor);
    final effectiveUnselectedLabelColor = unselectedLabelColor ?? 
        (isDark ? Colors.white70 : Colors.grey[600]);
    final effectiveIndicatorColor = indicatorColor ?? 
        (isDark ? Colors.white : theme.primaryColor);

    return TabBar(
      controller: controller,
      tabs: tabs,
      isScrollable: isScrollable,
      labelPadding: labelPadding,
      indicatorColor: effectiveIndicatorColor,
      labelColor: effectiveLabelColor,
      unselectedLabelColor: effectiveUnselectedLabelColor,
      tabAlignment: tabAlignment,
      indicatorWeight: 3,
      labelStyle: labelStyle ?? const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: unselectedLabelStyle ?? const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

