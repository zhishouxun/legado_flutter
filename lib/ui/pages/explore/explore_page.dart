import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_source.dart';
import '../../../data/models/explore_kind.dart';
import '../../../services/source/book_source_service.dart';
import '../../../services/explore_service.dart';
import '../../../providers/scroll_control_provider.dart';
import '../book_source/book_source_edit_page.dart';
import '../book_source/source_login_page.dart';
import 'explore_show_page.dart';
import '../search/search_page.dart';

/// 发现页面
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<BookSource> _bookSources = [];
  List<String> _groups = [];
  bool _isLoading = true;
  String? _searchKeyword;
  String? _selectedGroup;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 滚动到顶部（压缩发现列表）
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 加载分组
      final groups = await BookSourceService.instance.getExploreGroups();

      // 加载书源
      List<BookSource> sources;
      if (_searchKeyword != null && _searchKeyword!.isNotEmpty) {
        // 优先处理搜索
        sources = await BookSourceService.instance
            .searchExploreBookSources(_searchKeyword!);
      } else if (_selectedGroup != null && _selectedGroup!.isNotEmpty) {
        // 按分组筛选
        sources = await BookSourceService.instance
            .getExploreBookSourcesByGroup(_selectedGroup!);
      } else {
        // 全部分组
        sources =
            await BookSourceService.instance.getEnabledExploreBookSources();
      }

      setState(() {
        _groups = groups;
        _bookSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchKeyword = value.isEmpty ? null : value;
    });
    _loadData();
  }

  void _onGroupSelected(String? group) {
    setState(() {
      _selectedGroup = group;
      _searchKeyword = null;
      _searchController.clear();
      _expandedIndex = null; // 切换分组时折叠所有展开的项
    });
    _loadData();
  }

  void _toggleExpand(int index) {
    setState(() {
      if (_expandedIndex == index) {
        // 折叠
        _expandedIndex = null;
      } else {
        // 展开
        _expandedIndex = index;
      }
    });
  }

  void _openExplore(BookSource source, String title, String exploreUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExploreShowPage(
          bookSource: source,
          exploreName: title,
          exploreUrl: exploreUrl,
        ),
      ),
    );
  }

  void _editSource(BookSource source) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => BookSourceEditPage(bookSource: source),
          ),
        )
        .then((_) => _loadData());
  }

  Future<void> _topSource(BookSource source) async {
    try {
      final minOrder = await BookSourceService.instance.getMinOrder();
      await BookSourceService.instance.updateBookSource(
        source.copyWith(customOrder: minOrder - 1),
      );
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('置顶失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteSource(BookSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书源'),
        content: Text('确定要删除书源 "${source.bookSourceName}" 吗？'),
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
        await BookSourceService.instance.deleteBookSource(source.bookSourceUrl);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _refreshExploreKinds(int index) async {
    final source = _bookSources[index];
    await ExploreService.instance.clearExploreKindsCache(source);
    // 如果当前项是展开的，重新展开以刷新数据
    if (_expandedIndex == index) {
      setState(() {
        _expandedIndex = null;
      });
      // 延迟一下再展开，确保 FutureBuilder 重新构建
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _expandedIndex = index;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听滚动控制Provider
    ref.listen(exploreScrollControlProvider, (previous, next) {
      if (next > 0 && mounted) {
        _scrollToTop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedGroup == null ? '发现 - 全部分组' : '发现 - $_selectedGroup'),
        actions: [
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SearchPage(),
                ),
              );
            },
            tooltip: '搜索',
          ),
          // 分组菜单
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: _onGroupSelected,
            tooltip: '选择分组',
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    if (_selectedGroup == null) 
                      const Icon(Icons.check, size: 20),
                    if (_selectedGroup == null) 
                      const SizedBox(width: 8),
                    const Text('全部分组'),
                  ],
                ),
              ),
              if (_groups.isNotEmpty) const PopupMenuDivider(),
              ..._groups.map((group) => PopupMenuItem(
                    value: group,
                    child: Row(
                      children: [
                        if (_selectedGroup == group) 
                          const Icon(Icons.check, size: 20),
                        if (_selectedGroup == group) 
                          const SizedBox(width: 8),
                        Text(group),
                      ],
                    ),
                  )),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索书源',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookSources.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.explore_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchKeyword != null || _selectedGroup != null
                            ? '没有找到符合条件的书源'
                            : '暂无启用发现的书源',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _bookSources.length,
                  itemBuilder: (context, index) {
                    final source = _bookSources[index];
                    final isExpanded = _expandedIndex == index;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(source.bookSourceName),
                            subtitle: source.bookSourceGroup != null
                                ? Text(source.bookSourceGroup!)
                                : null,
                            trailing: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                            ),
                            onTap: () => _toggleExpand(index),
                            onLongPress: () =>
                                _showSourceMenu(context, source, index),
                          ),
                          if (isExpanded)
                            FutureBuilder<List<ExploreKind>>(
                              key: ValueKey(
                                  '${source.bookSourceUrl}_$_expandedIndex'),
                              future: ExploreService.instance
                                  .getExploreKinds(source),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      '加载失败: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  );
                                }

                                final kinds = snapshot.data ?? [];
                                if (kinds.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text('暂无发现分类'),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: kinds.map((kind) {
                                      final title = kind.title;
                                      final url = kind.url;

                                      if (title.startsWith('ERROR:')) {
                                        return Chip(
                                          label: Text(title),
                                          backgroundColor: Colors.red[100],
                                        );
                                      }

                                      return ActionChip(
                                        label: Text(title),
                                        onPressed: url == null || url.isEmpty
                                            ? null
                                            : () => _openExplore(
                                                  source,
                                                  title,
                                                  url,
                                                ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  void _showSourceMenu(BuildContext context, BookSource source, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                _editSource(source);
              },
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_top),
              title: const Text('置顶'),
              onTap: () {
                Navigator.pop(context);
                _topSource(source);
              },
            ),
            if (source.loginUrl != null && source.loginUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('登录'),
                onTap: () {
                  Navigator.pop(context);
                  _showLoginPage(source);
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('刷新分类'),
              onTap: () {
                Navigator.pop(context);
                _refreshExploreKinds(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(context);
                _deleteSource(source);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示登录页面
  void _showLoginPage(BookSource source) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SourceLoginPage(
          sourceUrl: source.bookSourceUrl,
        ),
      ),
    );
  }
}
