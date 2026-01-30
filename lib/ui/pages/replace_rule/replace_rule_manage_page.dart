import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/models/replace_rule.dart';
import '../../../services/replace_rule_service.dart';
import '../../../services/network/network_service.dart';
import 'replace_rule_item_widget.dart';
import 'replace_rule_edit_dialog.dart';
import 'replace_rule_import_dialog.dart';
import 'group_manage_dialog.dart';

/// 替换规则列表Provider
final replaceRuleListProvider = FutureProvider<List<ReplaceRule>>((ref) async {
  return await ReplaceRuleService.instance.getAllRules();
});

/// 替换规则管理页面
class ReplaceRuleManagePage extends ConsumerStatefulWidget {
  const ReplaceRuleManagePage({super.key});

  @override
  ConsumerState<ReplaceRuleManagePage> createState() =>
      _ReplaceRuleManagePageState();
}

class _ReplaceRuleManagePageState extends ConsumerState<ReplaceRuleManagePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedGroup; // 选中的分组，null表示全部，'__no_group__'表示无分组
  bool _isBatchMode = false;
  final Set<int> _selectedIds = {};
  List<String> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await ReplaceRuleService.instance.getAllGroups();
    setState(() {
      _groups = groups;
    });
  }

  void _showGroupManageDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => GroupManageDialog(
        onGroupChanged: () {
          _loadGroups();
          ref.invalidate(replaceRuleListProvider);
        },
      ),
    );
  }

  Widget _buildGroupChip(String label, String? groupValue) {
    final isSelected = _selectedGroup == groupValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedGroup = selected ? groupValue : null;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(replaceRuleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('替换规则'),
        actions: [
          if (_isBatchMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isBatchMode = false;
                  _selectedIds.clear();
                });
              },
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 20),
                      SizedBox(width: 8),
                      Text('新增规则'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import_local',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload, size: 20),
                      SizedBox(width: 8),
                      Text('导入本地'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import_online',
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 20),
                      SizedBox(width: 8),
                      Text('网络导入'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import_default',
                  child: Row(
                    children: [
                      Icon(Icons.restore, size: 20),
                      SizedBox(width: 8),
                      Text('导入默认规则'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download, size: 20),
                      SizedBox(width: 8),
                      Text('导出规则'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'batch',
                  child: Row(
                    children: [
                      Icon(Icons.select_all, size: 20),
                      SizedBox(width: 8),
                      Text('批量操作'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'group_manage',
                  child: Row(
                    children: [
                      Icon(Icons.folder, size: 20),
                      SizedBox(width: 8),
                      Text('分组管理'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'add':
                    _addRule();
                    break;
                  case 'import_local':
                    _importFromLocal();
                    break;
                  case 'import_online':
                    _importFromOnline();
                    break;
                  case 'import_default':
                    _importDefaultRules();
                    break;
                  case 'export':
                    _exportRules();
                    break;
                  case 'batch':
                    setState(() {
                      _isBatchMode = true;
                    });
                    break;
                  case 'group_manage':
                    _showGroupManageDialog();
                    break;
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框和分组筛选
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索规则',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                // 分组筛选
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildGroupChip('全部', null),
                      _buildGroupChip('无分组', '__no_group__'),
                      ..._groups.map((group) => _buildGroupChip(group, group)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 批量操作栏
          if (_isBatchMode && _selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Text('已选择 ${_selectedIds.length} 项'),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('启用'),
                    onPressed: () => _batchEnable(true),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text('禁用'),
                    onPressed: () => _batchEnable(false),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('删除'),
                    onPressed: () => _batchDelete(),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.vertical_align_top),
                    label: const Text('置顶'),
                    onPressed: () => _batchMoveToTop(),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.vertical_align_bottom),
                    label: const Text('置底'),
                    onPressed: () => _batchMoveToBottom(),
                  ),
                ],
              ),
            ),
          // 规则列表
          Expanded(
            child: rulesAsync.when(
              data: (rules) {
                // 过滤规则
                final filteredRules = _searchQuery.isEmpty
                    ? rules
                    : rules.where((rule) {
                        final query = _searchQuery.toLowerCase();
                        return rule.name.toLowerCase().contains(query) ||
                            rule.pattern.toLowerCase().contains(query) ||
                            rule.replacement.toLowerCase().contains(query) ||
                            (rule.group?.toLowerCase().contains(query) ??
                                false);
                      }).toList();

                if (filteredRules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.find_replace_outlined
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? '暂无规则' : '未找到匹配的规则',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(replaceRuleListProvider);
                  },
                  child: ReorderableListView.builder(
                    itemCount: filteredRules.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      _handleReorder(filteredRules, oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final rule = filteredRules[index];
                      final isSelected = _selectedIds.contains(rule.id);

                      return ReplaceRuleItemWidget(
                        key: ValueKey(rule.id),
                        rule: rule,
                        isBatchMode: _isBatchMode,
                        isSelected: isSelected,
                        onTap: () {
                          if (_isBatchMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(rule.id);
                              } else {
                                _selectedIds.add(rule.id);
                              }
                            });
                          } else {
                            _editRule(rule);
                          }
                        },
                        onLongPress: () {
                          if (!_isBatchMode) {
                            setState(() {
                              _isBatchMode = true;
                              _selectedIds.add(rule.id);
                            });
                          }
                        },
                        onToggleEnabled: (enabled) {
                          _toggleEnabled(rule, enabled);
                        },
                        onDelete: () {
                          _deleteRule(rule);
                        },
                        onEdit: () {
                          _editRule(rule);
                        },
                        onMoveToTop: () {
                          _moveToTop(rule);
                        },
                        onMoveToBottom: () {
                          _moveToBottom(rule);
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('加载失败: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(replaceRuleListProvider);
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 添加规则
  void _addRule() {
    showDialog(
      context: context,
      builder: (context) => ReplaceRuleEditDialog(
        onSave: (rule) async {
          await ReplaceRuleService.instance.addOrUpdateRule(rule);
          ref.invalidate(replaceRuleListProvider);
        },
      ),
    );
  }

  // 编辑规则
  void _editRule(ReplaceRule rule) {
    showDialog(
      context: context,
      builder: (context) => ReplaceRuleEditDialog(
        rule: rule,
        onSave: (updatedRule) async {
          await ReplaceRuleService.instance.addOrUpdateRule(updatedRule);
          ref.invalidate(replaceRuleListProvider);
        },
      ),
    );
  }

  // 置顶规则
  Future<void> _moveToTop(ReplaceRule rule) async {
    try {
      await ReplaceRuleService.instance.moveToTop(rule);
      ref.invalidate(replaceRuleListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已置顶')),
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

  // 置底规则
  Future<void> _moveToBottom(ReplaceRule rule) async {
    try {
      await ReplaceRuleService.instance.moveToBottom(rule);
      ref.invalidate(replaceRuleListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已置底')),
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

  // 切换启用状态
  void _toggleEnabled(ReplaceRule rule, bool enabled) async {
    try {
      await ReplaceRuleService.instance
          .updateRule(rule.copyWith(enabled: enabled));
      ref.invalidate(replaceRuleListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  // 删除规则
  void _deleteRule(ReplaceRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定要删除规则"${rule.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ReplaceRuleService.instance.deleteRuleById(rule.id);
                ref.invalidate(replaceRuleListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除')),
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

  // 批量置顶
  Future<void> _batchMoveToTop() async {
    if (_selectedIds.isEmpty) return;

    try {
      await ReplaceRuleService.instance.batchMoveToTop(_selectedIds.toList());
      final count = _selectedIds.length;
      setState(() {
        _selectedIds.clear();
        _isBatchMode = false;
      });
      ref.invalidate(replaceRuleListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已置顶 $count 项')),
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

  // 批量置底
  Future<void> _batchMoveToBottom() async {
    if (_selectedIds.isEmpty) return;

    try {
      await ReplaceRuleService.instance.batchMoveToBottom(_selectedIds.toList());
      final count = _selectedIds.length;
      setState(() {
        _selectedIds.clear();
        _isBatchMode = false;
      });
      ref.invalidate(replaceRuleListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已置底 $count 项')),
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

  // 批量启用/禁用
  Future<void> _batchEnable(bool enabled) async {
    if (_selectedIds.isEmpty) return;

    try {
      await ReplaceRuleService.instance.batchSetEnabledByIds(
        _selectedIds.toList(),
        enabled,
      );
      final count = _selectedIds.length;
      setState(() {
        _selectedIds.clear();
        _isBatchMode = false;
      });
      ref.invalidate(replaceRuleListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已${enabled ? '启用' : '禁用'} $count 项')),
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

  // 批量删除
  void _batchDelete() {
    if (_selectedIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 项规则吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ReplaceRuleService.instance
                    .deleteRulesByIds(_selectedIds.toList());
                final count = _selectedIds.length;
                setState(() {
                  _selectedIds.clear();
                  _isBatchMode = false;
                });
                ref.invalidate(replaceRuleListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已删除 $count 项')),
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

  // 处理排序
  void _handleReorder(
      List<ReplaceRule> rules, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final reorderedRules = List<ReplaceRule>.from(rules);
    final rule = reorderedRules.removeAt(oldIndex);
    reorderedRules.insert(newIndex, rule);

    try {
      await ReplaceRuleService.instance.updateOrder(reorderedRules);
      ref.invalidate(replaceRuleListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('排序失败: $e')),
        );
      }
    }
  }

  // 从本地导入
  Future<void> _importFromLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'json'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      _showImportDialog(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  // 从网络导入
  void _importFromOnline() {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('网络导入'),
          content: isLoading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在获取规则...'),
                  ],
                )
              : TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '请输入规则URL或JSON内容',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  autofocus: true,
                ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final content = controller.text.trim();
                      if (content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入URL或JSON内容')),
                        );
                        return;
                      }

                      // 如果是URL，尝试从网络获取
                      final uri = Uri.tryParse(content);
                      if (uri != null && uri.hasScheme) {
                        setDialogState(() {
                          isLoading = true;
                        });

                        try {
                          final response = await NetworkService.instance.get(
                            content,
                            retryCount: 1,
                          );
                          final fetchedContent =
                              await NetworkService.getResponseText(response);

                          if (!mounted) return;
                          Navigator.pop(context);
                          _showImportDialog(fetchedContent);
                        } catch (e) {
                          if (!mounted) return;
                          setDialogState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('获取失败: $e')),
                          );
                        }
                      } else {
                        // 直接作为JSON内容处理
                        Navigator.pop(context);
                        _showImportDialog(content);
                      }
                    },
              child: const Text('导入'),
            ),
          ],
        ),
      ),
    );
  }

  // 导入默认规则
  Future<void> _importDefaultRules() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入默认规则'),
        content: const Text('导入默认替换规则。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ReplaceRuleService.instance.importDefaultRules();
                ref.invalidate(replaceRuleListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('导入成功')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('导入失败: $e')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 导出规则
  Future<void> _exportRules() async {
    try {
      final rules = await ReplaceRuleService.instance.getAllRules();

      if (rules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可导出的规则')),
        );
        return;
      }

      final jsonString = jsonEncode(rules.map((r) => r.toJson()).toList());

      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出规则',
        fileName: 'replaceRule-${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  // 显示导入对话框
  void _showImportDialog(String content) {
    showDialog(
      context: context,
      builder: (context) => ReplaceRuleImportDialog(
        content: content,
        onImportComplete: () {
          ref.invalidate(replaceRuleListProvider);
        },
      ),
    );
  }
}
