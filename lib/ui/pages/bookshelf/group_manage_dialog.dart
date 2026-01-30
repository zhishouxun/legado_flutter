import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_group.dart';
import '../../../services/book_group_service.dart';
import '../../../services/book/book_service.dart';
import '../../../providers/book_provider.dart';
import '../../widgets/base/base_bottom_sheet_consumer.dart';
import '../../widgets/common/custom_switch.dart';
import 'group_edit_dialog.dart';

/// 分组管理对话框
class GroupManageDialog extends BaseBottomSheetConsumer {
  const GroupManageDialog({super.key}) : super(
          title: '分组管理',
          heightFactor: 0.8,
        );

  @override
  ConsumerState<GroupManageDialog> createState() => _GroupManageDialogState();
}

class _GroupManageDialogState extends BaseBottomSheetConsumerState<GroupManageDialog> {
  @override
  Widget buildContent(BuildContext context) {
    final groupsAsync = ref.watch(bookGroupsProvider);

    return Column(
      children: [
        // 添加按钮
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  _showAddGroupDialog();
                },
                tooltip: '添加分组',
              ),
            ],
          ),
        ),
        // 分组列表
        Expanded(
          child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Center(
                      child: Text('暂无分组'),
                    );
                  }
                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _buildGroupItem(group);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('加载失败: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(bookGroupsProvider);
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
          ),
        ),
        // 底部按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ),
      ],
    );
  }

  /// 构建分组项
  Widget _buildGroupItem(BookGroup group) {
    // 系统分组不能编辑或删除
    final isSystemGroup = group.groupId < 0;

    return ListTile(
      title: Text(group.groupName),
      subtitle: Text('ID: ${group.groupId}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 显示/隐藏开关
          CustomSwitch(
            value: group.show,
            onChanged: isSystemGroup
                ? null
                : (value) async {
                    try {
                      await BookGroupService.instance.updateGroup(
                        group.copyWith(show: value),
                      );
                      ref.invalidate(bookGroupsProvider);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('操作失败: $e')),
                        );
                      }
                    }
                  },
          ),
          // 编辑按钮
          if (!isSystemGroup)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showEditGroupDialog(group);
              },
            ),
          // 删除按钮
          if (!isSystemGroup)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _showDeleteConfirmDialog(group);
              },
            ),
        ],
      ),
      onTap: isSystemGroup
          ? null
          : () {
              _showEditGroupDialog(group);
            },
    );
  }

  /// 显示添加分组对话框
  void _showAddGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => GroupEditDialog(),
    ).then((_) {
      ref.invalidate(bookGroupsProvider);
    });
  }

  /// 显示编辑分组对话框
  void _showEditGroupDialog(BookGroup group) {
    showDialog(
      context: context,
      builder: (context) => GroupEditDialog(group: group),
    ).then((_) {
      ref.invalidate(bookGroupsProvider);
    });
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BookGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定要删除分组"${group.groupName}"吗？\n分组中的书籍将移动到"全部"分组。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await BookGroupService.instance.deleteGroup(group.groupId);
                // 将分组中的书籍移动到"全部"分组
                final books =
                    await ref.read(booksByGroupProvider(group.groupId).future);
                for (final book in books) {
                  await BookService.instance
                      .updateBookGroup(book.bookUrl, BookGroup.idAll);
                }
                ref.invalidate(bookGroupsProvider);
                ref.invalidate(refreshBookshelfProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除分组')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
