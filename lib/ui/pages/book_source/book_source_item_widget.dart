import 'package:flutter/material.dart';
import '../../../data/models/book_source.dart';
import '../../widgets/common/custom_switch.dart';

/// 书源列表项组件
class BookSourceItemWidget extends StatelessWidget {
  final BookSource bookSource;
  final bool isBatchMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(bool) onToggleEnabled;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const BookSourceItemWidget({
    super.key,
    required this.bookSource,
    required this.isBatchMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    required this.onToggleEnabled,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 选择框（批量模式）
              if (isBatchMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onTap(),
                ),
              // 书源信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bookSource.bookSourceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 启用状态开关
                        if (!isBatchMode)
                          CustomSwitch(
                            value: bookSource.enabled,
                            onChanged: onToggleEnabled,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bookSource.bookSourceUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bookSource.bookSourceGroup != null && bookSource.bookSourceGroup!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: bookSource.bookSourceGroup!.split(',').map((group) {
                          return Chip(
                            label: Text(
                              group.trim(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // 操作按钮（非批量模式）
              if (!isBatchMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'enable',
                      child: Row(
                        children: [
                          Icon(
                            bookSource.enabled ? Icons.block : Icons.check_circle,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(bookSource.enabled ? '禁用' : '启用'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'enable':
                        onToggleEnabled(!bookSource.enabled);
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

