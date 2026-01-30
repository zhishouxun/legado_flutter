/// 异步搜索服务使用示例
///
/// 演示如何集成AsyncSearchService到现有的搜索页面中
library;

import 'package:flutter/material.dart';
import 'package:legado_flutter/services/book/async_search_service.dart';
import 'package:legado_flutter/services/book/search_model.dart';
import 'package:legado_flutter/services/source/book_source_service.dart';
import 'package:legado_flutter/data/models/book.dart';
import 'package:legado_flutter/data/models/book_source.dart';

/// 示例1: 使用SearchModel(推荐方式)
class AsyncSearchExampleWithModel extends StatefulWidget {
  const AsyncSearchExampleWithModel({super.key});

  @override
  State<AsyncSearchExampleWithModel> createState() =>
      _AsyncSearchExampleWithModelState();
}

class _AsyncSearchExampleWithModelState
    extends State<AsyncSearchExampleWithModel> {
  final TextEditingController _searchController = TextEditingController();
  SearchModel? _searchModel;
  List<Book> _searchResults = [];
  bool _isSearching = false;
  int _searchTaskId = 0;

  @override
  void initState() {
    super.initState();
    _initSearchModel();
  }

  /// 初始化搜索模型
  void _initSearchModel() {
    _searchModel = SearchModel(
      onSearchStart: () {
        if (mounted) {
          setState(() {
            _isSearching = true;
            _searchResults.clear();
          });
        }
      },
      onSearchSuccess: (books) {
        // 实时更新结果(每找到一本书就更新UI)
        if (mounted) {
          setState(() {
            _searchResults = books;
          });
        }
      },
      onSearchFinish: (isEmpty) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
        if (isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到相关书籍')),
          );
        }
      },
      onSearchCancel: (error) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('搜索出错: $error')),
          );
        }
      },
    );
  }

  /// 执行搜索
  Future<void> _performSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      return;
    }

    // 获取启用的书源
    final sources = await BookSourceService.instance.getAllBookSources(
      enabledOnly: true,
    );

    if (sources.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可用的书源')),
        );
      }
      return;
    }

    // 增加搜索任务ID(用于区分不同的搜索)
    final searchId = ++_searchTaskId;

    // 开始搜索
    await _searchModel?.search(
      searchId: searchId,
      keyword: keyword,
      sources: sources,
      precisionSearch: false, // 精确搜索模式
    );
  }

  /// 取消搜索
  void _cancelSearch() {
    _searchModel?.cancelSearch();
  }

  @override
  void dispose() {
    _searchModel?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('异步搜索示例(使用SearchModel)'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelSearch,
              tooltip: '取消搜索',
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入书名或作者',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _performSearch,
            ),
          ),
          // 搜索结果列表
          Expanded(
            child: _searchResults.isEmpty && !_isSearching
                ? const Center(child: Text('请输入关键词开始搜索'))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final book = _searchResults[index];
                      return ListTile(
                        leading: book.coverUrl != null
                            ? Image.network(
                                book.coverUrl!,
                                width: 40,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.book, size: 40);
                                },
                              )
                            : const Icon(Icons.book, size: 40),
                        title: Text(book.name),
                        subtitle: Text('${book.author}\n${book.originName}'),
                        isThreeLine: true,
                        onTap: () {
                          // 跳转到书籍详情页
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 示例2: 直接使用AsyncSearchService(高级用法)
class AsyncSearchExampleDirect extends StatefulWidget {
  const AsyncSearchExampleDirect({super.key});

  @override
  State<AsyncSearchExampleDirect> createState() =>
      _AsyncSearchExampleDirectState();
}

class _AsyncSearchExampleDirectState extends State<AsyncSearchExampleDirect> {
  final AsyncSearchService _searchService = AsyncSearchService();
  final SearchResultDeduplicator _deduplicator = SearchResultDeduplicator();
  final TextEditingController _searchController = TextEditingController();

  List<Book> _books = [];
  bool _isSearching = false;
  int _searchedCount = 0;
  int _totalCount = 0;

  /// 开始搜索
  Future<void> _startSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      return;
    }

    // 获取启用的书源
    final sources = await BookSourceService.instance.getAllBookSources(
      enabledOnly: true,
    );

    if (sources.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可用的书源')),
        );
      }
      return;
    }

    // 重置状态
    setState(() {
      _books.clear();
      _isSearching = true;
      _searchedCount = 0;
      _totalCount = sources.length;
    });
    _deduplicator.clear();

    // 订阅搜索流
    _searchService
        .searchAllSources(
      keyword,
      sources,
      batchSize: 10, // 每批10个书源并发
      saveToDatabase: true, // 自动保存到数据库
      timeout: const Duration(seconds: 30),
    )
        .listen(
      (result) {
        // 更新已搜索数量
        setState(() {
          _searchedCount++;
        });

        // 忽略错误结果
        if (result.isError) {
          debugPrint('书源${result.sourceName}出错: ${result.errorMessage}');
          return;
        }

        // 去重并添加
        if (result.book != null && _deduplicator.addBook(result.book!)) {
          setState(() {
            _books.add(result.book!);
          });
        }
      },
      onDone: () {
        setState(() {
          _isSearching = false;
        });

        debugPrint('搜索完成,共找到${_deduplicator.count}本书(去重后)');

        if (_books.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到相关书籍')),
          );
        }
      },
      onError: (error) {
        setState(() {
          _isSearching = false;
        });

        debugPrint('搜索出错: $error');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('搜索出错: $error')),
          );
        }
      },
    );
  }

  /// 取消搜索
  void _cancelSearch() {
    _searchService.cancelSearch();
    setState(() {
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('异步搜索示例(直接使用Service)'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelSearch,
              tooltip: '取消搜索',
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '输入书名或作者',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: _startSearch,
            ),
          ),
          // 搜索进度
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _totalCount > 0 ? _searchedCount / _totalCount : 0,
                  ),
                  const SizedBox(height: 8),
                  Text('正在搜索: $_searchedCount / $_totalCount'),
                ],
              ),
            ),
          // 搜索结果
          Expanded(
            child: _books.isEmpty && !_isSearching
                ? const Center(child: Text('请输入关键词开始搜索'))
                : ListView.builder(
                    itemCount: _books.length,
                    itemBuilder: (context, index) {
                      final book = _books[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: book.coverUrl != null
                              ? Image.network(
                                  book.coverUrl!,
                                  width: 40,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.book, size: 40);
                                  },
                                )
                              : const Icon(Icons.book, size: 40),
                          title: Text(book.name),
                          subtitle: Text(
                            '作者: ${book.author}\n'
                            '来源: ${book.originName}',
                          ),
                          isThreeLine: true,
                          trailing: book.latestChapterTitle != null
                              ? Text(
                                  '最新: ${book.latestChapterTitle}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            // 跳转到书籍详情页
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
