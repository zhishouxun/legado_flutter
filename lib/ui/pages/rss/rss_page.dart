import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/rss_source.dart';
import '../../../services/rss_service.dart';
import 'rss_source_item_widget.dart';
import 'rss_source_manage_page.dart';
import 'rss_articles_page.dart';
import 'rss_articles_sort_page.dart';
import 'rss_favorites_page.dart';

/// RSS源列表Provider（仅启用的）
final enabledRssSourceListProvider =
    FutureProvider<List<RssSource>>((ref) async {
  final service = RssService.instance;
  return await service.getEnabledRssSources();
});

/// RSS订阅页面
class RssPage extends ConsumerWidget {
  const RssPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rssSourcesAsync = ref.watch(enabledRssSourceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RssFavoritesPage(),
                ),
              );
            },
            tooltip: '收藏',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (context) => const RssSourceManagePage(),
                ),
              )
                  .then((_) {
                ref.invalidate(enabledRssSourceListProvider);
              });
            },
            tooltip: 'RSS源管理',
          ),
        ],
      ),
      body: rssSourcesAsync.when(
        data: (sources) {
          if (sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rss_feed,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无RSS源',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(
                          builder: (context) => const RssSourceManagePage(),
                        ),
                      )
                          .then((_) {
                        ref.invalidate(enabledRssSourceListProvider);
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('添加RSS源'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return RssSourceItemWidget(
                source: source,
                onTap: () {
                  // 检查是否有分类URL，如果有则使用排序页面
                  if (source.sortUrl != null && source.sortUrl!.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RssArticlesSortPage(source: source),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RssArticlesPage(source: source),
                      ),
                    );
                  }
                },
                onToggleEnabled: (enabled) async {
                  await RssService.instance.updateRssSourceEnabled(
                    source.sourceUrl,
                    enabled,
                  );
                  ref.invalidate(enabledRssSourceListProvider);
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
                  ref.invalidate(enabledRssSourceListProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
            MaterialPageRoute(
              builder: (context) => const RssSourceManagePage(),
            ),
          )
              .then((_) {
            ref.invalidate(enabledRssSourceListProvider);
          });
        },
        tooltip: '添加RSS源',
        child: const Icon(Icons.add),
      ),
    );
  }
}
