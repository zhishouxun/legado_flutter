import 'package:flutter/material.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_chapter.dart';
import '../../../data/models/book_source.dart';
import '../../../services/book/book_service.dart';
import '../reader/chapter_list_page.dart';
import 'explore_book_reader_page.dart';

/// 探索书籍章节列表页面
/// 参考项目：统一使用 ChapterListPage 显示目录
class ExploreBookChaptersPage extends StatefulWidget {
  final Book book;
  final BookSource bookSource;

  const ExploreBookChaptersPage({
    super.key,
    required this.book,
    required this.bookSource,
  });

  @override
  State<ExploreBookChaptersPage> createState() =>
      _ExploreBookChaptersPageState();
}

class _ExploreBookChaptersPageState extends State<ExploreBookChaptersPage> {
  List<BookChapter> _chapters = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 使用不保存到数据库的方法获取章节列表
      final chapters = await BookService.instance.getChapterListWithoutSave(
        widget.book,
      );

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoading = false;
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

  void _readChapter(int chapterIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExploreBookReaderPage(
          book: widget.book,
          bookSource: widget.bookSource,
          initialChapterIndex: chapterIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 加载中状态
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.book.name} - 目录'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 加载失败状态
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.book.name} - 目录'),
        ),
        body: Center(
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
        ),
      );
    }

    // 无章节状态
    if (_chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.book.name} - 目录'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '暂无章节',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // 使用统一的 ChapterListPage 显示目录
    return ChapterListPage(
      chapters: _chapters,
      currentChapterIndex: widget.book.durChapterIndex >= 0 &&
              widget.book.durChapterIndex < _chapters.length
          ? widget.book.durChapterIndex
          : 0,
      onChapterSelected: _readChapter,
    );
  }
}
