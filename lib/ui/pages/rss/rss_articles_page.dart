import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/rss_source.dart';
import '../../../data/models/rss_article.dart';
import '../../../services/rss_service.dart';
import 'rss_article_item_widget.dart';
import 'rss_read_page.dart';
import 'rss_read_record_dialog.dart';

/// RSS文章列表Provider
final rssArticlesProvider = FutureProvider.family<List<RssArticle>, String?>((ref, origin) async {
  final service = RssService.instance;
  return await service.getRssArticles(origin: origin, limit: 100);
});

/// RSS文章列表页面
class RssArticlesPage extends ConsumerWidget {
  final RssSource source;

  const RssArticlesPage({super.key, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(rssArticlesProvider(source.sourceUrl));

    return Scaffold(
      appBar: AppBar(
        title: Text(source.sourceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const RssReadRecordDialog(),
              );
            },
            tooltip: '阅读记录',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                // 显示加载提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('正在刷新...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                
                // 刷新RSS文章
                final count = await RssService.instance.refreshRssArticles(source);
                
                // 刷新列表
                ref.invalidate(rssArticlesProvider(source.sourceUrl));
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('刷新完成，获取到 $count 篇文章'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('刷新失败: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: articlesAsync.when(
        data: (articles) {
          if (articles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无文章',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        // 刷新RSS文章
                        final count = await RssService.instance.refreshRssArticles(source);
                        
                        // 刷新列表
                        ref.invalidate(rssArticlesProvider(source.sourceUrl));
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('刷新完成，获取到 $count 篇文章'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('刷新失败: $e'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return RssArticleItemWidget(
                article: article,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RssReadPage(
                        source: source,
                        article: article,
                      ),
                    ),
                  ).then((_) {
                    ref.invalidate(rssArticlesProvider(source.sourceUrl));
                  });
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(rssArticlesProvider(source.sourceUrl));
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

