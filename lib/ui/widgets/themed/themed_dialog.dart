import 'package:flutter/material.dart';
import 'themed_constants.dart';

/// 统一样式的对话框组件
/// 基于 reader_settings_page.dart 的设计规范
class ThemedDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final EdgeInsets? contentPadding;

  const ThemedDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.backgroundColor,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: backgroundColor ?? ThemedConstants.dialogBackground,
      shape: ThemedConstants.getDialogShape(),
      title: Text(
        title,
        style: const TextStyle(
          color: ThemedConstants.textPrimary,
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: DefaultTextStyle(
        style: TextStyle(
          color: ThemedConstants.textTertiary,
          fontSize: 14.0,
        ),
        child: content,
      ),
      contentPadding: contentPadding ?? const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
      actions: actions,
    );
  }

  /// 快速创建确认对话框
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ThemedDialog(
        title: title,
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelText,
              style: TextStyle(color: ThemedConstants.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDangerous
                    ? ThemedConstants.primaryGradientStart
                    : ThemedConstants.activeColorAlt,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 快速创建选择对话框
  static Future<T?> showSelection<T>({
    required BuildContext context,
    required String title,
    required List<ThemedDialogOption<T>> options,
    T? currentValue,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => ThemedDialog(
        title: title,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              final isSelected = option.value == currentValue;
              return ListTile(
                title: Text(
                  option.label,
                  style: const TextStyle(color: ThemedConstants.textPrimary),
                ),
                subtitle: option.description != null
                    ? Text(
                        option.description!,
                        style: TextStyle(color: ThemedConstants.textTertiary),
                      )
                    : null,
                trailing: isSelected
                    ? const Icon(
                        Icons.check,
                        color: ThemedConstants.activeColorAlt,
                      )
                    : null,
                onTap: () => Navigator.pop(context, option.value),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: ThemedConstants.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  /// 快速创建输入对话框
  static Future<String?> showInput({
    required BuildContext context,
    required String title,
    String? initialValue,
    String? hintText,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (context) => ThemedDialog(
        title: title,
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          keyboardType: keyboardType,
          style: const TextStyle(color: ThemedConstants.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: ThemedConstants.textDisabled),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: ThemedConstants.textDisabled),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: ThemedConstants.activeColorAlt),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: ThemedConstants.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(
              '确定',
              style: TextStyle(color: ThemedConstants.activeColorAlt),
            ),
          ),
        ],
      ),
    );
  }
}

/// 对话框选项
class ThemedDialogOption<T> {
  final String label;
  final String? description;
  final T value;

  const ThemedDialogOption({
    required this.label,
    required this.value,
    this.description,
  });
}
