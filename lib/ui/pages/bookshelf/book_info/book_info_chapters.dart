import 'package:flutter/material.dart';
import '../../../../data/models/book.dart';
import '../../../../data/models/book_chapter.dart';
import '../../../../services/book/book_service.dart';
import '../../../../utils/app_log.dart';

/// 书籍章节列表组件
class BookInfoChapters extends StatefulWidget {
  final Book book;
  final VoidCallback? onChapterTap;
  final bool isInBookshelf; // 是否在书架中

  const BookInfoChapters({
    super.key,
    required this.book,
    this.onChapterTap,
    this.isInBookshelf = true, // 默认为true，保持向后兼容
  });

  @override
  State<BookInfoChapters> createState() => _BookInfoChaptersState();
}

class _BookInfoChaptersState extends State<BookInfoChapters> {
  List<BookChapter> _chapters = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  @override
  void didUpdateWidget(BookInfoChapters oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果书籍或书架状态发生变化，重新加载章节
    if (oldWidget.book.bookUrl != widget.book.bookUrl ||
        oldWidget.isInBookshelf != widget.isInBookshelf) {
      _loadChapters();
    }
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 确保服务已初始化
      if (!BookService.instance.isInitialized) {
        await BookService.instance.init();
      }
      
      // 如果书籍不在书架，使用不保存到数据库的方法
      final chapters = widget.isInBookshelf
          ? await BookService.instance.getChapterList(widget.book)
          : await BookService.instance.getChapterListWithoutSave(widget.book);
      
      AppLog.instance.put('加载章节列表完成: 书籍=${widget.book.displayName}, 章节数=${chapters.length}');
      
      setState(() {
        _chapters = chapters;
        _isLoading = false;
        _errorMessage = chapters.isEmpty ? '未找到章节' : null;
      });
    } catch (e, stackTrace) {
      AppLog.instance.put('加载章节列表失败: 书籍=${widget.book.displayName}', error: e);
      AppLog.instance.put('错误堆栈: $stackTrace');
      
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = theme.textTheme.bodySmall?.color ?? Colors.grey[600];

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: widget.onChapterTap,
        child: Row(
          children: [
            Icon(
              Icons.folder_open,
              size: 18,
              color: textColor,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                _isLoading
                    ? '目录（加载中...）'
                    : _chapters.isEmpty
                        ? (_errorMessage != null 
                            ? '目录（加载失败）' 
                            : '目录（暂无章节）')
                        : widget.book.durChapterTitle != null &&
                                widget.book.durChapterTitle!.isNotEmpty
                            ? '目录（${widget.book.durChapterTitle}）'
                            : '目录（共${_chapters.length}章）',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!_isLoading && _chapters.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '查看目录',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
