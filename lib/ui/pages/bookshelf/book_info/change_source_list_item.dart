import 'package:flutter/material.dart';
import '../../../../data/models/book.dart';

/// 换源列表项
class ChangeSourceListItem extends StatelessWidget {
  final Book book;
  final bool isCurrentSource;
  final VoidCallback onTap;

  const ChangeSourceListItem({
    super.key,
    required this.book,
    required this.isCurrentSource,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isCurrentSource ? theme.primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: book.coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  book.coverUrl!,
                  width: 50,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 70,
                      color: Colors.grey[300],
                      child: const Icon(Icons.book),
                    );
                  },
                ),
              )
            : Container(
                width: 50,
                height: 70,
                color: Colors.grey[300],
                child: const Icon(Icons.book),
              ),
        title: Text(
          book.originName,
          style: TextStyle(
            fontWeight: isCurrentSource ? FontWeight.bold : FontWeight.normal,
            color: isCurrentSource ? theme.primaryColor : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.kind != null && book.kind!.isNotEmpty)
              Text(
                '分类: ${book.kind}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (book.latestChapterTitle != null &&
                book.latestChapterTitle!.isNotEmpty)
              Text(
                '最新章节: ${book.latestChapterTitle}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (isCurrentSource)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '当前书源',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: isCurrentSource
            ? Icon(Icons.check_circle, color: theme.primaryColor)
            : const Icon(Icons.chevron_right),
        onTap: isCurrentSource ? null : onTap,
      ),
    );
  }
}

