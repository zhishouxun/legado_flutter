import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_group.dart';
import '../../../services/book/book_service.dart';
import '../../../services/reader/cache_service.dart';
import '../../../providers/book_provider.dart';
import '../../widgets/base/base_bottom_sheet_consumer.dart';

/// 书架管理对话框
class BookshelfManageDialog extends BaseBottomSheetConsumer {
  final int groupId;

  const BookshelfManageDialog({
    super.key,
    required this.groupId,
  }) : super(
          title: '书架管理',
          heightFactor: 0.8,
        );

  @override
  ConsumerState<BookshelfManageDialog> createState() =>
      _BookshelfManageDialogState();
}

class _BookshelfManageDialogState
    extends BaseBottomSheetConsumerState<BookshelfManageDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedBookUrls = <String>{};
  bool _isSelectMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              color: Colors.orange.withOpacity(0.1),
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
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _showDeleteConfirmDialog(),
                  tooltip: '删除',
                ),
                IconButton(
                  icon: const Icon(Icons.folder_outlined),
                  onPressed: () => _showMoveToGroupDialog(),
                  tooltip: '移动到分组',
                ),
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () => _showClearCacheDialog(),
                  tooltip: '清除缓存',
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
                    subtitle: Text(book.author),
                    trailing: _isSelectMode
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (value) {
                              _handleBookAction(value, book);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 20),
                                    SizedBox(width: 8),
                                    Text('删除'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'move',
                                child: Row(
                                  children: [
                                    Icon(Icons.folder, size: 20),
                                    SizedBox(width: 8),
                                    Text('移动到分组'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'clear_cache',
                                child: Row(
                                  children: [
                                    Icon(Icons.clear_all, size: 20),
                                    SizedBox(width: 8),
                                    Text('清除缓存'),
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
      case 'delete':
        _showDeleteSingleBookDialog(book);
        break;
      case 'move':
        _showMoveSingleBookDialog(book);
        break;
      case 'clear_cache':
        _clearBookCache([book]);
        break;
    }
  }

  /// 显示删除确认对话框（单个）
  void _showDeleteSingleBookDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定要删除"${book.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await BookService.instance.deleteBook(book.bookUrl);
                ref.invalidate(booksByGroupProvider(widget.groupId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除')),
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
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 显示删除确认对话框（批量）
  void _showDeleteConfirmDialog() {
    if (_selectedBookUrls.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定要删除选中的 ${_selectedBookUrls.length} 本书籍吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                for (final bookUrl in _selectedBookUrls) {
                  await BookService.instance.deleteBook(bookUrl);
                }
                setState(() {
                  _selectedBookUrls.clear();
                  _isSelectMode = false;
                });
                ref.invalidate(booksByGroupProvider(widget.groupId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('已删除 ${_selectedBookUrls.length} 本书籍')),
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
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 显示移动到分组对话框（单个）
  void _showMoveSingleBookDialog(Book book) async {
    final groupsAsync = ref.read(bookGroupsProvider);
    final groups = groupsAsync.value ?? [];
    if (groups.isEmpty) return;

    final selectedGroup = await showDialog<BookGroup>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择分组'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(group.groupName),
                onTap: () => Navigator.pop(context, group),
              );
            },
          ),
        ),
      ),
    );

    if (selectedGroup == null) return;

    try {
      await BookService.instance
          .updateBookGroup(book.bookUrl, selectedGroup.groupId);
      ref.invalidate(booksByGroupProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已移动到"${selectedGroup.groupName}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移动失败: $e')),
        );
      }
    }
  }

  /// 显示移动到分组对话框（批量）
  void _showMoveToGroupDialog() async {
    if (_selectedBookUrls.isEmpty) return;

    final groupsAsync = ref.read(bookGroupsProvider);
    final groups = groupsAsync.value ?? [];
    if (groups.isEmpty) return;

    final selectedGroup = await showDialog<BookGroup>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择分组'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(group.groupName),
                onTap: () => Navigator.pop(context, group),
              );
            },
          ),
        ),
      ),
    );

    if (selectedGroup == null) return;

    try {
      final count = _selectedBookUrls.length;
      for (final bookUrl in _selectedBookUrls) {
        await BookService.instance
            .updateBookGroup(bookUrl, selectedGroup.groupId);
      }
      setState(() {
        _selectedBookUrls.clear();
        _isSelectMode = false;
      });
      ref.invalidate(booksByGroupProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('已移动 $count 本书籍到"${selectedGroup.groupName}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移动失败: $e')),
        );
      }
    }
  }

  /// 清除缓存对话框
  void _showClearCacheDialog() {
    if (_selectedBookUrls.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: Text('确定要清除选中的 ${_selectedBookUrls.length} 本书籍的缓存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 获取选中的书籍
              ref
                  .read(booksByGroupProvider(widget.groupId).future)
                  .then((books) {
                final selectedBooks = books
                    .where((b) => _selectedBookUrls.contains(b.bookUrl))
                    .toList();
                _clearBookCache(selectedBooks);
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 清除书籍缓存
  Future<void> _clearBookCache(List<Book> books) async {
    try {
      final results = await CacheService.instance.clearBooksCache(books);
      final successCount = results.values.where((v) => v == true).length;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('清除缓存完成：成功 $successCount / ${books.length} 本')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除缓存失败: $e')),
        );
      }
    }
  }
}
