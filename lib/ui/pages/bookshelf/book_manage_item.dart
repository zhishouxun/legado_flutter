import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/book.dart';
import '../../../services/book/book_service.dart';
import 'book_info/book_info_page.dart';

/// 书籍管理列表项
class BookManageItem extends StatelessWidget {
  final Book book;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const BookManageItem({
    super.key,
    required this.book,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : null,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // 选择框
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
            ),
            const SizedBox(width: 12),
            // 封面
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[300],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: book.displayCover != null && book.displayCover!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: book.displayCover!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.book,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.book,
                          color: Colors.grey,
                          size: 20,
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
                    book.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 作者
                  Text(
                    book.displayAuthor,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 状态信息
                  Row(
                    children: [
                      if (!book.canUpdate)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '不更新',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      if (book.isLocal) ...[
                        if (!book.canUpdate) const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '本地',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 更多操作
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                _showItemMenu(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showItemMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BookInfoPage(
                      key: ValueKey('book_info_${book.bookUrl}'),
                      bookUrl: book.bookUrl,
                      bookName: book.name,
                      author: book.author,
                      sourceUrl: book.origin,
                      coverUrl: book.coverUrl,
                      intro: book.intro,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                // 显示确认对话框
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认删除'),
                    content: Text('确定要删除《${book.name}》吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await BookService.instance.deleteBook(book.bookUrl);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('删除成功')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('删除失败: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

