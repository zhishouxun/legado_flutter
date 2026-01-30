import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/main_page_index_provider.dart';
import '../../../providers/scroll_control_provider.dart';
import '../../../providers/book_update_count_provider.dart';
import '../../../config/app_config.dart';
import '../bookshelf/bookshelf_page.dart';
import '../explore/explore_page.dart';
import '../rss/rss_page.dart';
import '../my/my_page.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  DateTime? _lastExitTime;
  static const Duration _exitInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    // 延迟执行，确保页面已构建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setDefaultHomePage();
    });
  }

  /// 设置默认首页
  void _setDefaultHomePage() {
    final defaultPage = AppConfig.getDefaultHomePage();
    final indexNotifier = ref.read(mainPageIndexProvider.notifier);
    
    switch (defaultPage) {
      case 'explore':
        indexNotifier.setIndex(1);
        break;
      case 'rss':
        indexNotifier.setIndex(2);
        break;
      case 'my':
        indexNotifier.setIndex(3);
        break;
      case 'bookshelf':
      default:
        indexNotifier.setIndex(0);
        break;
    }
  }

  /// 处理返回按钮
  Future<bool> _onWillPop() async {
    final currentIndex = ref.read(mainPageIndexProvider);
    
    // 如果不在书架页面，先返回书架页面
    if (currentIndex != 0) {
      ref.read(mainPageIndexProvider.notifier).setIndex(0);
      return false;
    }

    // 在书架页面，检查是否双击退出
    final now = DateTime.now();
    if (_lastExitTime == null || 
        now.difference(_lastExitTime!) > _exitInterval) {
      _lastExitTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再按一次退出应用'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    return true;
  }

  /// 处理Tab选择
  void _onDestinationSelected(int index) {
    final indexNotifier = ref.read(mainPageIndexProvider.notifier);
    final currentIndex = ref.read(mainPageIndexProvider);
    
    // 检查是否是重新选择同一个Tab
    if (currentIndex == index) {
      // Tab重新选择，触发滚动到顶部
      if (index == 0) {
        // 书架页面，滚动到顶部
        ref.read(bookshelfScrollControlProvider.notifier).scrollToTop();
      } else if (index == 1) {
        // 发现页面，滚动到顶部
        ref.read(exploreScrollControlProvider.notifier).scrollToTop();
      }
    } else {
      // 正常切换Tab
      indexNotifier.setIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainPageIndexProvider);
    final updateCount = ref.watch(bookUpdateCountProvider);

    final pages = const [
      BookshelfPage(),
      ExplorePage(),
      RssPage(),
      MyPage(),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            // 退出应用
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            NavigationDestination(
              icon: Badge(
                label: Text(updateCount > 99 ? '99+' : updateCount.toString()),
                isLabelVisible: updateCount > 0,
                child: const Icon(Icons.library_books_outlined),
              ),
              selectedIcon: Badge(
                label: Text(updateCount > 99 ? '99+' : updateCount.toString()),
                isLabelVisible: updateCount > 0,
                child: const Icon(Icons.library_books),
              ),
              label: '书架',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: '发现',
            ),
            const NavigationDestination(
              icon: Icon(Icons.rss_feed_outlined),
              selectedIcon: Icon(Icons.rss_feed),
              label: '订阅',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}

