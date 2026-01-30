import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/rss_star.dart';
import '../../../services/rss_service.dart';
import 'rss_read_page.dart';

/// RSS收藏列表Provider
final rssFavoritesListProvider = FutureProvider.family<List<RssStar>, String?>((ref, group) async {
  final service = RssService.instance;
  return await service.getRssStars(group: group);
});

/// RSS收藏分组列表Provider
final rssFavoritesGroupsProvider = FutureProvider<List<String>>((ref) async {
  final service = RssService.instance;
  return await service.getStarGroups();
});

/// RSS收藏页面
/// 参考项目：RssFavoritesActivity.kt
class RssFavoritesPage extends ConsumerStatefulWidget {
  const RssFavoritesPage({super.key});

  @override
  ConsumerState<RssFavoritesPage> createState() => _RssFavoritesPageState();
}

class _RssFavoritesPageState extends ConsumerState<RssFavoritesPage> {
  String? _selectedGroup;
  final TextEditingController _searchController = TextEditingController();
  String _searchKey = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteStar(RssStar star) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏'),
        content: Text('确定要删除收藏吗？\n<${star.title}>'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await RssService.instance.deleteRssStar(star.origin, star.link);
      if (mounted) {
        ref.invalidate(rssFavoritesListProvider(_selectedGroup));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
      }
    }
  }

  Future<void> _readStar(RssStar star) async {
    // 将RssStar转换为RssArticle并打开阅读页面
    final article = star.toRssArticle();
    final source = await RssService.instance.getRssSourceByUrl(star.origin);
    
    if (source != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RssReadPage(
            source: source,
            article: article,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(rssFavoritesGroupsProvider);
    final favoritesAsync = ref.watch(rssFavoritesListProvider(_selectedGroup));

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          // 分组选择
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) return const SizedBox.shrink();
              return PopupMenuButton<String?>(
                icon: const Icon(Icons.filter_list),
                tooltip: '选择分组',
                onSelected: (group) {
                  setState(() {
                    _selectedGroup = group;
                  });
                  ref.invalidate(rssFavoritesListProvider(_selectedGroup));
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: null,
                    child: Text('全部分组'),
                  ),
                  ...groups.map((group) => PopupMenuItem(
                    value: group,
                    child: Text(group),
                  )),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索收藏',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchKey.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchKey = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchKey = value;
                });
              },
            ),
          ),
          // 收藏列表
          Expanded(
            child: favoritesAsync.when(
              data: (stars) {
                // 过滤搜索结果
                final filteredStars = _searchKey.isEmpty
                    ? stars
                    : stars.where((star) {
                        return star.title.toLowerCase().contains(_searchKey.toLowerCase()) ||
                            (star.description?.toLowerCase().contains(_searchKey.toLowerCase()) ?? false);
                      }).toList();

                if (filteredStars.isEmpty) {
                  return Center(
                    child: Text(
                      _searchKey.isEmpty ? '暂无收藏' : '未找到相关收藏',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(rssFavoritesListProvider(_selectedGroup));
                  },
                  child: ListView.builder(
                    itemCount: filteredStars.length,
                    itemBuilder: (context, index) {
                      final star = filteredStars[index];
                      return ListTile(
                        leading: star.image != null && star.image!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  star.image!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.article, size: 40);
                                  },
                                ),
                              )
                            : const Icon(Icons.article, size: 40),
                        title: Text(
                          star.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (star.pubDate != null && star.pubDate!.isNotEmpty)
                              Text(
                                star.pubDate!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            if (star.group.isNotEmpty && star.group != '默认分组')
                              Text(
                                star.group,
                                style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteStar(star),
                          tooltip: '删除收藏',
                        ),
                        onTap: () => _readStar(star),
                        onLongPress: () => _deleteStar(star),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('加载失败: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(rssFavoritesListProvider(_selectedGroup));
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

