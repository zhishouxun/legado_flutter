import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

/// 书架布局类型
enum BookshelfLayoutType {
  list,    // 列表布局
  grid2,   // 2列网格
  grid3,   // 3列网格
  grid4,   // 4列网格
  grid5,   // 5列网格
  grid6,   // 6列网格
}

/// 书架布局Provider
final bookshelfLayoutProvider = Provider<BookshelfLayoutType>((ref) {
  return _loadLayout();
});

/// 加载布局配置
BookshelfLayoutType _loadLayout() {
  final layout = AppConfig.getBookshelfLayout();
  switch (layout) {
    case 0:
      return BookshelfLayoutType.list;
    case 1:
      return BookshelfLayoutType.grid2;
    case 2:
      return BookshelfLayoutType.grid3;
    case 3:
      return BookshelfLayoutType.grid4;
    case 4:
      return BookshelfLayoutType.grid5;
    case 5:
      return BookshelfLayoutType.grid6;
    default:
      return BookshelfLayoutType.list;
  }
}

/// 设置布局
void setBookshelfLayout(WidgetRef ref, BookshelfLayoutType layout) {
  final layoutValue = switch (layout) {
    BookshelfLayoutType.list => 0,
    BookshelfLayoutType.grid2 => 1,
    BookshelfLayoutType.grid3 => 2,
    BookshelfLayoutType.grid4 => 3,
    BookshelfLayoutType.grid5 => 4,
    BookshelfLayoutType.grid6 => 5,
  };
  AppConfig.setBookshelfLayout(layoutValue);
  // 刷新provider
  ref.invalidate(bookshelfLayoutProvider);
}

/// 获取网格列数
int getGridCrossAxisCount(BookshelfLayoutType layout) {
  return switch (layout) {
    BookshelfLayoutType.list => 1,
    BookshelfLayoutType.grid2 => 2,
    BookshelfLayoutType.grid3 => 3,
    BookshelfLayoutType.grid4 => 4,
    BookshelfLayoutType.grid5 => 5,
    BookshelfLayoutType.grid6 => 6,
  };
}

/// 是否为列表布局
bool isListLayout(BookshelfLayoutType layout) {
  return layout == BookshelfLayoutType.list;
}

