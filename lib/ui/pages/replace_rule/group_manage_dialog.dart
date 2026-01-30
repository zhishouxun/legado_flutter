import 'package:flutter/material.dart';
import '../../../services/replace_rule_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 分组管理对话框
class GroupManageDialog extends BaseBottomSheetStateful {
  final VoidCallback? onGroupChanged;

  const GroupManageDialog({
    super.key,
    this.onGroupChanged,
  }) : super(
          title: '分组管理',
          heightFactor: 0.8,
        );

  @override
  State<GroupManageDialog> createState() => _GroupManageDialogState();
}

class _GroupManageDialogState extends BaseBottomSheetState<GroupManageDialog> {
  List<String> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await ReplaceRuleService.instance.getAllGroups();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载分组失败: $e')),
        );
      }
    }
  }

  Future<void> _addGroup() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入分组名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      // 检查分组是否已存在
      if (_groups.contains(result.trim())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('分组已存在')),
          );
        }
        return;
      }

      // 添加分组（通过创建一个临时规则来创建分组）
      // 注意：这里只是添加分组名称到列表，实际分组会在规则中使用时创建
      setState(() {
        _groups.add(result.trim());
        _groups.sort();
      });

      widget.onGroupChanged?.call();
    }
  }

  Future<void> _editGroup(String oldGroup) async {
    final controller = TextEditingController(text: oldGroup);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入分组名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null &&
        result.trim().isNotEmpty &&
        result.trim() != oldGroup) {
      // 检查新分组名是否已存在
      if (_groups.contains(result.trim())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('分组已存在')),
          );
        }
        return;
      }

      try {
        // 更新分组名称
        await ReplaceRuleService.instance
            .updateGroupName(oldGroup, result.trim());

        setState(() {
          final index = _groups.indexOf(oldGroup);
          if (index != -1) {
            _groups[index] = result.trim();
            _groups.sort();
          }
        });

        widget.onGroupChanged?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('分组已更新')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新分组失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteGroup(String group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定要删除分组"$group"吗？\n该分组下的规则将变为无分组。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 删除分组（将该分组下所有规则的分组设为null）
        await ReplaceRuleService.instance.deleteGroup(group);

        setState(() {
          _groups.remove(group);
        });

        widget.onGroupChanged?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('分组已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除分组失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 添加分组按钮
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('添加分组'),
            onPressed: _addGroup,
          ),
        ),
        // 分组列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _groups.isEmpty
                  ? const Center(
                      child: Text('暂无分组'),
                    )
                  : ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return ListTile(
                          title: Text(group),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editGroup(group),
                                tooltip: '编辑',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteGroup(group),
                                tooltip: '删除',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
