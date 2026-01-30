import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/rss_source.dart';
import '../../../data/models/rss_article.dart';
import '../../../services/rss/rss_parser_service.dart';
import '../../../utils/helpers/source/rss_source_extensions.dart';
import 'rss_article_item_widget.dart';
import 'rss_read_page.dart';
import '../../widgets/common/custom_tab_bar.dart';

/// RSS文章排序/分类页面
/// 参考项目：RssSortActivity.kt
/// 支持多个分类Tab，每个Tab显示对应分类的文章列表
class RssArticlesSortPage extends ConsumerStatefulWidget {
  final RssSource source;

  const RssArticlesSortPage({
    super.key,
    required this.source,
  });

  @override
  ConsumerState<RssArticlesSortPage> createState() => _RssArticlesSortPageState();
}

class _RssArticlesSortPageState extends ConsumerState<RssArticlesSortPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MapEntry<String, String>> _sortList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSortUrls();
  }

  Future<void> _loadSortUrls() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sortUrls = await widget.source.sortUrls();
      if (mounted) {
        setState(() {
          _sortList = sortUrls;
          _tabController = TabController(
            length: _sortList.length,
            vsync: this,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载分类失败: $e')),
        );
      }
    }
  }

  Future<void> _clearSortCache() async {
    await widget.source.removeSortCache();
    if (mounted) {
      await _loadSortUrls();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除分类缓存')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.source.sourceName),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 如果只有一个分类，直接显示文章列表
    if (_sortList.length == 1) {
      final sort = _sortList.first;
      return _buildArticlesList(sort.key, sort.value);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.sourceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearSortCache,
            tooltip: '刷新分类',
          ),
        ],
        bottom: CustomTabBar(
          controller: _tabController,
          isScrollable: _sortList.length > 3,
          tabs: _sortList.map((sort) {
            final name = sort.key.isEmpty ? '全部' : sort.key;
            return Tab(text: name);
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _sortList.map((sort) {
          return _buildArticlesList(sort.key, sort.value);
        }).toList(),
      ),
    );
  }

  Widget _buildArticlesList(String sortName, String sortUrl) {
    return Consumer(
      builder: (context, ref, child) {
        // 创建基于sortName和sortUrl的Provider
        final articlesAsync = ref.watch(
          FutureProvider.family<List<RssArticle>, Map<String, String>>(
            (ref, params) async {
              return await RssParserService.instance.getArticles(
                source: widget.source,
                sortName: params['sortName'] ?? '',
                sortUrl: params['sortUrl'],
              );
            },
          ).call({'sortName': sortName, 'sortUrl': sortUrl}),
        );

        return articlesAsync.when(
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
                          source: widget.source,
                          article: article,
                        ),
                      ),
                    ).then((_) {
                      ref.invalidate(
                        FutureProvider.family<List<RssArticle>, Map<String, String>>(
                          (ref, params) async {
                            return await RssParserService.instance.getArticles(
                              source: widget.source,
                              sortName: params['sortName'] ?? '',
                              sortUrl: params['sortUrl'],
                            );
                          },
                        ).call({'sortName': sortName, 'sortUrl': sortUrl}),
                      );
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
                    ref.invalidate(
                      FutureProvider.family<List<RssArticle>, Map<String, String>>(
                        (ref, params) async {
                          return await RssParserService.instance.getArticles(
                            source: widget.source,
                            sortName: params['sortName'] ?? '',
                            sortUrl: params['sortUrl'],
                          );
                        },
                      ).call({'sortName': sortName, 'sortUrl': sortUrl}),
                    );
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

