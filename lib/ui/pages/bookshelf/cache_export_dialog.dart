import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_group.dart';
import '../../../providers/book_provider.dart';
import '../../../services/reader/cache_service.dart';
import '../../../services/reader/cache_export_service.dart';
import '../../../services/book/book_service.dart';
import '../../../services/source/book_source_service.dart';
import '../../widgets/base/base_bottom_sheet_consumer.dart';

/// 缓存/导出对话框
class CacheExportDialog extends BaseBottomSheetConsumer {
  final int groupId;

  const CacheExportDialog({
    super.key,
    required this.groupId,
  }) : super(
          title: '缓存/导出',
          heightFactor: 0.8,
        );

  @override
  ConsumerState<CacheExportDialog> createState() => _CacheExportDialogState();
}

class _CacheExportDialogState
    extends BaseBottomSheetConsumerState<CacheExportDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedBookUrls = <String>{};
  bool _isSelectMode = false;
  final Map<String, int> _cachedCounts = {}; // 书籍URL -> 已缓存章节数
  final Map<String, int> _totalCounts = {}; // 书籍URL -> 总章节数

  @override
  void initState() {
    super.initState();
    _loadCacheStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载缓存状态
  Future<void> _loadCacheStatus() async {
    final booksAsync = ref.read(booksByGroupProvider(widget.groupId));
    final books = booksAsync.value ?? [];

    for (final book in books) {
      if (book.isLocal) continue;

      try {
        final chapters = await BookService.instance.getChapterList(book);
        final cachedCount =
            await CacheService.instance.getCachedChapterCount(book, chapters);

        setState(() {
          _totalCounts[book.bookUrl] = chapters.length;
          _cachedCounts[book.bookUrl] = cachedCount;
        });
      } catch (e) {
        // 忽略错误
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    final booksAsync = ref.watch(booksByGroupProvider(widget.groupId));
    final groupsAsync = ref.watch(bookGroupsProvider);

    return Column(
      children: [
        // 搜索框和操作按钮
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: groupsAsync.when(
                      data: (groups) {
                        final group = groups.firstWhere(
                          (g) => g.groupId == widget.groupId,
                          orElse: () => BookGroup(
                              groupId: widget.groupId, groupName: '未知分组'),
                        );
                        return '筛选 • ${group.groupName}';
                      },
                      loading: () => '筛选',
                      error: (_, __) => '筛选',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _isSelectMode ? Icons.close : Icons.checklist,
                ),
                onPressed: () {
                  setState(() {
                    _isSelectMode = !_isSelectMode;
                    if (!_isSelectMode) {
                      _selectedBookUrls.clear();
                    }
                  });
                },
                tooltip: _isSelectMode ? '取消选择' : '批量选择',
              ),
            ],
          ),
        ),
        // 批量操作栏
        if (_isSelectMode && _selectedBookUrls.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '已选择 ${_selectedBookUrls.length} 项',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _showCacheBooksDialog(),
                  tooltip: '缓存',
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  onPressed: () => _showExportBooksDialog(),
                  tooltip: '导出',
                ),
              ],
            ),
          ),
        // 书籍列表
        Expanded(
          child: booksAsync.when(
            data: (books) {
              // 应用搜索筛选
              final filteredBooks = _searchController.text.isEmpty
                  ? books
                  : books.where((book) {
                      final keyword = _searchController.text.toLowerCase();
                      return book.name.toLowerCase().contains(keyword) ||
                          book.author.toLowerCase().contains(keyword);
                    }).toList();

              if (filteredBooks.isEmpty) {
                return Center(
                  child: Text(
                    _searchController.text.isEmpty ? '暂无书籍' : '没有找到相关书籍',
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = filteredBooks[index];
                  final isSelected = _selectedBookUrls.contains(book.bookUrl);
                  final cachedChapters = _cachedCounts[book.bookUrl] ?? 0;
                  final totalChapters =
                      _totalCounts[book.bookUrl] ?? book.totalChapterNum;

                  return ListTile(
                    leading: _isSelectMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedBookUrls.add(book.bookUrl);
                                } else {
                                  _selectedBookUrls.remove(book.bookUrl);
                                }
                              });
                            },
                          )
                        : null,
                    title: Text(book.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.author),
                        if (totalChapters > 0)
                          Text(
                            '缓存: $cachedChapters / $totalChapters',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    trailing: _isSelectMode
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (value) {
                              _handleBookAction(value, book);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'cache',
                                child: Row(
                                  children: [
                                    Icon(Icons.download, size: 20),
                                    SizedBox(width: 8),
                                    Text('缓存'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.upload_file, size: 20),
                                    SizedBox(width: 8),
                                    Text('导出'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                    onTap: _isSelectMode
                        ? () {
                            setState(() {
                              if (isSelected) {
                                _selectedBookUrls.remove(book.bookUrl);
                              } else {
                                _selectedBookUrls.add(book.bookUrl);
                              }
                            });
                          }
                        : null,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(booksByGroupProvider(widget.groupId));
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 处理书籍操作
  void _handleBookAction(String value, Book book) {
    switch (value) {
      case 'cache':
        _showCacheBookDialog(book);
        break;
      case 'export':
        _showExportBookDialog(book);
        break;
    }
  }

  /// 显示缓存书籍对话框（单个）
  void _showCacheBookDialog(Book book) async {
    if (book.isLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地书籍不需要缓存')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缓存书籍'),
        content: Text('确定要缓存"${book.name}"的所有章节吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cacheBook(book);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 缓存书籍
  Future<void> _cacheBook(Book book) async {
    // 显示进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在缓存章节...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final source =
          await BookSourceService.instance.getBookSourceByUrl(book.origin);
      if (source == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到书源')),
          );
        }
        return;
      }

      final chapters = await BookService.instance.getChapterList(book);
      if (chapters.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有章节可缓存')),
          );
        }
        return;
      }

      int successCount = 0;
      await CacheService.instance.cacheChapters(
        book,
        chapters,
        source,
        onProgress: (current, total) {
          // 可以在这里更新进度
        },
      ).then((results) {
        successCount = results.values.where((v) => v == true).length;
      });

      if (!mounted) return;
      Navigator.pop(context);

      // 刷新缓存状态
      await _loadCacheStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('缓存完成：成功 $successCount / ${chapters.length} 章')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('缓存失败: $e')),
        );
      }
    }
  }

  /// 显示缓存书籍对话框（批量）
  void _showCacheBooksDialog() async {
    if (_selectedBookUrls.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缓存书籍'),
        content: Text('确定要缓存选中的 ${_selectedBookUrls.length} 本书籍吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cacheBooks();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 批量缓存书籍
  Future<void> _cacheBooks() async {
    final booksAsync = ref.read(booksByGroupProvider(widget.groupId));
    final allBooks = booksAsync.value ?? [];
    final books =
        allBooks.where((b) => _selectedBookUrls.contains(b.bookUrl)).toList();

    if (books.isEmpty) return;

    // 显示进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在批量缓存...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      int totalSuccess = 0;
      int totalChapters = 0;

      for (final book in books) {
        if (book.isLocal) continue;

        final source =
            await BookSourceService.instance.getBookSourceByUrl(book.origin);
        if (source == null) continue;

        final chapters = await BookService.instance.getChapterList(book);
        if (chapters.isEmpty) continue;

        totalChapters += chapters.length;

        final results = await CacheService.instance.cacheChapters(
          book,
          chapters,
          source,
        );

        totalSuccess += results.values.where((v) => v == true).length;
      }

      if (!mounted) return;
      Navigator.pop(context);

      // 刷新缓存状态
      await _loadCacheStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量缓存完成：成功 $totalSuccess / $totalChapters 章')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量缓存失败: $e')),
        );
      }
    }
  }

  /// 显示导出书籍对话框（单个）
  void _showExportBookDialog(Book book) {
    String exportType = 'txt';
    bool isExporting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('导出书籍'),
          content: isExporting
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在导出...'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('确定要导出"${book.name}"吗？'),
                    const SizedBox(height: 16),
                    const Text('导出格式：'),
                    RadioListTile<String>(
                      title: const Text('TXT'),
                      value: 'txt',
                      groupValue: exportType,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            exportType = value;
                          });
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('EPUB'),
                      value: 'epub',
                      groupValue: exportType,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            exportType = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
          actions: isExporting
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () async {
                      setDialogState(() {
                        isExporting = true;
                      });

                      try {
                        bool success;
                        if (exportType == 'txt') {
                          success = await CacheExportService.instance
                              .exportAsTxt(book);
                        } else {
                          success = await CacheExportService.instance
                              .exportAsEpub(book);
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? '导出成功' : '导出失败'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('导出失败: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('确定'),
                  ),
                ],
        ),
      ),
    );
  }

  /// 显示导出书籍对话框（批量）
  void _showExportBooksDialog() {
    if (_selectedBookUrls.isEmpty) return;

    String exportType = 'txt';
    bool isExporting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('导出书籍'),
          content: isExporting
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在批量导出...'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('确定要导出选中的 ${_selectedBookUrls.length} 本书籍吗？'),
                    const SizedBox(height: 16),
                    const Text('导出格式：'),
                    RadioListTile<String>(
                      title: const Text('TXT'),
                      value: 'txt',
                      groupValue: exportType,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            exportType = value;
                          });
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('EPUB'),
                      value: 'epub',
                      groupValue: exportType,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            exportType = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
          actions: isExporting
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () async {
                      setDialogState(() {
                        isExporting = true;
                      });

                      try {
                        // 获取选中的书籍列表
                        final booksAsync =
                            ref.read(booksByGroupProvider(widget.groupId));
                        final allBooks = booksAsync.value ?? [];
                        final selectedBooks = allBooks
                            .where((book) =>
                                _selectedBookUrls.contains(book.bookUrl))
                            .toList();

                        // 批量导出
                        final results =
                            await CacheExportService.instance.exportBooks(
                          selectedBooks,
                          exportType,
                        );

                        final successCount =
                            results.values.where((v) => v).length;
                        final failCount = results.length - successCount;

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '导出完成：成功 $successCount 本，失败 $failCount 本',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('批量导出失败: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('确定'),
                  ),
                ],
        ),
      ),
    );
  }
}
