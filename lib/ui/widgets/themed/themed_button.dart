import 'package:flutter/material.dart';
import 'themed_constants.dart';

/// 统一样式的按钮组件
/// 基于 reader_settings_page.dart 的设计规范
class ThemedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const ThemedButton({
    super.key,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: ThemedConstants.spacingLarge,
              vertical: ThemedConstants.spacingSmall,
            ),
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? ThemedConstants.primaryGradient : null,
          color: isSelected ? null : ThemedConstants.buttonBackground,
          borderRadius: BorderRadius.circular(ThemedConstants.radiusMedium),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : ThemedConstants.buttonBorder,
            width: 1,
          ),
          boxShadow: isSelected ? ThemedConstants.tabShadow : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: ThemedConstants.textPrimary,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// 图标按钮（带圆形背景）
class ThemedIconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final double? iconSize;
  final EdgeInsets? padding;

  const ThemedIconButton({
    super.key,
    required this.icon,
    this.label,
    this.onTap,
    this.iconColor,
    this.iconSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThemedConstants.radiusSmall),
      child: Padding(
        padding: padding ?? ThemedConstants.paddingMedium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: iconColor ?? ThemedConstants.textPrimary,
              size: iconSize ?? ThemedConstants.iconButtonSizeLarge,
            ),
            if (label != null) ...[
              const SizedBox(height: ThemedConstants.spacingXSmall),
              Text(
                label!,
                style: TextStyle(
                  color: ThemedConstants.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 渐变按钮（全宽）
class ThemedGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? height;

  const ThemedGradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.padding,
    this.margin,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: height ?? 48.0,
      decoration: BoxDecoration(
        gradient: ThemedConstants.primaryGradient,
        borderRadius: BorderRadius.circular(ThemedConstants.radiusMedium),
        boxShadow: ThemedConstants.tabShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ThemedConstants.radiusMedium),
          child: Center(
            child: Padding(
              padding: padding ?? ThemedConstants.paddingMedium,
              child: Text(
                label,
                style: const TextStyle(
                  color: ThemedConstants.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 文本按钮（用于对话框）
class ThemedTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? textColor;
  final bool isPrimary;

  const ThemedTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.textColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: textColor ??
              (isPrimary
                  ? ThemedConstants.activeColorAlt
                  : ThemedConstants.textTertiary),
        ),
      ),
    );
  }
}
