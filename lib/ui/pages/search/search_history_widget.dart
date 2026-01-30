import 'package:flutter/material.dart';

/// 搜索历史组件
class SearchHistoryWidget extends StatelessWidget {
  final List<String> history;
  final Function(String) onHistoryTap;
  final Function(String) onHistoryDelete;
  final VoidCallback onClearHistory;

  const SearchHistoryWidget({
    super.key,
    required this.history,
    required this.onHistoryTap,
    required this.onHistoryDelete,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: onClearHistory,
                child: const Text('清空'),
              ),
            ],
          ),
        ),
        // 历史列表
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final keyword = history[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(keyword),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => onHistoryDelete(keyword),
                ),
                onTap: () => onHistoryTap(keyword),
              );
            },
          ),
        ),
      ],
    );
  }
}

