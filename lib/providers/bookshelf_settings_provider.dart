import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import '../config/app_config.dart';
import 'bookshelf_layout_provider.dart';

/// 分组样式
enum GroupingStyle {
  none,      // 不分组
  byTag,     // 按标签分组
  byAuthor,  // 按作者分组
}

/// 排序方式
enum SortType {
  byReadTime,      // 按阅读时间
  byUpdateTime,    // 按更新时间
  byBookName,      // 按书名
  manual,          // 手动排序
  comprehensive,   // 综合排序
}

/// 书架布局设置
class BookshelfSettings {
  final BookshelfLayoutType layoutType;
  final GroupingStyle groupingStyle;
  final SortType sortType;
  final bool showUnreadMark;
  final bool showLastUpdateTime;
  final bool showPendingUpdateCount;
  final bool showQuickScrollBar;
  final String? selectedTag;

  BookshelfSettings({
    required this.layoutType,
    this.groupingStyle = GroupingStyle.none,
    this.sortType = SortType.byReadTime,
    this.showUnreadMark = true,
    this.showLastUpdateTime = false,
    this.showPendingUpdateCount = false,
    this.showQuickScrollBar = false,
    this.selectedTag,
  });

  BookshelfSettings copyWith({
    BookshelfLayoutType? layoutType,
    GroupingStyle? groupingStyle,
    SortType? sortType,
    bool? showUnreadMark,
    bool? showLastUpdateTime,
    bool? showPendingUpdateCount,
    bool? showQuickScrollBar,
    String? selectedTag,
  }) {
    return BookshelfSettings(
      layoutType: layoutType ?? this.layoutType,
      groupingStyle: groupingStyle ?? this.groupingStyle,
      sortType: sortType ?? this.sortType,
      showUnreadMark: showUnreadMark ?? this.showUnreadMark,
      showLastUpdateTime: showLastUpdateTime ?? this.showLastUpdateTime,
      showPendingUpdateCount: showPendingUpdateCount ?? this.showPendingUpdateCount,
      showQuickScrollBar: showQuickScrollBar ?? this.showQuickScrollBar,
      selectedTag: selectedTag ?? this.selectedTag,
    );
  }
}

/// 书架设置 Provider
final bookshelfSettingsProvider = NotifierProvider<BookshelfSettingsNotifier, BookshelfSettings>(() {
  return BookshelfSettingsNotifier();
});

class BookshelfSettingsNotifier extends Notifier<BookshelfSettings> {
  @override
  BookshelfSettings build() {
    final settings = _loadSettings();
    // 监听布局类型变化
    ref.listen<BookshelfLayoutType>(bookshelfLayoutProvider, (previous, next) {
      state = state.copyWith(layoutType: next);
    });
    return settings;
  }

  static BookshelfSettings _loadSettings() {
    final layoutType = _loadLayout();
    return BookshelfSettings(
      layoutType: layoutType,
      groupingStyle: _loadGroupingStyle(),
      sortType: _loadSortType(),
      showUnreadMark: AppConfig.getBool('bookshelf_show_unread_mark', defaultValue: true),
      showLastUpdateTime: AppConfig.getBool('bookshelf_show_last_update_time', defaultValue: false),
      showPendingUpdateCount: AppConfig.getBool('bookshelf_show_pending_update_count', defaultValue: false),
      showQuickScrollBar: AppConfig.getBool('bookshelf_show_quick_scroll_bar', defaultValue: false),
      selectedTag: AppConfig.getString('bookshelf_selected_tag'),
    );
  }

  static BookshelfLayoutType _loadLayout() {
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

  static GroupingStyle _loadGroupingStyle() {
    final value = AppConfig.getInt('bookshelf_grouping_style', defaultValue: 0);
    return GroupingStyle.values[value.clamp(0, GroupingStyle.values.length - 1)];
  }

  static SortType _loadSortType() {
    final value = AppConfig.getInt('bookshelf_sort_type', defaultValue: 0);
    return SortType.values[value.clamp(0, SortType.values.length - 1)];
  }

  void updateLayoutType(BookshelfLayoutType layoutType) {
    final layoutValue = switch (layoutType) {
      BookshelfLayoutType.list => 0,
      BookshelfLayoutType.grid2 => 1,
      BookshelfLayoutType.grid3 => 2,
      BookshelfLayoutType.grid4 => 3,
      BookshelfLayoutType.grid5 => 4,
      BookshelfLayoutType.grid6 => 5,
    };
    AppConfig.setBookshelfLayout(layoutValue);
    state = state.copyWith(layoutType: layoutType);
    ref.invalidate(bookshelfLayoutProvider);
  }

  void updateGroupingStyle(GroupingStyle style) {
    AppConfig.setInt('bookshelf_grouping_style', style.index);
    state = state.copyWith(groupingStyle: style);
  }

  void updateSortType(SortType sortType) {
    AppConfig.setInt('bookshelf_sort_type', sortType.index);
    state = state.copyWith(sortType: sortType);
  }

  void updateShowUnreadMark(bool value) {
    AppConfig.setBool('bookshelf_show_unread_mark', value);
    state = state.copyWith(showUnreadMark: value);
  }

  void updateShowLastUpdateTime(bool value) {
    AppConfig.setBool('bookshelf_show_last_update_time', value);
    state = state.copyWith(showLastUpdateTime: value);
  }

  void updateShowPendingUpdateCount(bool value) {
    AppConfig.setBool('bookshelf_show_pending_update_count', value);
    state = state.copyWith(showPendingUpdateCount: value);
  }

  void updateShowQuickScrollBar(bool value) {
    AppConfig.setBool('bookshelf_show_quick_scroll_bar', value);
    state = state.copyWith(showQuickScrollBar: value);
  }

  void updateSelectedTag(String? tag) {
    if (tag != null) {
      AppConfig.setString('bookshelf_selected_tag', tag);
    } else {
      AppConfig.remove('bookshelf_selected_tag');
    }
    state = state.copyWith(selectedTag: tag);
  }
}

