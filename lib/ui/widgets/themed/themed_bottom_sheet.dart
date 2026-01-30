import 'package:flutter/material.dart';
import 'themed_constants.dart';

/// 统一样式的底部弹窗基类
/// 基于 reader_settings_page.dart 的设计规范
class ThemedBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double heightFactor;
  final bool showDragHandle;
  final VoidCallback? onClose;
  final Widget? trailing;

  const ThemedBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.heightFactor = 0.6,
    this.showDragHandle = true,
    this.onClose,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * heightFactor,
        decoration: BoxDecoration(
          gradient: ThemedConstants.backgroundGradient,
          borderRadius: ThemedConstants.getBottomSheetRadius(),
          boxShadow: ThemedConstants.cardShadow,
        ),
        child: Column(
          children: [
            // 顶部标题栏
            _buildHeader(context),
            Divider(height: 1, color: ThemedConstants.dividerColor),
            // 内容区域
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        children: [
          // 拖动指示器
          if (showDragHandle)
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (showDragHandle) const SizedBox(height: 8),
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),
              Text(
                title,
                style: ThemedConstants.titleStyle,
              ),
              if (trailing != null)
                trailing!
              else
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: ThemedConstants.iconColor,
                  ),
                  iconSize: ThemedConstants.iconButtonSizeLarge,
                  onPressed: onClose ?? () => Navigator.pop(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 快速显示底部弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    double heightFactor = 0.6,
    bool showDragHandle = true,
    bool isDismissible = true,
    Widget? trailing,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      builder: (context) => ThemedBottomSheet(
        title: title,
        heightFactor: heightFactor,
        showDragHandle: showDragHandle,
        trailing: trailing,
        child: child,
      ),
    );
  }
}

/// 带滚动内容的底部弹窗
class ThemedScrollableBottomSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double heightFactor;
  final bool showDragHandle;
  final VoidCallback? onClose;
  final EdgeInsets? padding;

  const ThemedScrollableBottomSheet({
    super.key,
    required this.title,
    required this.children,
    this.heightFactor = 0.6,
    this.showDragHandle = true,
    this.onClose,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedBottomSheet(
      title: title,
      heightFactor: heightFactor,
      showDragHandle: showDragHandle,
      onClose: onClose,
      child: SingleChildScrollView(
        padding: padding ?? ThemedConstants.paddingLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  /// 快速显示带滚动内容的底部弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    double heightFactor = 0.6,
    bool showDragHandle = true,
    bool isDismissible = true,
    EdgeInsets? padding,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      builder: (context) => ThemedScrollableBottomSheet(
        title: title,
        children: children,
        heightFactor: heightFactor,
        showDragHandle: showDragHandle,
        padding: padding,
      ),
    );
  }
}
