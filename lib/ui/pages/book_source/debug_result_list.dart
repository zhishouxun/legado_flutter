import 'package:flutter/material.dart';
import 'book_source_debug_page.dart';

/// 调试结果列表组件
class DebugResultList extends StatelessWidget {
  final List<DebugMessage> messages;

  const DebugResultList({
    super.key,
    required this.messages,
  });

  Color _getMessageColor(int state) {
    switch (state) {
      case -1:
        return Colors.red;
      case 1000:
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getMessageIcon(int state) {
    switch (state) {
      case -1:
        return Icons.error;
      case 1000:
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;
    final milliseconds = diff.inMilliseconds % 1000;
    return '[${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}]';
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bug_report,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无调试信息',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入关键字或URL开始调试',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final color = _getMessageColor(message.state);
        final icon = _getMessageIcon(message.state);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(icon, color: color),
            title: SelectableText(
              message.message,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            subtitle: Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ),
        );
      },
    );
  }
}

