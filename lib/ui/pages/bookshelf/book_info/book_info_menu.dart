import 'package:flutter/material.dart';
import '../../../../data/models/book.dart';

/// 书籍详情菜单组件
class BookInfoMenu extends StatelessWidget {
  final Book book;
  final bool isInBookshelf;
  final VoidCallback? onRefresh;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;

  const BookInfoMenu({
    super.key,
    required this.book,
    required this.isInBookshelf,
    this.onRefresh,
    this.onEdit,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'refresh':
            onRefresh?.call();
            break;
          case 'edit':
            onEdit?.call();
            break;
          case 'share':
            onShare?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (isInBookshelf)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('编辑'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20),
              SizedBox(width: 8),
              Text('刷新'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 20),
              SizedBox(width: 8),
              Text('分享'),
            ],
          ),
        ),
      ],
    );
  }
}

