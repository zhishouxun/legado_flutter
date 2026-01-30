import 'package:flutter/material.dart';
import '../../../utils/eink_theme.dart';

/// 基础对话框 Widget
/// 统一处理 Dialog 的主题、动画、软键盘适配等
/// 参考项目：BaseDialogFragment.kt
abstract class BaseDialog extends StatelessWidget {
  /// 是否适配软键盘
  final bool adaptationSoftKeyboard;

  /// 是否可关闭（点击外部关闭）
  final bool barrierDismissible;

  /// 对话框宽度（相对于屏幕宽度，0-1之间）
  final double? widthFactor;

  /// 对话框高度（相对于屏幕高度，0-1之间）
  final double? heightFactor;

  /// 最大宽度
  final double? maxWidth;

  /// 最大高度
  final double? maxHeight;

  /// 内边距
  final EdgeInsets? padding;

  /// 是否显示标题栏
  final bool showTitleBar;

  /// 标题
  final String? title;

  /// 标题栏操作按钮
  final List<Widget>? titleActions;

  const BaseDialog({
    super.key,
    this.adaptationSoftKeyboard = false,
    this.barrierDismissible = true,
    this.widthFactor,
    this.heightFactor,
    this.maxWidth,
    this.maxHeight,
    this.padding,
    this.showTitleBar = false,
    this.title,
    this.titleActions,
  });

  /// 构建对话框内容
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    // 计算对话框尺寸
    double? width;
    double? height;

    if (widthFactor != null) {
      width = mediaQuery.size.width * widthFactor!;
    } else if (maxWidth != null) {
      width = maxWidth;
    } else {
      width = mediaQuery.size.width * 0.9;
    }

    if (heightFactor != null) {
      height = mediaQuery.size.height * heightFactor!;
    } else if (maxHeight != null) {
      height = maxHeight;
    }

    Widget content = Container(
      width: width,
      height: height,
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? mediaQuery.size.width - 32,
        maxHeight: maxHeight ?? mediaQuery.size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: EInkTheme.getDialogBackgroundColor(context),
        borderRadius: adaptationSoftKeyboard
            ? BorderRadius.zero
            : EInkTheme.getDialogBorderRadius(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitleBar) _buildTitleBar(context, theme),
          Flexible(
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: buildContent(context),
            ),
          ),
        ],
      ),
    );

    // 软键盘适配
    if (adaptationSoftKeyboard) {
      content = GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: content,
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: adaptationSoftKeyboard ? 0 : 16,
        vertical: adaptationSoftKeyboard ? 0 : 24,
      ),
      child: content,
    );
  }

  /// 构建标题栏
  Widget _buildTitleBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (titleActions != null) ...titleActions!,
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  /// 显示对话框（静态方法）
  static Future<T?> show<T>({
    required BuildContext context,
    required BaseDialog dialog,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible && dialog.barrierDismissible,
      builder: (context) => dialog,
    );
  }

  /// 显示底部对话框（静态方法）
  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double? heightFactor,
    double? maxHeight,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight ??
              (heightFactor != null
                  ? MediaQuery.of(context).size.height * heightFactor
                  : MediaQuery.of(context).size.height * 0.9),
        ),
        decoration: BoxDecoration(
          color: EInkTheme.getBackgroundColor(context),
          borderRadius: EInkTheme.getBottomSheetBorderRadius(),
        ),
        child: child,
      ),
    );
  }
}

/// 基础底部对话框 Widget（无状态版本）
abstract class BaseBottomSheet extends StatelessWidget {
  /// 是否可关闭（向下拖拽关闭）
  final bool isDismissible;

  /// 是否启用拖拽
  final bool enableDrag;

  /// 高度因子（相对于屏幕高度，0-1之间）
  final double? heightFactor;

  /// 最大高度
  final double? maxHeight;

  /// 内边距
  final EdgeInsets? padding;

  /// 是否显示标题栏
  final bool showTitleBar;

  /// 标题
  final String? title;

  /// 标题栏操作按钮
  final List<Widget>? titleActions;

  const BaseBottomSheet({
    super.key,
    this.isDismissible = true,
    this.enableDrag = true,
    this.heightFactor,
    this.maxHeight,
    this.padding,
    this.showTitleBar = true,
    this.title,
    this.titleActions,
  });

  /// 构建对话框内容
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight ??
            (heightFactor != null
                ? mediaQuery.size.height * heightFactor!
                : mediaQuery.size.height * 0.9),
      ),
      decoration: BoxDecoration(
        color: EInkTheme.getBackgroundColor(context),
        borderRadius: EInkTheme.getBottomSheetBorderRadius(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitleBar) _buildTitleBar(context, theme),
          Flexible(
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: buildContent(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildTitleBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (titleActions != null) ...titleActions!,
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  /// 显示底部对话框（静态方法）
  static Future<T?> show<T>({
    required BuildContext context,
    required BaseBottomSheet bottomSheet,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible && bottomSheet.isDismissible,
      enableDrag: enableDrag && bottomSheet.enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => bottomSheet,
    );
  }
}
