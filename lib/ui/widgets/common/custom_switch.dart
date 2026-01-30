import 'package:flutter/material.dart';

/// 自定义开关组件
/// 参考项目：使用统一的开关样式，橙色激活状态，灰色未激活状态
class CustomSwitch extends StatelessWidget {
  /// 开关的值
  final bool value;

  /// 值改变时的回调
  final ValueChanged<bool>? onChanged;

  /// 激活时的颜色（默认橙色）
  final Color? activeColor;

  /// 未激活时的颜色（默认灰色）
  final Color? inactiveColor;

  /// 开关的宽度（默认40）
  final double width;

  /// 开关的高度（默认20）
  final double height;

  /// 圆形按钮的直径（默认20）
  final double thumbSize;

  /// 动画时长（默认200ms）
  final Duration duration;

  const CustomSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.width = 40,
    this.height = 20,
    this.thumbSize = 20,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive = inactiveColor ?? Colors.grey.withOpacity(0.5);

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? active : inactive,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeInOut,
              left: value ? width - thumbSize : 0,
              top: (height - thumbSize) / 2,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

