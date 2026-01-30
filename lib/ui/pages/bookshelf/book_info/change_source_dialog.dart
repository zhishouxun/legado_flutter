import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/book.dart';
import '../../../../data/models/book_chapter.dart';
import '../../../../data/models/book_source.dart';
import '../../../../services/book/book_service.dart';
import '../../../../services/source/book_source_service.dart';
import 'change_source_list_item.dart';
import '../../../widgets/base/base_bottom_sheet_consumer.dart';

/// 换源对话框
class ChangeSourceDialog extends BaseBottomSheetConsumer {
  final Book oldBook;
  final Function(BookSource source, Book book, List<BookChapter> chapters)
      onSourceChanged;

  const ChangeSourceDialog({
    super.key,
    required this.oldBook,
    required this.onSourceChanged,
  }) : super(
          title: '换源',
          heightFactor: 0.8,
        );

  @override
  ConsumerState<ChangeSourceDialog> createState() => _ChangeSourceDialogState();
}

class _ChangeSourceDialogState
    extends BaseBottomSheetConsumerState<ChangeSourceDialog> {
  List<Book> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String _searchKeyword = '';
  String? _selectedGroup;
  List<String> _groups = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _startSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await BookSourceService.instance.getAllGroups();
    setState(() {
      _groups = groups;
    });
  }

  Future<void> _startSearch() async {
    if (widget.oldBook.name.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      // 获取要搜索的书源列表
      List<BookSource> sources;
      if (_selectedGroup != null && _selectedGroup!.isNotEmpty) {
        sources = await BookSourceService.instance
            .getBookSourcesByGroup(_selectedGroup!);
      } else {
        sources = await BookSourceService.instance.getEnabledBookSources();
      }

      // 限制搜索书源数量，避免搜索过慢
      // 参考项目使用并行搜索和流式返回，这里简化处理：限制数量并打乱顺序
      const maxSourcesToSearch = 100;
      
      // 打乱书源顺序，避免总是搜索前N个
      sources.shuffle();
      
      final sourcesToSearch = sources.length > maxSourcesToSearch
          ? sources.sublist(0, maxSourcesToSearch)
          : sources;
      
      if (sources.length > maxSourcesToSearch && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('书源过多，随机搜索$maxSourcesToSearch个书源'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 创建临时结果列表（用于实时显示）
      final tempResults = <Book>[];
      
      // 搜索同名书籍（带超时，支持实时结果）
      final results = await BookService.instance.searchBooks(
        widget.oldBook.name,
        sources: sourcesToSearch,
        onResult: (book) {
          // 找到结果立即显示
          tempResults.add(book);
          try {
            if (mounted) {
              setState(() {
                _searchResults = List.from(tempResults);
              });
            }
          } catch (_) {}
        },
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('搜索超时，显示已找到的结果')),
            );
          }
          return [];
        },
      );

      // 过滤：只保留书名相同且作者匹配的书籍
      final filteredResults = results.where((book) {
        if (book.name != widget.oldBook.name) return false;
        if (widget.oldBook.author.isNotEmpty) {
          return book.author.contains(widget.oldBook.author) ||
              widget.oldBook.author.contains(book.author);
        }
        return true;
      }).toList();

      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  Future<void> _changeSource(Book newBook) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取书源
      final source =
          await BookSourceService.instance.getBookSourceByUrl(newBook.origin);
      if (source == null) {
        throw Exception('书源不存在');
      }

      // 获取书籍详情
      final bookInfo = await BookService.instance.getBookInfo(newBook);
      if (bookInfo == null) {
        throw Exception('获取书籍信息失败');
      }

      // 获取章节列表
      final chapters = await BookService.instance.getChapterList(bookInfo);
      if (chapters.isEmpty) {
        throw Exception('获取章节列表失败');
      }

      // 调用回调
      widget.onSourceChanged(source, bookInfo, chapters);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('换源失败: $e')),
        );
      }
    }
  }

  void _filterResults(String keyword) {
    setState(() {
      _searchKeyword = keyword.toLowerCase();
    });
  }

  List<Book> get _filteredResults {
    if (_searchKeyword.isEmpty) {
      return _searchResults;
    }
    return _searchResults.where((book) {
      return book.originName.toLowerCase().contains(_searchKeyword) ||
          (book.kind?.toLowerCase().contains(_searchKeyword) ?? false);
    }).toList();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 书籍信息
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.oldBook.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.oldBook.author.isNotEmpty)
                Text(
                  widget.oldBook.author,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        // 搜索框和操作按钮
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索书源名称',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterResults('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: _filterResults,
                ),
              ),
              const SizedBox(width: 8),
              // 分组选择
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                onSelected: (group) {
                  setState(() {
                    _selectedGroup = group == '全部' ? null : group;
                  });
                  _startSearch();
                },
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem(
                      value: '全部',
                      child: Text('全部'),
                    ),
                    ..._groups.map((group) => PopupMenuItem(
                          value: group,
                          child: Text(group),
                        )),
                  ];
                },
              ),
              IconButton(
                icon: Icon(_isSearching ? Icons.stop : Icons.refresh),
                onPressed: _isSearching ? null : _startSearch,
                tooltip: _isSearching ? '停止搜索' : '刷新',
              ),
            ],
          ),
        ),
        // 搜索结果列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isSearching
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('正在搜索...'),
                        ],
                      ),
                    )
                  : _filteredResults.isEmpty
                      ? Center(
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
                                '未找到可用书源',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredResults.length,
                          itemBuilder: (context, index) {
                            final book = _filteredResults[index];
                            final isCurrentSource =
                                book.origin == widget.oldBook.origin;
                            return ChangeSourceListItem(
                              book: book,
                              isCurrentSource: isCurrentSource,
                              onTap: () => _changeSource(book),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
