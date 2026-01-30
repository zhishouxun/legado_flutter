import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../core/constants/prefer_key.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 自定义翻页按键配置对话框
/// 参考项目：io.legado.app.ui.book.read.config.PageKeyDialog
class PageKeyDialog extends BaseBottomSheetStateful {
  const PageKeyDialog({super.key}) : super(
          title: '自定义翻页按键',
          heightFactor: 0.5,
        );

  @override
  State<PageKeyDialog> createState() => _PageKeyDialogState();
}

class _PageKeyDialogState extends BaseBottomSheetState<PageKeyDialog> {
  late TextEditingController _prevKeysController;
  late TextEditingController _nextKeysController;
  final FocusNode _prevKeysFocus = FocusNode();
  final FocusNode _nextKeysFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final prevKeys = AppConfig.getString(PreferKey.prevKeys, defaultValue: '');
    final nextKeys = AppConfig.getString(PreferKey.nextKeys, defaultValue: '');
    _prevKeysController = TextEditingController(text: prevKeys);
    _nextKeysController = TextEditingController(text: nextKeys);
  }

  @override
  void dispose() {
    _prevKeysController.dispose();
    _nextKeysController.dispose();
    _prevKeysFocus.dispose();
    _nextKeysFocus.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '上一页按键',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _prevKeysController,
                focusNode: _prevKeysFocus,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '点击输入按键码（用逗号分隔）',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                ),
                // 注意：Flutter的TextField不支持直接监听按键事件
                // 如果需要按键监听，需要使用KeyboardListener包装
                // 这里简化实现，用户手动输入按键码
              ),
              const SizedBox(height: 16),
              Text(
                '下一页按键',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nextKeysController,
                focusNode: _nextKeysFocus,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '点击输入按键码（用逗号分隔）',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                ),
                // 注意：Flutter的TextField不支持直接监听按键事件
                // 如果需要按键监听，需要使用KeyboardListener包装
                // 这里简化实现，用户手动输入按键码
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _prevKeysController.clear();
                  _nextKeysController.clear();
                },
                child: const Text('重置', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  AppConfig.setString(PreferKey.prevKeys, _prevKeysController.text);
                  AppConfig.setString(PreferKey.nextKeys, _nextKeysController.text);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('确定', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

