import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/eink_theme.dart';

/// 电子墨水模式适配的 AppBar Widget
/// 在电子墨水模式下自动应用相应的样式
class EInkAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 标题
  final Widget? title;
  
  /// 标题文本
  final String? titleText;
  
  /// 前导 Widget
  final Widget? leading;
  
  /// 操作按钮
  final List<Widget>? actions;
  
  /// 是否自动实现前导按钮
  final bool automaticallyImplyLeading;
  
  /// 是否居中标题
  final bool? centerTitle;
  
  /// 工具栏高度
  final double? toolbarHeight;
  
  /// 标题间距
  final double? titleSpacing;
  
  /// 底部 Widget
  final PreferredSizeWidget? bottom;
  
  /// 形状
  final ShapeBorder? shape;
  
  /// 图标主题
  final IconThemeData? iconTheme;
  
  /// 操作图标主题
  final IconThemeData? actionsIconTheme;
  
  /// 文本主题
  final TextStyle? titleTextStyle;
  
  /// 系统覆盖样式
  final SystemUiOverlayStyle? systemOverlayStyle;
  
  /// 是否显示阴影
  final bool? shadowColor;
  
  /// 表面色调
  final Color? surfaceTintColor;

  const EInkAppBar({
    super.key,
    this.title,
    this.titleText,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.toolbarHeight,
    this.titleSpacing,
    this.bottom,
    this.shape,
    this.iconTheme,
    this.actionsIconTheme,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.shadowColor,
    this.surfaceTintColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title ?? (titleText != null ? Text(titleText!) : null),
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      toolbarHeight: toolbarHeight,
      titleSpacing: titleSpacing,
      bottom: bottom,
      shape: shape,
      backgroundColor: EInkTheme.getAppBarColor(context),
      iconTheme: iconTheme ?? IconThemeData(
        color: EInkTheme.getAppBarIconColor(context),
      ),
      actionsIconTheme: actionsIconTheme ?? IconThemeData(
        color: EInkTheme.getAppBarIconColor(context),
      ),
      titleTextStyle: titleTextStyle ?? TextStyle(
        color: EInkTheme.getAppBarTextColor(context),
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      systemOverlayStyle: systemOverlayStyle ?? (EInkTheme.isEInkMode
          ? SystemUiOverlayStyle.dark
          : null),
      elevation: EInkTheme.isEInkMode ? 0 : null,
      shadowColor: shadowColor != null ? (shadowColor! ? Colors.black : Colors.transparent) : null,
      surfaceTintColor: surfaceTintColor ?? (EInkTheme.isEInkMode ? Colors.transparent : null),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    toolbarHeight ?? kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );
}

