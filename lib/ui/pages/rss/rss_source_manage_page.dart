import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/rss_source.dart';
import '../../../services/rss_service.dart';
import 'rss_source_item_widget.dart';
import 'rss_source_edit_page.dart';
import 'rss_source_import_dialog.dart';
import 'rss_group_manage_dialog.dart';

/// RSS源列表Provider
final rssSourceListProvider = FutureProvider<List<RssSource>>((ref) async {
  final service = RssService.instance;
  return await service.getAllRssSources();
});

/// RSS源管理页面
class RssSourceManagePage extends ConsumerStatefulWidget {
  const RssSourceManagePage({super.key});

  @override
  ConsumerState<RssSourceManagePage> createState() =>
      _RssSourceManagePageState();
}

class _RssSourceManagePageState extends ConsumerState<RssSourceManagePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isBatchMode = false;
  final Set<String> _selectedUrls = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rssSourcesAsync = ref.watch(rssSourceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS源管理'),
        actions: [
          if (_isBatchMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isBatchMode = false;
                  _selectedUrls.clear();
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (context) => const RssSourceEditPage(),
                  ),
                )
                    .then((_) {
                  ref.invalidate(rssSourceListProvider);
                });
              },
              tooltip: '添加RSS源',
            ),
            IconButton(
              icon: const Icon(Icons.file_upload),
              onPressed: () => _showImportDialog(),
              tooltip: '导入RSS源',
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => const RssGroupManageDialog(),
                );
              },
              tooltip: '分组管理',
            ),
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  _isBatchMode = true;
                });
              },
              tooltip: '批量操作',
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索RSS源',
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
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: rssSourcesAsync.when(
        data: (sources) {
          final filteredSources = _filterSources(sources, _searchQuery);

          if (filteredSources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rss_feed,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty ? '暂无RSS源' : '未找到匹配的RSS源',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                          MaterialPageRoute(
                            builder: (context) => const RssSourceEditPage(),
                          ),
                        )
                            .then((_) {
                          ref.invalidate(rssSourceListProvider);
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('添加RSS源'),
                    ),
                  ],
                ],
              ),
            );
          }

          return Column(
            children: [
              if (_isBatchMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      Text('已选择 ${_selectedUrls.length} 项'),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            _selectedUrls.isEmpty ? null : _enableSelected,
                        child: const Text('启用'),
                      ),
                      TextButton(
                        onPressed:
                            _selectedUrls.isEmpty ? null : _disableSelected,
                        child: const Text('禁用'),
                      ),
                      TextButton(
                        onPressed:
                            _selectedUrls.isEmpty ? null : _deleteSelected,
                        child: const Text('删除',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isBatchMode
                    ? ListView.builder(
                        itemCount: filteredSources.length,
                        itemBuilder: (context, index) {
                          final source = filteredSources[index];
                          final isSelected = _selectedUrls.contains(source.sourceUrl);

                          return RssSourceItemWidget(
                            source: source,
                            isSelected: isSelected,
                            isBatchMode: _isBatchMode,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUrls.remove(source.sourceUrl);
                                } else {
                                  _selectedUrls.add(source.sourceUrl);
                                }
                              });
                            },
                            onLongPress: () {},
                            onToggleEnabled: (enabled) async {
                              await RssService.instance.updateRssSourceEnabled(
                                source.sourceUrl,
                                enabled,
                              );
                              ref.invalidate(rssSourceListProvider);
                            },
                          );
                        },
                      )
                    : ReorderableListView.builder(
                        itemCount: filteredSources.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          _handleReorder(filteredSources, oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final source = filteredSources[index];

                          return RssSourceItemWidget(
                            key: ValueKey(source.sourceUrl),
                            source: source,
                            isSelected: false,
                            isBatchMode: false,
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      RssSourceEditPage(source: source),
                                ),
                              )
                                  .then((_) {
                                ref.invalidate(rssSourceListProvider);
                              });
                            },
                            onLongPress: () {
                              setState(() {
                                _isBatchMode = true;
                                _selectedUrls.add(source.sourceUrl);
                              });
                            },
                            onToggleEnabled: (enabled) async {
                              await RssService.instance.updateRssSourceEnabled(
                                source.sourceUrl,
                                enabled,
                              );
                              ref.invalidate(rssSourceListProvider);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(rssSourceListProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 过滤RSS源
  List<RssSource> _filterSources(List<RssSource> sources, String query) {
    if (query.isEmpty) return sources;

    final lowerQuery = query.toLowerCase();
    return sources.where((source) {
      return source.sourceName.toLowerCase().contains(lowerQuery) ||
          (source.sourceUrl.toLowerCase().contains(lowerQuery)) ||
          (source.sourceGroup?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// 显示导入对话框
  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => const RssSourceImportDialog(),
    ).then((_) {
      ref.invalidate(rssSourceListProvider);
    });
  }

  /// 启用选中的源
  Future<void> _enableSelected() async {
    for (final url in _selectedUrls) {
      await RssService.instance.updateRssSourceEnabled(url, true);
    }
    setState(() {
      _selectedUrls.clear();
      _isBatchMode = false;
    });
    ref.invalidate(rssSourceListProvider);
  }

  /// 禁用选中的源
  Future<void> _disableSelected() async {
    for (final url in _selectedUrls) {
      await RssService.instance.updateRssSourceEnabled(url, false);
    }
    setState(() {
      _selectedUrls.clear();
      _isBatchMode = false;
    });
    ref.invalidate(rssSourceListProvider);
  }

  /// 处理拖拽排序
  Future<void> _handleReorder(
      List<RssSource> sources, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final reorderedSources = List<RssSource>.from(sources);
    final source = reorderedSources.removeAt(oldIndex);
    reorderedSources.insert(newIndex, source);

    try {
      // 更新customOrder
      for (int i = 0; i < reorderedSources.length; i++) {
        final updatedSource = reorderedSources[i].copyWith(customOrder: i);
        await RssService.instance.addOrUpdateRssSource(updatedSource);
      }
      ref.invalidate(rssSourceListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('排序失败: $e')),
        );
      }
    }
  }

  /// 删除选中的源
  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedUrls.length} 个RSS源吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final url in _selectedUrls) {
      await RssService.instance.deleteRssSource(url);
    }
    setState(() {
      _selectedUrls.clear();
      _isBatchMode = false;
    });
    ref.invalidate(rssSourceListProvider);
  }
}
