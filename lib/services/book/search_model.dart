import 'dart:async';
import '../../data/models/book.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';
import 'book_service.dart';

/// 搜索模型
/// 参考项目：SearchModel.kt
/// 独立的搜索引擎，不受UI生命周期影响
class SearchModel {
  final Function()? onSearchStart;
  final Function(List<Book> books)? onSearchSuccess;
  final Function(bool isEmpty)? onSearchFinish;
  final Function(dynamic error)? onSearchCancel;

  // 当前搜索ID
  int _searchId = 0;
  
  // 当前搜索关键词
  String _searchKey = '';
  
  // 搜索结果
  final List<Book> _searchBooks = [];
  
  // 是否暂停
  bool _isPaused = false;
  
  // 是否已取消
  bool _isCancelled = false;
  
  // 搜索任务
  StreamSubscription? _searchSubscription;

  SearchModel({
    this.onSearchStart,
    this.onSearchSuccess,
    this.onSearchFinish,
    this.onSearchCancel,
  });

  /// 开始搜索
  /// 参考项目：search(searchId, key)
  Future<void> search({
    required int searchId,
    required String keyword,
    required List<BookSource> sources,
    bool precisionSearch = false,
  }) async {
    if (searchId != _searchId) {
      if (keyword.isEmpty) return;
      
      _searchKey = keyword;
      
      if (_searchId != 0) {
        cancelSearch();
      }
      
      _searchBooks.clear();
      _searchId = searchId;
      _isPaused = false;
      _isCancelled = false;
    }

    if (_searchKey.isEmpty) return;

    await _startSearch(sources, precisionSearch);
  }

  /// 开始搜索（参考项目的实现）
  Future<void> _startSearch(List<BookSource> sources, bool precisionSearch) async {
    try {
      onSearchStart?.call();

      // 创建搜索流（参考项目使用flow + mapParallelSafe）
      final searchStream = _createSearchStream(sources, precisionSearch);
      
      _searchSubscription = searchStream.listen(
        (books) {
          // 合并新结果
          _mergeItems(books, precisionSearch);
          
          // 回调更新
          onSearchSuccess?.call(List.from(_searchBooks));
        },
        onDone: () {
          onSearchFinish?.call(_searchBooks.isEmpty);
        },
        onError: (error) {
          AppLog.instance.put('搜索出错: $error', error: error);
          onSearchCancel?.call(error);
        },
        cancelOnError: false,
      );
    } catch (e) {
      AppLog.instance.put('搜索启动失败: $e', error: e);
      onSearchCancel?.call(e);
    }
  }

  /// 创建搜索流
  /// 参考项目：flow { emit() }.mapParallelSafe().onEach()
  Stream<List<Book>> _createSearchStream(List<BookSource> sources, bool precisionSearch) async* {
    final validSources = sources.where((source) {
      return source.enabled &&
          source.searchUrl != null &&
          source.ruleSearch != null;
    }).toList();

    // 并行搜索（参考项目使用线程池并发）
    // 这里简化实现：批量并发搜索
    const batchSize = 10; // 每批10个书源
    
    for (var i = 0; i < validSources.length; i += batchSize) {
      // 检查是否已取消
      if (_isCancelled) break;
      
      // 等待暂停状态解除
      while (_isPaused && !_isCancelled) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (_isCancelled) break;

      final batch = validSources.skip(i).take(batchSize).toList();
      
      // 并发搜索当前批次
      final futures = batch.map((source) async {
        try {
          // 超时30秒
          return await BookService.instance
              .searchBooksFromSource(source, _searchKey, precisionSearch)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => <Book>[],
              );
        } catch (e) {
          AppLog.instance.put('书源搜索失败: ${source.bookSourceName}', error: e);
          return <Book>[];
        }
      });

      // 等待当前批次完成
      final results = await Future.wait(futures);
      
      // 合并并返回结果
      final batchBooks = <Book>[];
      for (final books in results) {
        batchBooks.addAll(books);
      }
      
      if (batchBooks.isNotEmpty) {
        yield batchBooks;
      }
    }
  }

  /// 合并搜索结果
  /// 参考项目：mergeItems() - 智能排序和去重
  void _mergeItems(List<Book> newBooks, bool precisionSearch) {
    if (newBooks.isEmpty) return;

    // 参考项目的排序逻辑：
    // 1. 完全匹配（名称或作者）
    // 2. 包含关键词
    // 3. 其他（非精确模式）
    
    final copyData = List<Book>.from(_searchBooks);
    final equalData = <Book>[];
    final containsData = <Book>[];
    final otherData = <Book>[];

    // 分类现有数据
    for (final book in copyData) {
      if (book.name == _searchKey || book.author == _searchKey) {
        equalData.add(book);
      } else if (book.name.contains(_searchKey) || book.author.contains(_searchKey)) {
        containsData.add(book);
      } else {
        otherData.add(book);
      }
    }

    // 合并新数据
    for (final newBook in newBooks) {
      if (newBook.name == _searchKey || newBook.author == _searchKey) {
        // 检查是否已存在
        final hasSame = equalData.any((book) =>
            book.name == newBook.name && book.author == newBook.author);
        if (!hasSame) {
          equalData.add(newBook);
        }
      } else if (newBook.name.contains(_searchKey) ||
          newBook.author.contains(_searchKey)) {
        final hasSame = containsData.any((book) =>
            book.name == newBook.name && book.author == newBook.author);
        if (!hasSame) {
          containsData.add(newBook);
        }
      } else if (!precisionSearch) {
        final hasSame = otherData.any((book) =>
            book.name == newBook.name && book.author == newBook.author);
        if (!hasSame) {
          otherData.add(newBook);
        }
      }
    }

    // 重新组合：完全匹配 + 包含关键词 + 其他
    _searchBooks.clear();
    _searchBooks.addAll(equalData);
    _searchBooks.addAll(containsData);
    if (!precisionSearch) {
      _searchBooks.addAll(otherData);
    }
  }

  /// 暂停搜索
  void pause() {
    _isPaused = true;
  }

  /// 恢复搜索
  void resume() {
    _isPaused = false;
  }

  /// 取消搜索
  void cancelSearch() {
    _isCancelled = true;
    _searchSubscription?.cancel();
    _searchSubscription = null;
    _searchId = 0;
    onSearchCancel?.call(null);
  }

  /// 清理资源
  void dispose() {
    cancelSearch();
  }
}

