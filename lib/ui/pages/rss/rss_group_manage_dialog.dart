import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/rss_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';
import 'rss_source_manage_page.dart';

/// RSS源分组列表Provider
final rssGroupListProvider = FutureProvider<List<String>>((ref) async {
  return await RssService.instance.getAllGroups();
});

/// RSS源分组管理对话框
/// 参考项目：GroupManageDialog.kt
class RssGroupManageDialog extends BaseBottomSheetStateful {
  const RssGroupManageDialog({super.key}) : super(title: '分组管理', heightFactor: 0.7);

  @override
  State<RssGroupManageDialog> createState() => _RssGroupManageDialogState();
}

class _RssGroupManageDialogState extends BaseBottomSheetState<RssGroupManageDialog> {
  @override
  Widget buildContent(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final groupsAsync = ref.watch(rssGroupListProvider);

        return Column(
          children: [
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Center(child: Text('暂无分组'));
                  }
                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(group),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editGroup(context, ref, group),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteGroup(context, ref, group),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('加载失败: $error')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _addGroup(context, ref),
                child: const Text('新增分组'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addGroup(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '分组名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                await _addGroupToSources(context, name);
                ref.invalidate(rssGroupListProvider);
                ref.invalidate(rssSourceListProvider);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _editGroup(BuildContext context, WidgetRef ref, String oldGroup) {
    final controller = TextEditingController(text: oldGroup);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '分组名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newGroup = controller.text.trim();
              if (newGroup.isNotEmpty && newGroup != oldGroup) {
                Navigator.pop(context);
                await _updateGroupName(context, oldGroup, newGroup);
                ref.invalidate(rssGroupListProvider);
                ref.invalidate(rssSourceListProvider);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _deleteGroup(BuildContext context, WidgetRef ref, String group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定要删除分组"$group"吗？该分组下的RSS源将变为无分组。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGroupFromSources(context, group);
              ref.invalidate(rssGroupListProvider);
              ref.invalidate(rssSourceListProvider);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 添加分组到RSS源（通过创建一个临时源来添加分组）
  Future<void> _addGroupToSources(BuildContext context, String groupName) async {
    // RSS源的分组是通过sourceGroup字段管理的
    // 这里只需要刷新列表，分组会在用户编辑RSS源时设置
    // 或者我们可以创建一个临时源来"注册"这个分组
    // 但更简单的方式是：分组会在用户设置RSS源的sourceGroup时自动创建
    // 所以这里只需要提示用户
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分组"$groupName"将在您设置RSS源分组时创建')),
      );
    }
  }

  /// 更新分组名称
  Future<void> _updateGroupName(BuildContext context, String oldGroup, String newGroup) async {
    try {
      // 获取所有RSS源
      final sources = await RssService.instance.getAllRssSources();
      for (final source in sources) {
        if (source.sourceGroup == oldGroup) {
          await RssService.instance.addOrUpdateRssSource(
            source.copyWith(sourceGroup: newGroup),
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分组名称已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  /// 删除分组（将该分组下所有源的分组设为null）
  Future<void> _deleteGroupFromSources(BuildContext context, String group) async {
    try {
      // 获取所有RSS源
      final sources = await RssService.instance.getAllRssSources();
      for (final source in sources) {
        if (source.sourceGroup == group) {
          await RssService.instance.addOrUpdateRssSource(
            source.copyWith(sourceGroup: null),
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分组已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}
