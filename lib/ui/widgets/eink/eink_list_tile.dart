import 'package:flutter/material.dart';
import '../../../utils/eink_theme.dart';

/// 电子墨水模式适配的列表项 Widget
/// 在电子墨水模式下自动应用相应的样式
class EInkListTile extends StatelessWidget {
  /// 标题
  final Widget? title;
  
  /// 副标题
  final Widget? subtitle;
  
  /// 前导图标
  final Widget? leading;
  
  /// 尾随图标
  final Widget? trailing;
  
  /// 是否启用
  final bool enabled;
  
  /// 是否选中
  final bool selected;
  
  /// 是否密集布局
  final bool dense;
  
  /// 视觉密度
  final VisualDensity? visualDensity;
  
  /// 形状
  final ShapeBorder? shape;
  
  /// 内容填充
  final EdgeInsetsGeometry? contentPadding;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  /// 长按回调
  final VoidCallback? onLongPress;

  const EInkListTile({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.selected = false,
    this.dense = false,
    this.visualDensity,
    this.shape,
    this.contentPadding,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: title != null
          ? DefaultTextStyle(
              style: TextStyle(
                color: EInkTheme.getTextColor(context),
              ),
              child: title!,
            )
          : null,
      subtitle: subtitle != null
          ? DefaultTextStyle(
              style: TextStyle(
                color: EInkTheme.getSecondaryTextColor(context),
              ),
              child: subtitle!,
            )
          : null,
      leading: leading,
      trailing: trailing,
      enabled: enabled,
      selected: selected,
      dense: dense,
      visualDensity: visualDensity,
      shape: shape ?? (EInkTheme.isEInkMode ? null : RoundedRectangleBorder()),
      contentPadding: contentPadding,
      onTap: onTap,
      onLongPress: onLongPress,
      tileColor: EInkTheme.getListTileColor(context, transparent: true),
      selectedTileColor: EInkTheme.isEInkMode
          ? Colors.grey[100]
          : Theme.of(context).colorScheme.primary.withOpacity(0.1),
    );
  }
}

