import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 滚动控制Provider
/// 用于控制页面滚动到顶部
class ScrollControlNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  /// 触发滚动到顶部
  void scrollToTop() {
    state = state + 1; // 触发状态变化
  }
}

/// 书架页面滚动控制Provider
final bookshelfScrollControlProvider = NotifierProvider<ScrollControlNotifier, int>(() {
  return ScrollControlNotifier();
});

/// 发现页面滚动控制Provider
final exploreScrollControlProvider = NotifierProvider<ScrollControlNotifier, int>(() {
  return ScrollControlNotifier();
});

