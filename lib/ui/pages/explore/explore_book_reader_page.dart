import 'package:flutter/material.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_chapter.dart';
import '../../../data/models/book_source.dart';
import '../../../services/book/book_service.dart';
import '../reader/chapter_list_page.dart';

/// 探索书籍阅读页面（不依赖书架）
class ExploreBookReaderPage extends StatefulWidget {
  final Book book;
  final BookSource bookSource;
  final int? initialChapterIndex;

  const ExploreBookReaderPage({
    super.key,
    required this.book,
    required this.bookSource,
    this.initialChapterIndex,
  });

  @override
  State<ExploreBookReaderPage> createState() => _ExploreBookReaderPageState();
}

class _ExploreBookReaderPageState extends State<ExploreBookReaderPage> {
  List<BookChapter> _chapters = [];
  int _currentChapterIndex = 0;
  String? _currentContent;
  bool _isLoading = true;
  bool _isLoadingContent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapterIndex ?? 0;
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final chapters = await BookService.instance.getChapterListWithoutSave(
        widget.book,
      );

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoading = false;
          if (_chapters.isNotEmpty) {
            _loadChapterContent(_currentChapterIndex);
          } else {
            _error = '暂无章节';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadChapterContent(int index) async {
    if (index < 0 || index >= _chapters.length) return;

    setState(() {
      _isLoadingContent = true;
      _currentContent = null;
    });

    try {
      final chapter = _chapters[index];
      final content = await BookService.instance.getChapterContent(
        chapter,
        widget.bookSource,
        bookName: widget.book.name,
        bookOrigin: widget.book.origin,
        book: widget.book, // 传入 book 参数，启用缓存优化
      );

      if (mounted) {
        setState(() {
          _currentChapterIndex = index;
          _currentContent = content ?? '无法加载章节内容';
          _isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentContent = '加载失败: $e';
          _isLoadingContent = false;
        });
      }
    }
  }

  /// 显示目录页面
  /// 参考项目：统一使用 ChapterListPage 显示目录
  void _showChapterList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterListPage(
          chapters: _chapters,
          currentChapterIndex: _currentChapterIndex,
          onChapterSelected: (index) {
            _loadChapterContent(index);
          },
        ),
      ),
    );
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      _loadChapterContent(_currentChapterIndex - 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是第一章')),
      );
    }
  }

  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      _loadChapterContent(_currentChapterIndex + 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是最后一章')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
              ? _chapters[_currentChapterIndex].title
              : widget.book.name,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showChapterList,
            tooltip: '目录',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
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
                        '加载失败',
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
                        onPressed: _loadChapters,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _isLoadingContent
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _currentContent == null
                      ? const Center(
                          child: Text('暂无内容'),
                        )
                      : Column(
                          children: [
                            // 章节信息栏
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Row(
                                children: [
                                  Text(
                                    '${_currentChapterIndex + 1}/${_chapters.length}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _previousChapter,
                                    icon: const Icon(Icons.chevron_left),
                                    label: const Text('上一章'),
                                  ),
                                  TextButton.icon(
                                    onPressed: _nextChapter,
                                    icon: const Text('下一章'),
                                    label: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ),
                            // 内容区域
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _currentContent!,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.8,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
    );
  }
}
