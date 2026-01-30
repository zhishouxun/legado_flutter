import 'package:flutter/material.dart';
import '../../../utils/eink_theme.dart';

/// 电子墨水模式适配的卡片 Widget
/// 在电子墨水模式下自动应用相应的样式
class EInkCard extends StatelessWidget {
  /// 卡片内容
  final Widget child;
  
  /// 外边距
  final EdgeInsetsGeometry? margin;
  
  /// 内边距
  final EdgeInsetsGeometry? padding;
  
  /// 自定义颜色（可选）
  final Color? color;
  
  /// 自定义圆角（可选）
  final BorderRadius? borderRadius;
  
  /// 是否透明背景（电子墨水模式下）
  final bool transparent;
  
  /// 自定义边框（可选）
  final Border? border;
  
  /// 高度
  final double? height;
  
  /// 宽度
  final double? width;
  
  /// 点击回调
  final VoidCallback? onTap;
  
  /// 长按回调
  final VoidCallback? onLongPress;

  const EInkCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
    this.borderRadius,
    this.transparent = false,
    this.border,
    this.height,
    this.width,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: EInkTheme.applyEInkDecoration(
        context,
        color: color,
        borderRadius: borderRadius,
        border: border,
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      card = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius ?? EInkTheme.getCardBorderRadius(),
        child: card,
      );
    }

    return card;
  }
}

