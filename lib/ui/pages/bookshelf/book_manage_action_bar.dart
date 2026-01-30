import 'package:flutter/material.dart';
import 'book_manage_batch_actions.dart';

/// 书籍管理操作栏
class BookManageActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final Function(BatchAction) onBatchAction;

  const BookManageActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onBatchAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllSelected = selectedCount == totalCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 全选按钮
          TextButton.icon(
            icon: Icon(isAllSelected ? Icons.check_box : Icons.check_box_outline_blank),
            label: Text(isAllSelected ? '取消全选' : '全选'),
            onPressed: onSelectAll,
          ),
          const Spacer(),
          // 选中数量
          Text(
            '已选择 $selectedCount / $totalCount',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          // 批量操作按钮
          PopupMenuButton<BatchAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: onBatchAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: BatchAction.moveToGroup,
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move, size: 20),
                    SizedBox(width: 8),
                    Text('移动到分组'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: BatchAction.addToGroup,
                child: Row(
                  children: [
                    Icon(Icons.folder_copy, size: 20),
                    SizedBox(width: 8),
                    Text('添加到分组'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: BatchAction.enableUpdate,
                child: Row(
                  children: [
                    Icon(Icons.update, size: 20),
                    SizedBox(width: 8),
                    Text('启用更新'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: BatchAction.disableUpdate,
                child: Row(
                  children: [
                    Icon(Icons.update_disabled, size: 20),
                    SizedBox(width: 8),
                    Text('禁用更新'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: BatchAction.clearCache,
                child: Row(
                  children: [
                    Icon(Icons.storage, size: 20),
                    SizedBox(width: 8),
                    Text('清除缓存'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: BatchAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

