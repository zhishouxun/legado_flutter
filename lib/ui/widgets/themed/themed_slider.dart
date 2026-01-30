import 'package:flutter/material.dart';
import 'themed_constants.dart';

/// 统一样式的滑块组件（带+/-按钮）
/// 基于 reader_settings_page.dart 的设计规范
class ThemedSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double)? formatValue;
  final bool showButtons;

  const ThemedSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.onChangeEnd,
    this.formatValue,
    this.showButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = formatValue ?? (v) => v.toStringAsFixed(0);

    return Row(
      children: [
        // 标题
        Text(
          label,
          style: ThemedConstants.bodyStyle,
        ),
        const SizedBox(width: ThemedConstants.spacingSmall),
        
        // 减号按钮
        if (showButtons)
          IconButton(
            icon: Icon(
              Icons.remove,
              color: ThemedConstants.iconColorSecondary,
              size: ThemedConstants.iconButtonSize,
            ),
            padding: EdgeInsets.zero,
            constraints: ThemedConstants.iconButtonConstraints,
            onPressed: () {
              final newValue = (value - step).clamp(min, max);
              onChanged(newValue);
              onChangeEnd?.call(newValue);
            },
          ),
        
        // 滑块
        Expanded(
          child: SliderTheme(
            data: ThemedConstants.getSliderTheme(context),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: ThemedConstants.activeColor,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        
        // 加号按钮
        if (showButtons)
          IconButton(
            icon: Icon(
              Icons.add,
              color: ThemedConstants.iconColorSecondary,
              size: ThemedConstants.iconButtonSize,
            ),
            padding: EdgeInsets.zero,
            constraints: ThemedConstants.iconButtonConstraints,
            onPressed: () {
              final newValue = (value + step).clamp(min, max);
              onChanged(newValue);
              onChangeEnd?.call(newValue);
            },
          ),
        
        // 数值显示
        SizedBox(
          width: 50,
          child: Text(
            formatter(value),
            style: ThemedConstants.valueStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// 简单的滑块组件（无+/-按钮）
class ThemedSliderSimple extends StatelessWidget {
  final String? label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? displayValue;
  final double? displayWidth;

  const ThemedSliderSimple({
    super.key,
    this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.displayValue,
    this.displayWidth = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 标题（可选）
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              color: ThemedConstants.textSecondary,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(width: ThemedConstants.spacingSmall),
        ],
        
        // 滑块
        Expanded(
          child: SliderTheme(
            data: ThemedConstants.getSliderTheme(context),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: ThemedConstants.activeColor,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        
        // 数值显示（可选）
        if (displayValue != null && displayWidth != null)
          SizedBox(
            width: displayWidth!,
            child: Text(
              displayValue!,
              style: ThemedConstants.valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );
  }
}
