import 'package:flutter/material.dart';
import '../../../data/models/book_source.dart';
import '../../../services/explore_service.dart';

/// 调试帮助组件
class DebugHelpWidget extends StatefulWidget {
  final BookSource source;
  final Function(String) onSelectKey;

  const DebugHelpWidget({
    super.key,
    required this.source,
    required this.onSelectKey,
  });

  @override
  State<DebugHelpWidget> createState() => _DebugHelpWidgetState();
}

class _DebugHelpWidgetState extends State<DebugHelpWidget> {
  String? _exploreKey;
  bool _showHelp = true;

  @override
  void initState() {
    super.initState();
    _loadExploreKinds();
  }

  Future<void> _loadExploreKinds() async {
    try {
      final kinds =
          await ExploreService.instance.getExploreKinds(widget.source);
      if (kinds.isNotEmpty) {
        final firstKind = kinds.first;
        setState(() {
          _exploreKey = '${firstKind.title}::${firstKind.url}';
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showHelp) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildHelpChip(
            '搜索',
            '我的',
            Icons.search,
          ),
          if (_exploreKey != null)
            _buildHelpChip(
              '发现',
              _exploreKey!,
              Icons.explore,
            ),
          _buildHelpChip(
            '目录页',
            '++',
            Icons.list,
            prefix: true,
          ),
          _buildHelpChip(
            '正文页',
            '--',
            Icons.article,
            prefix: true,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _showHelp = false;
              });
            },
            tooltip: '隐藏帮助',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpChip(
    String label,
    String key,
    IconData icon, {
    bool prefix = false,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () {
        if (prefix) {
          // 如果是前缀，需要用户输入URL
          _showUrlInputDialog(label, key);
        } else {
          widget.onSelectKey(key);
        }
      },
    );
  }

  void _showUrlInputDialog(String label, String prefix) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('输入${label}URL'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入$label的URL',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                widget.onSelectKey('$prefix$url');
                Navigator.of(context).pop();
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
