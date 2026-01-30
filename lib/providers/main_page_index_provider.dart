import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 主页面索引 Provider
/// 用于管理主页面底部导航栏的当前索引
/// 0: 书架, 1: 发现, 2: RSS, 3: 我的
final mainPageIndexProvider = NotifierProvider<MainPageIndexNotifier, int>(() {
  return MainPageIndexNotifier();
});

class MainPageIndexNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  /// 设置当前页面索引
  void setIndex(int index) {
    if (index >= 0 && index <= 3) {
      state = index;
    }
  }

  /// 切换到书架页面
  void switchToBookshelf() {
    state = 0;
  }

  /// 切换到发现页面
  void switchToExplore() {
    state = 1;
  }

  /// 切换到RSS页面
  void switchToRss() {
    state = 2;
  }

  /// 切换到我的页面
  void switchToMy() {
    state = 3;
  }
}

