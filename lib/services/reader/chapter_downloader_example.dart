import 'package:flutter/material.dart';
import 'chapter_downloader_service.dart';
import '../../data/models/book.dart';
import '../book/book_service.dart';
import '../source/book_source_service.dart';

/// 基于Isolate的章节下载器使用示例
/// 
/// 展示3种常见下载场景:
/// 1. 下载全本
/// 2. 缓存后N章
/// 3. 缓存选定章节

// ==================== 示例1: 下载全本 ====================

class DownloadWholeBookExample extends StatefulWidget {
  final Book book;

  const DownloadWholeBookExample({Key? key, required this.book}) : super(key: key);

  @override
  State<DownloadWholeBookExample> createState() => _DownloadWholeBookExampleState();
}

class _DownloadWholeBookExampleState extends State<DownloadWholeBookExample> {
  final _downloader = ChapterDownloaderService.instance;

  @override
  void initState() {
    super.initState();
    // 监听下载进度
    _downloader.progressNotifier.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    _downloader.progressNotifier.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    if (mounted) {
      setState(() {}); // 更新UI
    }
  }

  /// 开始下载全本
  Future<void> _startDownloadWholeBook() async {
    try {
      // 1. 获取所有章节
      final chapters = await BookService.instance.getChapterList(widget.book);
      if (chapters.isEmpty) {
        _showMessage('该书没有章节');
        return;
      }

      // 2. 获取书源
      final source = await BookSourceService.instance
          .getBookSourceByUrl(widget.book.origin);
      if (source == null) {
        _showMessage('书源不存在');
        return;
      }

      // 3. 开始下载
      await _downloader.startDownload(
        book: widget.book,
        chapters: chapters,
        source: source,
        batchSize: 10, // 每批10章
        showNotification: true,
      );
    } catch (e) {
      _showMessage('启动下载失败: $e');
    }
  }

