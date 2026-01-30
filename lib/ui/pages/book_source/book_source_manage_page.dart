import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/book_source.dart';
import '../../../providers/book_source_provider.dart';
import '../../../services/source/book_source_service.dart';
import '../../../services/network/network_service.dart';
import 'book_source_item_widget.dart';
import 'book_source_edit_page.dart';
import 'book_source_import_dialog.dart';
import 'book_source_group_manage_dialog.dart';
import 'check_source_page.dart';

/// 书源管理页面
class BookSourceManagePage extends ConsumerStatefulWidget {
  const BookSourceManagePage({super.key});

  @override
  ConsumerState<BookSourceManagePage> createState() => _BookSourceManagePageState();
}

enum BookSourceSort {
  defaultSort,
  name,
  url,
  weight,
  update,
  enable,
  respond,
}

class _BookSourceManagePageState extends ConsumerState<BookSourceManagePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isBatchMode = false;
  Set<String> _selectedUrls = {};
  BookSourceSort _sortType = BookSourceSort.defaultSort;
  bool _sortAscending = true;
  List<BookSource> _currentFilteredSources = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookSourcesAsync = ref.watch(bookSourceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
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
            // 排序按钮
            PopupMenuButton<Map<String, dynamic>>(
              icon: const Icon(Icons.sort),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: {'sort': BookSourceSort.defaultSort, 'asc': _sortAscending},
                  child: Row(
                    children: [
                      Icon(_sortType == BookSourceSort.defaultSort ? Icons.check : null),
                      const SizedBox(width: 8),
                      const Text('默认排序'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: {'sort': BookSourceSort.name, 'asc': _sortAscending},
                  child: Row(
                    children: [
                      Icon(_sortType == BookSourceSort.name ? Icons.check : null),
                      const SizedBox(width: 8),
                      const Text('按名称'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: {'sort': BookSourceSort.url, 'asc': _sortAscending},
                  child: Row(
                    children: [
                      Icon(_sortType == BookSourceSort.url ? Icons.check : null),
                      const SizedBox(width: 8),
                      const Text('按URL'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: {'sort': BookSourceSort.update, 'asc': _sortAscending},
                  child: Row(
                    children: [
                      Icon(_sortType == BookSourceSort.update ? Icons.check : null),
                      const SizedBox(width: 8),
                      const Text('按更新时间'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: {'sort': _sortType, 'asc': !_sortAscending},
                  child: Row(
                    children: [
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                      const SizedBox(width: 8),
                      Text(_sortAscending ? '升序' : '降序'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                setState(() {
                  _sortType = value['sort'] as BookSourceSort;
                  _sortAscending = value['asc'] as bool;
                });
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 20),
                      SizedBox(width: 8),
                      Text('添加书源'),
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
                      Text('导入在线'),
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
                      Text('导出书源'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 8),
                      Text('分享书源'),
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
                const PopupMenuItem(
                  value: 'check',
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, size: 20),
                      SizedBox(width: 8),
                      Text('批量校验'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'add':
                    _addBookSource();
                    break;
                  case 'import_local':
                    _importFromLocal();
                    break;
                  case 'import_online':
                    _importFromOnline();
                    break;
                  case 'export':
                    _exportBookSources();
                    break;
                  case 'share':
                    _shareBookSources();
                    break;
                  case 'group_manage':
                    _showGroupManageDialog();
                    break;
                  case 'batch':
                    setState(() {
                      _isBatchMode = true;
                    });
                    break;
                  case 'check':
                    _startBatchCheck();
                    break;
                }
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 搜索框和快速筛选
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索书源（支持：启用、禁用、需要登录、无分组、group:分组名）',
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
                // 快速筛选按钮
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickFilterChip('启用', '启用'),
                      _buildQuickFilterChip('禁用', '禁用'),
                      _buildQuickFilterChip('需要登录', '需要登录'),
                      _buildQuickFilterChip('无分组', '无分组'),
                      _buildQuickFilterChip('启用发现', '启用发现'),
                      _buildQuickFilterChip('禁用发现', '禁用发现'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 批量操作栏
          if (_isBatchMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text('已选择 ${_selectedUrls.length} 项'),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('全选'),
                      onPressed: () => _selectAll(),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.deselect, size: 18),
                      label: const Text('取消'),
                      onPressed: () {
                        setState(() {
                          _selectedUrls.clear();
                        });
                      },
                    ),
                    if (_selectedUrls.isNotEmpty) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('启用'),
                        onPressed: () => _batchEnable(true),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('禁用'),
                        onPressed: () => _batchEnable(false),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.folder, size: 18),
                        label: const Text('分组'),
                        onPressed: () => _batchSetGroup(),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('删除'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () => _batchDelete(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // 书源列表
          Expanded(
            child: bookSourcesAsync.when(
              data: (sources) {
                return FutureBuilder<List<BookSource>>(
                  future: _filterAndSortSources(sources),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('加载失败: ${snapshot.error}'),
                          ],
                        ),
                      );
                    }
                    
                    final filteredSources = snapshot.data ?? [];
                    // 保存当前过滤后的书源列表，用于全选功能
                    _currentFilteredSources = filteredSources;
                    return _buildBookSourceList(filteredSources);
                  },
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
                        ref.invalidate(bookSourceListProvider);
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

  void _addBookSource() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BookSourceEditPage(),
      ),
    ).then((_) {
      ref.invalidate(bookSourceListProvider);
    });
  }

  void _editBookSource(BookSource source) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookSourceEditPage(bookSource: source),
      ),
    ).then((_) {
      ref.invalidate(bookSourceListProvider);
    });
  }

  void _toggleEnabled(BookSource source, bool enabled) {
    final updatedSource = BookSource(
      bookSourceUrl: source.bookSourceUrl,
      bookSourceName: source.bookSourceName,
      bookSourceGroup: source.bookSourceGroup,
      bookSourceType: source.bookSourceType,
      bookUrlPattern: source.bookUrlPattern,
      customOrder: source.customOrder,
      enabled: enabled,
      enabledExplore: source.enabledExplore,
      jsLib: source.jsLib,
      enabledCookieJar: source.enabledCookieJar,
      concurrentRate: source.concurrentRate,
      header: source.header,
      loginUrl: source.loginUrl,
      loginUi: source.loginUi,
      loginCheckJs: source.loginCheckJs,
      coverDecodeJs: source.coverDecodeJs,
      bookSourceComment: source.bookSourceComment,
      variableComment: source.variableComment,
      lastUpdateTime: source.lastUpdateTime,
      respondTime: source.respondTime,
      weight: source.weight,
      exploreUrl: source.exploreUrl,
      exploreScreen: source.exploreScreen,
      ruleExplore: source.ruleExplore,
      searchUrl: source.searchUrl,
      ruleSearch: source.ruleSearch,
      ruleBookInfo: source.ruleBookInfo,
      ruleToc: source.ruleToc,
      ruleContent: source.ruleContent,
    );

    BookSourceService.instance.updateBookSource(updatedSource).then((_) {
      ref.invalidate(bookSourceListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? '已启用' : '已禁用')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $error')),
      );
    });
  }

  void _deleteBookSource(BookSource source) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书源'),
        content: Text('确定要删除书源 "${source.bookSourceName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await BookSourceService.instance.deleteBookSource(source.bookSourceUrl);
                ref.invalidate(bookSourceListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('删除成功')),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _batchEnable(bool enabled) async {
    if (_selectedUrls.isEmpty) return;

    try {
      await BookSourceService.instance.batchSetEnabled(
        _selectedUrls.toList(),
        enabled,
      );
      
      ref.invalidate(bookSourceListProvider);
      
      if (mounted) {
        setState(() {
          _isBatchMode = false;
          _selectedUrls.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已${enabled ? '启用' : '禁用'} ${_selectedUrls.length} 个书源')),
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

  /// 全选当前显示的书源
  void _selectAll() {
    setState(() {
      _selectedUrls = _currentFilteredSources
          .map((source) => source.bookSourceUrl)
          .toSet();
    });
  }

  Future<void> _startBatchCheck() async {
    final sources = await BookSourceService.instance.getAllBookSources();
    if (sources.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可校验的书源')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CheckSourcePage(initialSources: sources),
        ),
      );
    }
  }

  Future<void> _batchSetGroup() async {
    if (_selectedUrls.isEmpty) return;

    final controller = TextEditingController();
    
    // 获取所有现有分组
    final allGroups = await BookSourceService.instance.getAllGroups();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量设置分组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已选择 ${_selectedUrls.length} 个书源'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '分组名称',
                hintText: '输入分组名称（留空表示移除分组）',
                border: OutlineInputBorder(),
              ),
            ),
            if (allGroups.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('现有分组：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allGroups.map((group) => ActionChip(
                  label: Text(group),
                  onPressed: () {
                    controller.text = group;
                  },
                )).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final groupName = controller.text.trim();
              
              try {
                await BookSourceService.instance.batchSetGroup(
                  _selectedUrls.toList(),
                  groupName.isEmpty ? null : groupName,
                );
                
                ref.invalidate(bookSourceListProvider);
                
                if (mounted) {
                  setState(() {
                    _isBatchMode = false;
                    _selectedUrls.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(groupName.isEmpty 
                          ? '已移除 ${_selectedUrls.length} 个书源的分组'
                          : '已将 ${_selectedUrls.length} 个书源设置为分组: $groupName'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('设置分组失败: $e')),
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

  void _batchDelete() {
    if (_selectedUrls.isEmpty) return;

    final count = _selectedUrls.length;
    // 获取要删除的书源名称列表
    final selectedSources = _currentFilteredSources
        .where((source) => _selectedUrls.contains(source.bookSourceUrl))
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要删除 $count 个书源吗？此操作不可恢复。'),
              if (selectedSources.isNotEmpty && selectedSources.length <= 10) ...[
                const SizedBox(height: 16),
                const Text(
                  '将要删除的书源：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...selectedSources.map((source) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${source.bookSourceName}',
                    style: const TextStyle(fontSize: 14),
                  ),
                )),
              ] else if (selectedSources.length > 10) ...[
                const SizedBox(height: 16),
                const Text(
                  '将要删除的书源（前10个）：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...selectedSources.take(10).map((source) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${source.bookSourceName}',
                    style: const TextStyle(fontSize: 14),
                  ),
                )),
                Text(
                  '... 还有 ${selectedSources.length - 10} 个书源',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await BookSourceService.instance.batchDeleteBookSources(
                  _selectedUrls.toList(),
                );
                
                ref.invalidate(bookSourceListProvider);
                
                if (mounted) {
                  setState(() {
                    _isBatchMode = false;
                    _selectedUrls.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已删除 $count 个书源')),
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        
        if (mounted) {
          _showImportDialog(content);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  void _importFromOnline() {
    final controller = TextEditingController();
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('从在线导入'),
          content: isLoading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在获取书源...'),
                  ],
                )
              : TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '请输入书源URL或JSON内容',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  autofocus: true,
                ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.pop(context),
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
                        final fetchedContent = await NetworkService.getResponseText(response);
                        
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

  Future<void> _exportBookSources() async {
    try {
      final sources = await BookSourceService.instance.getAllBookSources();
      
      if (sources.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可导出的书源')),
        );
        return;
      }

      final jsonString = jsonEncode(sources.map((s) => s.toJson()).toList());
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出书源',
        fileName: 'bookSource-${DateTime.now().millisecondsSinceEpoch}.json',
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

  /// 分享书源
  Future<void> _shareBookSources() async {
    try {
      List<BookSource> sources;
      
      // 如果处于批量模式且有选中项，只分享选中的书源
      if (_isBatchMode && _selectedUrls.isNotEmpty) {
        final allSources = await BookSourceService.instance.getAllBookSources();
        sources = allSources.where((s) => _selectedUrls.contains(s.bookSourceUrl)).toList();
      } else {
        // 否则分享所有书源
        sources = await BookSourceService.instance.getAllBookSources();
      }
      
      if (sources.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可分享的书源')),
        );
        return;
      }

      final jsonString = jsonEncode(sources.map((s) => s.toJson()).toList());
      
      // 使用 share_plus 包分享
      await Share.share(
        jsonString,
        subject: '书源分享 (${sources.length}个)',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已分享 ${sources.length} 个书源')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  void _showImportDialog(String content) {
    showDialog(
      context: context,
      builder: (context) => BookSourceImportDialog(
        content: content,
        onImportComplete: () {
          ref.invalidate(bookSourceListProvider);
        },
      ),
    );
  }

  /// 过滤和排序书源
  Future<List<BookSource>> _filterAndSortSources(List<BookSource> sources) async {
    List<BookSource> filteredSources;
    
    if (_searchQuery.isEmpty) {
      filteredSources = sources;
    } else {
      // 处理特殊搜索关键词
      final query = _searchQuery.trim();
      
      if (query == '启用' || query == 'enabled') {
        filteredSources = await BookSourceService.instance.getEnabledBookSources();
      } else if (query == '禁用' || query == 'disabled') {
        filteredSources = await BookSourceService.instance.getDisabledBookSources();
      } else if (query == '需要登录' || query == 'need_login') {
        filteredSources = await BookSourceService.instance.getLoginBookSources();
      } else if (query == '无分组' || query == 'no_group') {
        filteredSources = await BookSourceService.instance.getNoGroupBookSources();
      } else if (query == '启用发现' || query == 'enabled_explore') {
        filteredSources = await BookSourceService.instance.getEnabledExploreBookSources();
      } else if (query == '禁用发现' || query == 'disabled_explore') {
        filteredSources = await BookSourceService.instance.getDisabledExploreBookSources();
      } else if (query.startsWith('group:')) {
        final groupName = query.substring(6).trim();
        filteredSources = await BookSourceService.instance.searchBookSourcesByGroup(groupName);
      } else {
        // 普通搜索
        filteredSources = await BookSourceService.instance.searchBookSources(query);
      }
    }

    // 排序
    return _sortSources(filteredSources);
  }

  /// 构建书源列表
  Widget _buildBookSourceList(List<BookSource> filteredSources) {
    if (filteredSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.source_outlined : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? '暂无书源' : '未找到匹配的书源',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookSourceListProvider);
      },
      child: ListView.builder(
        itemCount: filteredSources.length,
        itemBuilder: (context, index) {
          final source = filteredSources[index];
          final isSelected = _selectedUrls.contains(source.bookSourceUrl);

          return BookSourceItemWidget(
            bookSource: source,
            isBatchMode: _isBatchMode,
            isSelected: isSelected,
            onTap: () {
              if (_isBatchMode) {
                setState(() {
                  if (isSelected) {
                    _selectedUrls.remove(source.bookSourceUrl);
                  } else {
                    _selectedUrls.add(source.bookSourceUrl);
                  }
                });
              } else {
                _editBookSource(source);
              }
            },
            onLongPress: () {
              if (!_isBatchMode) {
                setState(() {
                  _isBatchMode = true;
                  _selectedUrls.add(source.bookSourceUrl);
                });
              }
            },
            onToggleEnabled: (enabled) {
              _toggleEnabled(source, enabled);
            },
            onDelete: () {
              _deleteBookSource(source);
            },
            onEdit: () {
              _editBookSource(source);
            },
          );
        },
      ),
    );
  }

  /// 排序书源
  List<BookSource> _sortSources(List<BookSource> sources) {
    final sorted = List<BookSource>.from(sources);
    
    switch (_sortType) {
      case BookSourceSort.name:
        sorted.sort((a, b) {
          final result = a.bookSourceName.compareTo(b.bookSourceName);
          return _sortAscending ? result : -result;
        });
        break;
      case BookSourceSort.url:
        sorted.sort((a, b) {
          final result = a.bookSourceUrl.compareTo(b.bookSourceUrl);
          return _sortAscending ? result : -result;
        });
        break;
      case BookSourceSort.update:
        sorted.sort((a, b) {
          final result = a.lastUpdateTime.compareTo(b.lastUpdateTime);
          return _sortAscending ? result : -result;
        });
        break;
      case BookSourceSort.weight:
        sorted.sort((a, b) {
          final result = a.weight.compareTo(b.weight);
          return _sortAscending ? result : -result;
        });
        break;
      case BookSourceSort.enable:
        sorted.sort((a, b) {
          if (a.enabled != b.enabled) {
            return _sortAscending
                ? (a.enabled ? 1 : -1)
                : (a.enabled ? -1 : 1);
          }
          return a.bookSourceName.compareTo(b.bookSourceName);
        });
        break;
      case BookSourceSort.respond:
        sorted.sort((a, b) {
          final result = a.respondTime.compareTo(b.respondTime);
          return _sortAscending ? result : -result;
        });
        break;
      case BookSourceSort.defaultSort:
        // 默认排序：按 customOrder，然后按名称
        sorted.sort((a, b) {
          if (a.customOrder != b.customOrder) {
            return a.customOrder.compareTo(b.customOrder);
          }
          return a.bookSourceName.compareTo(b.bookSourceName);
        });
        break;
    }
    
    return sorted;
  }

  /// 构建快速筛选按钮
  Widget _buildQuickFilterChip(String label, String query) {
    final isSelected = _searchQuery == query;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (selected) {
              _searchQuery = query;
              _searchController.text = query;
            } else {
              _searchQuery = '';
              _searchController.clear();
            }
          });
        },
      ),
    );
  }

  /// 显示分组管理对话框
  void _showGroupManageDialog() {
    showDialog(
      context: context,
      builder: (context) => const BookSourceGroupManageDialog(),
    ).then((_) {
      ref.invalidate(bookSourceListProvider);
    });
  }
}

