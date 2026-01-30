import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 基础底部对话框 Widget（支持 Consumer 的有状态版本）
abstract class BaseBottomSheetConsumer extends ConsumerStatefulWidget {
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

  const BaseBottomSheetConsumer({
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

  @override
  ConsumerState<BaseBottomSheetConsumer> createState();
}

/// 基础底部对话框状态（支持 Consumer）
abstract class BaseBottomSheetConsumerState<T extends BaseBottomSheetConsumer>
    extends ConsumerState<T> {
  /// 构建对话框内容
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: widget.maxHeight ??
              (widget.heightFactor != null
                  ? mediaQuery.size.height * widget.heightFactor!
                  : mediaQuery.size.height * 0.9),
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showTitleBar) _buildTitleBar(context, theme),
            Flexible(
              child: Padding(
                padding: widget.padding ?? const EdgeInsets.all(16),
                child: buildContent(context),
              ),
            ),
          ],
        ),
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
          if (widget.title != null)
            Expanded(
              child: Text(
                widget.title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (widget.titleActions != null) ...widget.titleActions!,
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
    required BaseBottomSheetConsumer bottomSheet,
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
