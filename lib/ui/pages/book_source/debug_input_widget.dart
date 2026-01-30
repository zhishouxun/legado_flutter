import 'package:flutter/material.dart';
import '../../../data/models/book_source.dart';

/// 调试输入组件
class DebugInputWidget extends StatefulWidget {
  final BookSource source;
  final Function(String) onDebug;

  const DebugInputWidget({
    super.key,
    required this.source,
    required this.onDebug,
  });

  @override
  State<DebugInputWidget> createState() => _DebugInputWidgetState();
}

class _DebugInputWidgetState extends State<DebugInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入调试关键字或URL')),
      );
      return;
    }
    widget.onDebug(key);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '输入搜索关键字、URL或特殊前缀（++目录页, --正文页, ::发现页）',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _submit,
            tooltip: '开始调试',
          ),
        ],
      ),
    );
  }
}

