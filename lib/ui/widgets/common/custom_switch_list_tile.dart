import 'package:flutter/material.dart';
import 'custom_switch.dart';

/// 自定义开关列表项组件
/// 用于替换 Material 的 SwitchListTile，使用统一的 CustomSwitch
class CustomSwitchListTile extends StatelessWidget {
  /// 标题
  final Widget? title;

  /// 副标题
  final Widget? subtitle;

  /// 开关的值
  final bool value;

  /// 值改变时的回调
  final ValueChanged<bool>? onChanged;

  /// 是否启用（如果为 false，开关将显示为禁用状态）
  final bool enabled;

  /// 前导图标
  final Widget? secondary;

  /// 是否自动聚焦
  final bool autofocus;

  /// 内容内边距
  final EdgeInsetsGeometry? contentPadding;

  /// 是否密集布局
  final bool dense;

  /// 是否启用视觉密度
  final bool? isThreeLine;

  /// 是否选中（用于主题）
  final bool? selected;

  /// 形状
  final ShapeBorder? shape;

  /// 选中时的背景色
  final Color? selectedTileColor;

  /// 未选中时的背景色
  final Color? tileColor;

  /// 视觉密度
  final VisualDensity? visualDensity;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 是否可聚焦
  final bool? enableFeedback;

  const CustomSwitchListTile({
    super.key,
    this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.secondary,
    this.autofocus = false,
    this.contentPadding,
    this.dense = false,
    this.isThreeLine = false,
    this.selected = false,
    this.shape,
    this.selectedTileColor,
    this.tileColor,
    this.visualDensity,
    this.focusNode,
    this.enableFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: secondary,
      title: title,
      subtitle: subtitle,
      trailing: CustomSwitch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
      enabled: enabled,
      autofocus: autofocus,
      contentPadding: contentPadding,
      dense: dense,
      isThreeLine: isThreeLine,
      selected: selected ?? false,
      shape: shape,
      selectedTileColor: selectedTileColor,
      tileColor: tileColor,
      visualDensity: visualDensity,
      focusNode: focusNode,
      enableFeedback: enableFeedback,
      onTap: enabled && onChanged != null
          ? () => onChanged!(!value)
          : null,
    );
  }
}

