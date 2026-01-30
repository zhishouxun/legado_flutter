import 'dart:async';
import '../../data/models/book.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';
import 'async_search_service.dart';

/// 搜索模型
/// 参考项目：SearchModel.kt
/// 参考文档：gemini重构建议/异步搜索逻辑.md
///
/// 独立的搜索引擎，不受UI生命周期影响
///
/// **核心特性**:
/// 1. 基于AsyncSearchService的流式加载
/// 2. 实时去重和智能排序
/// 3. 支持暂停/恢复/取消
/// 4. 自动保存到数据库
/// 5. 流畅的用户体验(出一个显示一个)
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
  StreamSubscription<SearchResult>? _searchSubscription;

  // 异步搜索服务
  final AsyncSearchService _asyncSearchService = AsyncSearchService();

  // 搜索结果去重器
  final SearchResultDeduplicator _deduplicator = SearchResultDeduplicator();

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

  /// 开始搜索（使用AsyncSearchService）
  Future<void> _startSearch(
      List<BookSource> sources, bool precisionSearch) async {
    try {
      onSearchStart?.call();

      // 清空去重器
      _deduplicator.clear();

      // 使用AsyncSearchService创建搜索流
      final searchStream = _asyncSearchService.searchAllSources(
        _searchKey,
        sources,
        batchSize: 10, // 每批10个书源并发
        saveToDatabase: true, // 自动保存到数据库
        timeout: const Duration(seconds: 30), // 30秒超时
      );

      _searchSubscription = searchStream.listen(
        (searchResult) {
          // 检查是否已取消或暂停
          if (_isCancelled) {
            return;
          }

          // 等待暂停状态解除
          while (_isPaused && !_isCancelled) {
            // 注意: 在实际Stream中,暂停由StreamSubscription.pause()处理
            // 这里的_isPaused是额外的应用层控制
            Future.delayed(const Duration(milliseconds: 100));
          }

          if (_isCancelled) {
            return;
          }

          // 忽略错误结果
          if (searchResult.isError) {
            AppLog.instance.put('搜索结果错误: ${searchResult.errorMessage}');
            return;
          }

          // 处理成功结果
          if (searchResult.book != null) {
            // 去重
            if (_deduplicator.addBook(searchResult.book!)) {
              // 新书籍,合并到结果中
              _mergeItems([searchResult.book!], precisionSearch);

              // 实时回调更新
              onSearchSuccess?.call(List.from(_searchBooks));
            }
          }
        },
        onDone: () {
          AppLog.instance.put(
              '搜索完成: 共找到${_searchBooks.length}本书(去重后${_deduplicator.count}本)');
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

  /// 合并搜索结果
  /// 参考项目：mergeItems() - 智能排序和去重
  /// 注意: AsyncSearchService已经做了基本去重,这里主要是排序
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
      } else if (book.name.contains(_searchKey) ||
          book.author.contains(_searchKey)) {
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
    _searchSubscription?.pause();
  }

  /// 恢复搜索
  void resume() {
    _isPaused = false;
    _searchSubscription?.resume();
  }

  /// 取消搜索
  void cancelSearch() {
    _isCancelled = true;

    // 取消AsyncSearchService的搜索
    _asyncSearchService.cancelSearch();

    // 取消Stream订阅
    _searchSubscription?.cancel();
    _searchSubscription = null;

    _searchId = 0;
    _deduplicator.clear();

    onSearchCancel?.call(null);
  }

  /// 清理资源
  void dispose() {
    cancelSearch();
    _searchBooks.clear();
    _deduplicator.clear();
  }
}