  /// 停止下载
  Future<void> _stopDownload() async {
    await _downloader.stopDownload();
    _showMessage('已停止下载');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _downloader.progressNotifier.value;
    final isDownloading = _downloader.isDownloading;

    return Scaffold(
      appBar: AppBar(
        title: Text('下载: ${widget.book.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 进度指示器
            if (isDownloading) ...[
              CircularProgressIndicator(value: progress.progress),
              const SizedBox(height: 16),
              Text(
                '${progress.completed}/${progress.total}章',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (progress.currentChapter != null)
                Text(
                  '正在下载: ${progress.currentChapter}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],

            // 状态文本
            if (!isDownloading) ...[
              Text(
                _getStatusText(progress.status),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (progress.status == DownloadStatus.error)
                Text(
                  '错误: ${progress.error}',
                  style: const TextStyle(color: Colors.red),
                ),
            ],

            const SizedBox(height: 32),

            // 操作按钮
            if (!isDownloading)
              ElevatedButton.icon(
                onPressed: _startDownloadWholeBook,
                icon: const Icon(Icons.download),
                label: const Text('下载全本'),
              )
            else
              ElevatedButton.icon(
                onPressed: _stopDownload,
                icon: const Icon(Icons.stop),
                label: const Text('停止下载'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.idle:
        return '准备下载';
      case DownloadStatus.downloading:
        return '下载中...';
      case DownloadStatus.completed:
        return '下载完成!';
      case DownloadStatus.cancelled:
        return '已取消';
      case DownloadStatus.error:
        return '下载失败';
    }
  }
}

// ==================== 示例2: 缓存后N章 ====================

/// 缓存后N章(自动预加载)
class CacheNextChaptersExample {
  static Future<void> cacheNextChapters({
    required Book book,
    required int currentIndex,
    int count = 3, // 默认缓存后3章
  }) async {
    try {
      // 1. 获取章节列表
      final allChapters = await BookService.instance.getChapterList(book);
      if (allChapters.isEmpty) return;

      // 2. 计算要缓存的章节范围
      final startIndex = currentIndex + 1;
      final endIndex = (startIndex + count).clamp(0, allChapters.length);
      
      if (startIndex >= allChapters.length) {
        print('已是最后一章,无需缓存');
        return;
      }

      final chaptersToCache = allChapters.sublist(startIndex, endIndex);

      // 3. 获取书源
      final source = await BookSourceService.instance
          .getBookSourceByUrl(book.origin);
      if (source == null) {
        print('书源不存在');
        return;
      }

      // 4. 开始后台缓存(不显示通知)
      await ChapterDownloaderService.instance.startDownload(
        book: book,
        chapters: chaptersToCache,
        source: source,
        batchSize: 3,
        showNotification: false, // 静默下载
      );

      print('开始缓存后$count章');
    } catch (e) {
      print('缓存后续章节失败: $e');
    }
  }
}

// ==================== 示例3: 带进度UI的下载Widget ====================

class DownloadProgressWidget extends StatefulWidget {
  const DownloadProgressWidget({Key? key}) : super(key: key);

  @override
  State<DownloadProgressWidget> createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget> {
  final _downloader = ChapterDownloaderService.instance;

  @override
  void initState() {
    super.initState();
    _downloader.progressNotifier.addListener(_update);
  }

  @override
  void dispose() {
    _downloader.progressNotifier.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = _downloader.progressNotifier.value;
    final isDownloading = _downloader.isDownloading;

    if (!isDownloading || progress.status != DownloadStatus.downloading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: progress.progress,
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              '下载中 ${progress.completed}/${progress.total}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () => _downloader.stopDownload(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ==================== 示例4: 书架上的下载角标 ====================

class BookCoverWithDownloadBadge extends StatefulWidget {
  final Book book;

  const BookCoverWithDownloadBadge({Key? key, required this.book}) : super(key: key);

  @override
  State<BookCoverWithDownloadBadge> createState() => _BookCoverWithDownloadBadgeState();
}

class _BookCoverWithDownloadBadgeState extends State<BookCoverWithDownloadBadge> {
  final _downloader = ChapterDownloaderService.instance;

  @override
  void initState() {
    super.initState();
    _downloader.progressNotifier.addListener(_update);
  }

  @override
  void dispose() {
    _downloader.progressNotifier.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = _downloader.progressNotifier.value;
    final isDownloading = _downloader.isDownloading;

    return Stack(
      children: [
        // 书籍封面
        Container(
          width: 100,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.book, size: 48),
          ),
        ),

        // 下载进度覆盖层
        if (isDownloading && progress.status == DownloadStatus.downloading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: progress.progress,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==================== 使用指南 ====================

/// 使用指南:
/// 
/// 1. 下载全本:
///    ```dart
///    Navigator.push(
///      context,
///      MaterialPageRoute(
///        builder: (_) => DownloadWholeBookExample(book: book),
///      ),
///    );
///    ```
/// 
/// 2. 自动缓存后3章(在翻页时调用):
///    ```dart
///    @override
///    void onPageChanged(int index) {
///      // 用户翻到新章节时,自动缓存后3章
///      CacheNextChaptersExample.cacheNextChapters(
///        book: widget.book,
///        currentIndex: index,
///        count: 3,
///      );
///    }
///    ```
/// 
/// 3. 在书架显示下载进度:
///    ```dart
///    BookCoverWithDownloadBadge(book: book)
///    ```
/// 
/// 4. 全局下载进度条(Overlay):
///    ```dart
///    Overlay.of(context).insert(
///      OverlayEntry(
///        builder: (_) => Positioned(
///          bottom: 80,
///          left: 16,
///          child: DownloadProgressWidget(),
///        ),
///      ),
///    );
///    ```
/// 
/// 性能优势:
/// - ✅ 下载在Worker Isolate执行,UI完全不卡顿
/// - ✅ 支持批量下载,事务提交
/// - ✅ 自动过滤已缓存章节
/// - ✅ 支持取消和进度通知
/// - ✅ 内存优化,避免大量章节同时加载
