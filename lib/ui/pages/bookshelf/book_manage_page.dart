import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_group.dart';
import '../../../services/book/book_service.dart';
import '../../../services/book_group_service.dart';
import '../../../services/reader/cache_service.dart';
import 'book_manage_item.dart';
import 'book_manage_action_bar.dart';
import 'book_manage_batch_actions.dart';
import 'book_info/book_info_page.dart';

/// 书籍管理页面
class BookManagePage extends ConsumerStatefulWidget {
  final int? groupId;

  const BookManagePage({
    super.key,
    this.groupId,
  });

  @override
  ConsumerState<BookManagePage> createState() => _BookManagePageState();
}

class _BookManagePageState extends ConsumerState<BookManagePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Book> _books = [];
  List<Book> _filteredBooks = [];
  Set<String> _selectedBookUrls = {};
  bool _isLoading = true;
  int? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final books = _selectedGroupId != null
          ? await BookService.instance.getBooksByGroup(_selectedGroupId!)
          : await BookService.instance.getBookshelfBooks();

      setState(() {
        _books = books;
        _filteredBooks = books;
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

  void _filterBooks(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        _filteredBooks = _books;
      });
      return;
    }

    setState(() {
      _filteredBooks = _books.where((book) {
        return book.name.toLowerCase().contains(keyword.toLowerCase()) ||
            book.author.toLowerCase().contains(keyword.toLowerCase());
      }).toList();
    });
  }

  void _toggleSelection(String bookUrl) {
    setState(() {
      if (_selectedBookUrls.contains(bookUrl)) {
        _selectedBookUrls.remove(bookUrl);
      } else {
        _selectedBookUrls.add(bookUrl);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedBookUrls.length == _filteredBooks.length) {
        _selectedBookUrls.clear();
      } else {
        _selectedBookUrls = _filteredBooks.map((book) => book.bookUrl).toSet();
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedBookUrls.clear();
    });
  }

  List<Book> get _selectedBooks {
    return _filteredBooks
        .where((book) => _selectedBookUrls.contains(book.bookUrl))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedBookUrls.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('书籍管理'),
        actions: [
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
              tooltip: '取消选择',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索书籍...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterBooks('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: _filterBooks,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 批量操作栏
          if (hasSelection)
            BookManageActionBar(
              selectedCount: _selectedBookUrls.length,
              totalCount: _filteredBooks.length,
              onSelectAll: _selectAll,
              onClearSelection: _clearSelection,
              onBatchAction: (action) => _handleBatchAction(action),
            ),
          // 书籍列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? '没有找到匹配的书籍'
                                  : '暂无书籍',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = _filteredBooks[index];
                          final isSelected = _selectedBookUrls.contains(book.bookUrl);
                          return BookManageItem(
                            book: book,
                            isSelected: isSelected,
                            onTap: () {
                              if (hasSelection) {
                                _toggleSelection(book.bookUrl);
                              } else {
                                // 跳转到书籍详情
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => BookInfoPage(
                                      key: ValueKey('book_info_${book.bookUrl}'),
                                      bookUrl: book.bookUrl,
                                    ),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
                              _toggleSelection(book.bookUrl);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBatchAction(BatchAction action) async {
    final selectedBooks = _selectedBooks;
    if (selectedBooks.isEmpty) return;

    switch (action) {
      case BatchAction.delete:
        await _batchDelete(selectedBooks);
        break;
      case BatchAction.moveToGroup:
        await _batchMoveToGroup(selectedBooks);
        break;
      case BatchAction.addToGroup:
        await _batchAddToGroup(selectedBooks);
        break;
      case BatchAction.clearCache:
        await _batchClearCache(selectedBooks);
        break;
      case BatchAction.enableUpdate:
        await _batchUpdateCanUpdate(selectedBooks, true);
        break;
      case BatchAction.disableUpdate:
        await _batchUpdateCanUpdate(selectedBooks, false);
        break;
    }
  }

  Future<void> _batchDelete(List<Book> books) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${books.length} 本书籍吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final book in books) {
        await BookService.instance.deleteBook(book.bookUrl);
      }

      _clearSelection();
      await _loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${books.length} 本书籍')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _batchMoveToGroup(List<Book> books) async {
    final groups = await BookGroupService.instance.getAllGroups();
    
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
                onTap: () => Navigator.of(context).pop(group),
              );
            },
          ),
        ),
      ),
    );

    if (selectedGroup == null) return;

    try {
      for (final book in books) {
        await BookService.instance.updateBookGroup(book.bookUrl, selectedGroup.groupId);
      }

      _clearSelection();
      await _loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已移动到分组')),
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

  Future<void> _batchAddToGroup(List<Book> books) async {
    final groups = await BookGroupService.instance.getAllGroups();
    
    final selectedGroup = await showDialog<BookGroup>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到分组'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(group.groupName),
                onTap: () => Navigator.of(context).pop(group),
              );
            },
          ),
        ),
      ),
    );

    if (selectedGroup == null) return;

    try {
      for (final book in books) {
        // 添加到分组（使用位运算，这里简化处理为直接设置）
        await BookService.instance.updateBookGroup(book.bookUrl, selectedGroup.groupId);
      }

      _clearSelection();
      await _loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到分组')),
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

  Future<void> _batchClearCache(List<Book> books) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: Text('确定要清除选中 ${books.length} 本书籍的缓存吗？'),
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

    try {
      for (final book in books) {
        await CacheService.instance.clearBookCache(book);
      }

      _clearSelection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清除 ${books.length} 本书籍的缓存')),
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

  Future<void> _batchUpdateCanUpdate(List<Book> books, bool canUpdate) async {
    try {
      for (final book in books) {
        await BookService.instance.updateBook(
          book.copyWith(canUpdate: canUpdate),
        );
      }

      _clearSelection();
      await _loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已${canUpdate ? '启用' : '禁用'}更新')),
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
}


