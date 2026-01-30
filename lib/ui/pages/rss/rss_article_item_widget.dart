import 'package:flutter/material.dart';
import '../../../data/models/rss_article.dart';

/// RSS文章项组件
class RssArticleItemWidget extends StatelessWidget {
  final RssArticle article;
  final VoidCallback onTap;

  const RssArticleItemWidget({
    super.key,
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: article.image != null && article.image!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  article.image!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.article, size: 40);
                  },
                ),
              )
            : Icon(
                article.read ? Icons.article : Icons.article_outlined,
                size: 40,
                color: article.read ? Colors.grey : Theme.of(context).primaryColor,
              ),
        title: Text(
          article.title,
          style: TextStyle(
            fontWeight: article.read ? FontWeight.normal : FontWeight.bold,
            decoration: article.read ? TextDecoration.lineThrough : null,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.description != null && article.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                article.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (article.pubDate != null && article.pubDate!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                article.pubDate!,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        trailing: article.read
            ? const Icon(Icons.check_circle, color: Colors.grey, size: 20)
            : const Icon(Icons.circle_outlined, color: Colors.blue, size: 20),
        onTap: onTap,
      ),
    );
  }
}

