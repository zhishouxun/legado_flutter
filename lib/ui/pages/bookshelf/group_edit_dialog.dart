import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_group.dart';
import '../../../services/book_group_service.dart';
import '../../../services/book/book_service.dart';
import '../../../providers/book_provider.dart';
import '../../widgets/common/custom_switch_list_tile.dart';

/// 分组编辑对话框
class GroupEditDialog extends ConsumerStatefulWidget {
  final BookGroup? group;

  const GroupEditDialog({super.key, this.group});

  @override
  ConsumerState<GroupEditDialog> createState() => _GroupEditDialogState();
}

class _GroupEditDialogState extends ConsumerState<GroupEditDialog> {
  late TextEditingController _nameController;
  bool _enableRefresh = true;
  int _bookSort = -1; // -1表示使用全局设置

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.group?.groupName ?? '');
    _enableRefresh = widget.group?.enableRefresh ?? true;
    _bookSort = widget.group?.bookSort ?? -1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.group != null;
    final isSystemGroup =
        widget.group?.groupId != null && widget.group!.groupId < 0;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    isEdit ? '编辑分组' : '添加分组',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 分组名称
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '分组名称',
                        hintText: '请输入分组名称',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !isSystemGroup,
                    ),
                    const SizedBox(height: 16),
                    // 书籍排序方式
                    DropdownButtonFormField<int>(
                      initialValue: _bookSort,
                      decoration: const InputDecoration(
                        labelText: '书籍排序方式',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: -1,
                          child: Text('使用全局设置'),
                        ),
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('按阅读时间'),
                        ),
                        const DropdownMenuItem(
                          value: 1,
                          child: Text('按更新时间'),
                        ),
                        const DropdownMenuItem(
                          value: 2,
                          child: Text('按书名'),
                        ),
                        const DropdownMenuItem(
                          value: 3,
                          child: Text('手动排序'),
                        ),
                        const DropdownMenuItem(
                          value: 4,
                          child: Text('综合排序'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _bookSort = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // 启用刷新
                    CustomSwitchListTile(
                      title: const Text('启用刷新'),
                      subtitle: const Text('允许自动检查更新'),
                      value: _enableRefresh,
                      onChanged: isSystemGroup
                          ? null
                          : (value) {
                              setState(() {
                                _enableRefresh = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEdit && !isSystemGroup)
                    TextButton(
                      onPressed: () {
                        _showDeleteConfirmDialog();
                      },
                      child:
                          const Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isSystemGroup ? null : _saveGroup,
                    child: Text(isEdit ? '保存' : '创建'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存分组
  Future<void> _saveGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分组名称不能为空')),
      );
      return;
    }

    try {
      if (widget.group != null) {
        // 更新分组
        final updatedGroup = widget.group!.copyWith(
          groupName: name,
          enableRefresh: _enableRefresh,
          bookSort: _bookSort,
        );
        await BookGroupService.instance.updateGroup(updatedGroup);
      } else {
        // 创建新分组
        final nextId = await BookGroupService.instance.getNextGroupId();
        final newGroup = BookGroup(
          groupId: nextId,
          groupName: name,
          enableRefresh: _enableRefresh,
          bookSort: _bookSort,
          order: 0,
          show: true,
        );
        await BookGroupService.instance.createGroup(newGroup);
      }

      ref.invalidate(bookGroupsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.group != null ? '已更新分组' : '已创建分组'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content:
            Text('确定要删除分组"${widget.group?.groupName}"吗？\n分组中的书籍将移动到"全部"分组。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 关闭确认对话框
              Navigator.pop(context); // 关闭编辑对话框
              try {
                final group = widget.group!;
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
