import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_chapter.dart';
import '../../../services/reader/cache_service.dart';
import '../../../services/book/book_service.dart';
import '../../../services/source/book_source_service.dart';
import '../../../utils/app_log.dart';
import 'cache_manage_page.dart';
import 'cache_export_dialog.dart';

/// 缓存书籍列表项
class CacheBookItem extends StatefulWidget {
  final Book book;
  final CacheInfo? cacheInfo;
  final VoidCallback? onCacheCleared;

  const CacheBookItem({
    super.key,
    required this.book,
    this.cacheInfo,
    this.onCacheCleared,
  });

  @override
  State<CacheBookItem> createState() => _CacheBookItemState();
}

class _CacheBookItemState extends State<CacheBookItem> {
  bool _isClearing = false;
  bool _isCaching = false;
  double _cachingProgress = 0.0;

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: Text('确定要清除《${widget.book.name}》的缓存吗？'),
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
      _isClearing = true;
    });

    try {
      await CacheService.instance.clearBookCache(widget.book);
      widget.onCacheCleared?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除缓存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  Future<void> _startCaching() async {
    if (widget.book.isLocal) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地书籍无需缓存')),
        );
      }
      return;
    }

    setState(() {
      _isCaching = true;
      _cachingProgress = 0.0;
    });

    try {
      // 获取书源
      final source = await BookSourceService.instance.getBookSourceByUrl(widget.book.origin);
      if (source == null) {
        throw Exception('书源不存在');
      }

      // 获取章节列表
      final chapters = await BookService.instance.getChapterList(widget.book);
      if (chapters.isEmpty) {
        throw Exception('章节列表为空');
      }

      // 过滤出未缓存的章节
      final uncachedChapters = <BookChapter>[];
      for (final chapter in chapters) {
        final hasCache = await CacheService.instance.hasChapterCache(widget.book, chapter);
        if (!hasCache) {
          uncachedChapters.add(chapter);
        }
      }

      if (uncachedChapters.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('所有章节已缓存')),
          );
        }
        return;
      }

      // 开始批量缓存
      await CacheService.instance.cacheChapters(
        widget.book,
        uncachedChapters,
        source,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _cachingProgress = current / total;
            });
          }
        },
      );

      // 通知父组件刷新
      widget.onCacheCleared?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('缓存完成：${uncachedChapters.length} 个章节')),
        );
      }
    } catch (e) {
      AppLog.instance.put('开始缓存失败: ${widget.book.name}', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('缓存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCaching = false;
          _cachingProgress = 0.0;
        });
      }
    }
  }

  Future<void> _exportBook() async {
    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => CacheExportDialog(book: widget.book),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cacheInfo = widget.cacheInfo;
    final progress = cacheInfo?.progress ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          // 可以跳转到书籍详情或缓存详情
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 封面
              Container(
                width: 60,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[300],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: widget.book.displayCover != null &&
                          widget.book.displayCover!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.book.displayCover!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.book,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.book,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // 书籍信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 书名
                    Text(
                      widget.book.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 作者
                    Text(
                      widget.book.displayAuthor,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 缓存信息
                    if (cacheInfo != null || _isCaching) ...[
                      if (_isCaching) ...[
                        // 显示缓存进度
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '正在缓存: ${(_cachingProgress * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _cachingProgress,
                              backgroundColor: Colors.grey[300],
                            ),
                          ],
                        ),
                      ] else if (cacheInfo != null) ...[
                        Row(
                          children: [
                            Text(
                              '已缓存: ${cacheInfo.cachedChapters}/${cacheInfo.totalChapters}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 进度条
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ] else ...[
                      Text(
                        '加载中...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 操作按钮
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'clear') {
                    _clearCache();
                  } else if (value == 'cache') {
                    _startCaching();
                  } else if (value == 'export') {
                    _exportBook();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'cache',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 8),
                        Text('开始缓存'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.file_download, size: 20),
                        SizedBox(width: 8),
                        Text('导出书籍'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('清除缓存', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: _isClearing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

