import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/app_config.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_source.dart';
import '../../../services/book/book_service.dart';
import '../../../services/book/search_model.dart';
import '../../../services/source/book_source_service.dart';
import '../../../services/search_history_service.dart';
import '../../../services/search_keyword_service.dart';
import '../../../utils/search_scope.dart';
import '../../../providers/book_provider.dart';
import '../../widgets/book/book_card.dart';
import '../bookshelf/book_info/book_info_page.dart';
import 'search_scope_dialog.dart';
import 'search_history_widget.dart';

/// 搜索页面
class SearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;

  const SearchPage({
    super.key,
    this.initialKeyword,
  });

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Book> _searchResults = [];
  List<Book> _filteredResults = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String? _error;

  // 搜索进度
  int _searchProgressCurrent = 0;
  int _searchProgressTotal = 0;

  // 搜索任务标识（用于在后台继续搜索）
  int _searchTaskId = 0;

  // 搜索模型（独立的搜索引擎）
  SearchModel? _searchModel;

  // 搜索范围
  SearchScope? _searchScope;

  // 筛选条件
  String _filterText = '';

  // 精确搜索模式
  bool _precisionSearch = false;

  // 搜索历史排序方式（0=时间，1=使用次数）
  int _historySortMode = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSearchModel();
    _precisionSearch = AppConfig.getPrecisionSearch();
    _historySortMode = AppConfig.getSearchHistorySortMode();
    _loadSearchScope();
    if (widget.initialKeyword != null) {
      _searchController.text = widget.initialKeyword!;
      _performSearch(widget.initialKeyword!);
    } else {
      _loadSearchHistory();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchModel?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 初始化搜索模型
  void _initSearchModel() {
    _searchModel = SearchModel(
      onSearchStart: () {
        // 搜索开始
        scheduleMicrotask(() {
          try {
            if (mounted) {
              setState(() {
                _isSearching = true;
                _isLoading = true;
              });
            }
          } catch (_) {}
        });
      },
      onSearchSuccess: (books) {
        // 实时更新结果（参考项目的做法）
        scheduleMicrotask(() {
          try {
            if (mounted) {
              setState(() {
                _searchResults = books;
                _applyFilter();
                _isLoading = false; // 有结果后不再显示loading
              });
            }
          } catch (_) {}
        });
      },
      onSearchFinish: (isEmpty) {
        // 搜索完成
        scheduleMicrotask(() {
          try {
            if (mounted) {
              setState(() {
                _isSearching = false;
                _isLoading = false;
              });
            }
          } catch (_) {}
        });
      },
      onSearchCancel: (error) {
        // 搜索取消或出错
        scheduleMicrotask(() {
          try {
            if (mounted) {
              setState(() {
                _isSearching = false;
                _isLoading = false;
                if (error != null) {
                  _error = error.toString();
                }
              });
            }
          } catch (_) {}
        });
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 监听应用生命周期状态变化
    // 不管窗口状态如何变化（inactive/paused/resumed），都不影响搜索任务
    // 搜索任务会在后台继续执行
  }

  Future<void> _loadSearchScope() async {
    _searchScope = await SearchScope.load();
  }

  Future<void> _loadSearchHistory() async {
    List<String> history;
    if (_historySortMode == 1) {
      // 按使用次数排序
      final keywords =
          await SearchKeywordService.instance.getKeywordsByUsage(limit: 20);
      history = keywords.map((k) => k.word).toList();
    } else {
      // 按时间排序（默认）
      history = await SearchHistoryService.instance.getSearchHistory();
    }

    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  Future<void> _performSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
          _error = null;
        });
      }
      return;
    }

    // 增加搜索任务ID
    final searchId = ++_searchTaskId;

    // 保存搜索历史
    await SearchHistoryService.instance.saveSearchKeyword(keyword);
    if (mounted) {
      await _loadSearchHistory();
    }

    try {
      // 获取要搜索的书源
      List<BookSource>? sources;
      if (_searchScope != null) {
        sources = await _searchScope!.getBookSources();
        if (sources.isEmpty) {
          sources = null;
        }
      }

      sources ??= await BookSourceService.instance.getEnabledBookSources();

      // 使用SearchModel进行后台搜索（完全独立于UI生命周期）
      await _searchModel?.search(
        searchId: searchId,
        keyword: keyword,
        sources: sources,
        precisionSearch: _precisionSearch,
      );
    } catch (e) {
      try {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
            _isSearching = false;
          });
        }
      } catch (_) {}
    }
  }

  /// 手动停止搜索
  void _stopSearch() {
    _searchTaskId++; // 增加任务ID，使当前搜索任务失效
    _searchModel?.cancelSearch();

    if (mounted) {
      setState(() {
        _isSearching = false;
        _isLoading = false;
      });
    }
  }

  void _showSearchScopeDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SearchScopeDialog(
        onScopeSelected: (sources, groups) {
          Navigator.of(context).pop({
            'sources': sources,
            'groups': groups,
          });
        },
      ),
    );

    if (result != null && mounted) {
      final sources = result['sources'] as List<BookSource>?;
      final groups = result['groups'] as List<String>?;

      // 更新SearchScope
      if (sources != null && sources.isNotEmpty) {
        if (sources.length == 1) {
          _searchScope = SearchScope.fromSource(sources.first);
        } else {
          // 多个书源，使用第一个作为代表（或创建新的范围管理）
          _searchScope = SearchScope.fromSource(sources.first);
        }
      } else if (groups != null && groups.isNotEmpty) {
        _searchScope = SearchScope.fromGroups(groups);
      } else {
        _searchScope = SearchScope(); // 全部书源
      }

      _searchScope?.update(_searchScope!.toString());

      setState(() {});

      // 如果有搜索关键词，重新搜索
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      }
    }
  }

  void _showBookInfo(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookInfoPage(
          key: ValueKey('book_info_${book.bookUrl}'),
          bookUrl: book.bookUrl,
          bookName: book.name,
          author: book.author,
          sourceUrl: book.origin,
          coverUrl: book.displayCover,
          intro: book.displayIntro,
        ),
      ),
    );
  }

  /// 显示书籍快速操作菜单
  void _showBookQuickActions(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(context);
                _showBookInfo(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('加入书架'),
              onTap: () async {
                Navigator.pop(context);
                await _addBookToShelf(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                _shareBook(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 添加书籍到书架
  Future<void> _addBookToShelf(Book book) async {
    try {
      // 如果书籍不是本地书籍，需要先获取章节列表
      if (!book.isLocal) {
        try {
          final chapters = await BookService.instance.getChapterList(book);
          if (chapters.isNotEmpty) {
            await BookService.instance.saveChapters(chapters);
          }
        } catch (e) {
          // 章节列表获取失败不影响添加书籍
        }
      }

      // 保存书籍
      await BookService.instance.createBook(book);

      // 刷新书架 Provider
      ref.invalidate(refreshBookshelfProvider);
      ref.invalidate(bookshelfBooksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到书架')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  /// 分享书籍
  void _shareBook(Book book) {
    final shareText =
        '《${book.name}》\n作者：${book.author}\n来源：${book.originName}\n链接：${book.bookUrl}';
    Share.share(shareText);
  }

  void _applyFilter() {
    if (_filterText.isEmpty) {
      _filteredResults = _searchResults;
    } else {
      final query = _filterText.toLowerCase();
      _filteredResults = _searchResults.where((book) {
        return book.name.toLowerCase().contains(query) ||
            book.author.toLowerCase().contains(query) ||
            book.originName.toLowerCase().contains(query);
      }).toList();
    }

    // 如果启用精确搜索模式，进一步过滤结果
    if (_precisionSearch && _searchController.text.trim().isNotEmpty) {
      final keyword = _searchController.text.trim().toLowerCase();
      _filteredResults = _filteredResults.where((book) {
        return book.name.toLowerCase() == keyword ||
            book.author.toLowerCase() == keyword ||
            (book.name.toLowerCase().contains(keyword) &&
                book.author.toLowerCase().contains(keyword));
      }).toList();
    }
  }

  void _showFilterDialog() {
    final controller = TextEditingController(text: _filterText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选搜索结果'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入书名、作者或来源',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clear();
            },
            child: const Text('清空'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _filterText = controller.text.trim();
                _applyFilter();
              });
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  String _getScopeText() {
    if (_searchScope != null) {
      return _searchScope!.display;
    }
    return '全部书源';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: widget.initialKeyword == null,
          decoration: InputDecoration(
            hintText: '搜索书籍',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _isSearching = false;
                        _searchResults = [];
                      });
                      _loadSearchHistory();
                    },
                  )
                : null,
          ),
          onSubmitted: (value) {
            _performSearch(value);
          },
          onChanged: (value) {
            setState(() {});
            // 只更新UI，不触发搜索
          },
        ),
        actions: [
          // 停止搜索按钮（搜索中时显示）
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopSearch,
              tooltip: '停止搜索',
            ),
          // 搜索范围按钮
          TextButton.icon(
            onPressed: _showSearchScopeDialog,
            icon: const Icon(Icons.filter_list, size: 20),
            label: Text(
              _getScopeText(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          // 筛选按钮（仅在搜索结果页面显示）
          if (_isSearching && _searchResults.isNotEmpty)
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.tune),
                  if (_filterText.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _showFilterDialog,
              tooltip: '筛选搜索结果',
            ),
          // 更多选项菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'precision_search',
                child: Row(
                  children: [
                    Icon(
                      _precisionSearch
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('精确搜索'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'history_sort_time',
                child: Row(
                  children: [
                    Icon(
                      _historySortMode == 0
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('按时间排序'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history_sort_usage',
                child: Row(
                  children: [
                    Icon(
                      _historySortMode == 1
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('按使用次数排序'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'precision_search') {
                setState(() {
                  _precisionSearch = !_precisionSearch;
                });
                AppConfig.setPrecisionSearch(_precisionSearch);
                // 如果有搜索结果，重新应用过滤
                if (_searchResults.isNotEmpty) {
                  _applyFilter();
                }
              } else if (value == 'history_sort_time') {
                setState(() {
                  _historySortMode = 0;
                });
                AppConfig.setSearchHistorySortMode(0);
                _loadSearchHistory();
              } else if (value == 'history_sort_usage') {
                setState(() {
                  _historySortMode = 1;
                });
                AppConfig.setSearchHistorySortMode(1);
                _loadSearchHistory();
              }
            },
          ),
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _searchFocusNode.unfocus();
              _performSearch(_searchController.text.trim());
            },
          ),
        ],
      ),
      body: _isSearching || _searchResults.isNotEmpty
          ? _buildSearchResults()
          : _buildSearchHistory(),
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '搜索历史为空',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SearchHistoryWidget(
      history: _searchHistory,
      onHistoryTap: (keyword) {
        _searchController.text = keyword;
        _performSearch(keyword);
      },
      onHistoryDelete: (keyword) async {
        await SearchHistoryService.instance.deleteSearchHistory(keyword);
        await _loadSearchHistory();
      },
      onClearHistory: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清空历史'),
            content: const Text('确定要清空所有搜索历史吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('清空'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await SearchHistoryService.instance.clearSearchHistory();
          await _loadSearchHistory();
        }
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (_searchProgressTotal > 0) ...[
              const SizedBox(height: 16),
              Text(
                '正在搜索: $_searchProgressCurrent / $_searchProgressTotal',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              '搜索失败',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _performSearch(_searchController.text.trim()),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关书籍',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '关键词: ${_searchController.text}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 搜索结果统计信息
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                '找到 ${_filteredResults.length} 个结果',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              if (_filteredResults.length != _searchResults.length) ...[
                const SizedBox(width: 8),
                Text(
                  '（已筛选 ${_searchResults.length} 个）',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
        // 筛选提示
        if (_filterText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '筛选: $_filterText (${_filteredResults.length}/${_searchResults.length})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterText = '';
                      _applyFilter();
                    });
                  },
                  child: const Text('清除'),
                ),
              ],
            ),
          ),
        // 搜索结果列表
        Expanded(
          child: _filteredResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_alt_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '筛选后无结果',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (_filterText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _filterText = '';
                              _applyFilter();
                            });
                          },
                          child: const Text('清除筛选'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredResults.length,
                  itemBuilder: (context, index) {
                    final book = _filteredResults[index];
                    return BookCard(
                      book: book,
                      isSearchResult: true,
                      highlightKeyword: _searchController.text.trim().isNotEmpty
                          ? _searchController.text.trim()
                          : null,
                      onTap: () => _showBookInfo(book),
                      onLongPress: () => _showBookQuickActions(context, book),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
