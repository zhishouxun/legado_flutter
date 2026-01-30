import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../services/book/book_service.dart';
import '../../../services/reader/cache_service.dart';
import 'cache_book_item.dart';
import 'cache_statistics_widget.dart';

/// 缓存管理页面
class CacheManagePage extends ConsumerStatefulWidget {
  const CacheManagePage({super.key});

  @override
  ConsumerState<CacheManagePage> createState() => _CacheManagePageState();
}

class _CacheManagePageState extends ConsumerState<CacheManagePage> {
  List<Book> _books = [];
  Map<String, CacheInfo> _cacheInfoMap = {};
  bool _isLoading = true;
  int? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取书籍列表
      final books = _selectedGroupId != null
          ? await BookService.instance.getBooksByGroup(_selectedGroupId!)
          : await BookService.instance.getBookshelfBooks();
      
      // 过滤掉本地书籍和音频书籍
      final filteredBooks = books.where((book) => !book.isLocal).toList();

      // 加载缓存信息
      final cacheInfoMap = <String, CacheInfo>{};
      for (final book in filteredBooks) {
        final chapters = await BookService.instance.getChapterList(book);
        final cachedFiles = await CacheService.instance.getCachedChapterFiles(book);
        final cachedCount = await CacheService.instance.getCachedChapterCount(book, chapters);
        
        cacheInfoMap[book.bookUrl] = CacheInfo(
          totalChapters: chapters.length,
          cachedChapters: cachedCount,
          cachedFiles: cachedFiles,
        );
      }

      setState(() {
        _books = filteredBooks;
        _cacheInfoMap = cacheInfoMap;
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

  Future<void> _refresh() async {
    await _loadBooks();
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有缓存吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await CacheService.instance.clearAllCache();
      await _loadBooks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除所有缓存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除缓存失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算总缓存大小
    int totalChapters = 0;
    int cachedChapters = 0;
    for (final info in _cacheInfoMap.values) {
      totalChapters += info.totalChapters;
      cachedChapters += info.cachedChapters;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_all') {
                _clearAllCache();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 8),
                    Text('清除所有缓存'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无书籍',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: Column(
                    children: [
                      // 缓存统计
                      CacheStatisticsWidget(
                        totalBooks: _books.length,
                        totalChapters: totalChapters,
                        cachedChapters: cachedChapters,
                      ),
                      const Divider(height: 1),
                      // 书籍列表
                      Expanded(
                        child: ListView.builder(
                          itemCount: _books.length,
                          itemBuilder: (context, index) {
                            final book = _books[index];
                            final cacheInfo = _cacheInfoMap[book.bookUrl];
                            return CacheBookItem(
                              book: book,
                              cacheInfo: cacheInfo,
                              onCacheCleared: () => _refresh(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// 缓存信息
class CacheInfo {
  final int totalChapters;
  final int cachedChapters;
  final Set<String> cachedFiles;

  CacheInfo({
    required this.totalChapters,
    required this.cachedChapters,
    required this.cachedFiles,
  });

  double get progress {
    if (totalChapters == 0) return 0.0;
    return cachedChapters / totalChapters;
  }
}

