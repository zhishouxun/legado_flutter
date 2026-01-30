import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/bookshelf_settings_provider.dart';
import '../../../providers/bookshelf_layout_provider.dart';
import '../../../services/book/book_service.dart';
import '../../widgets/common/custom_switch_list_tile.dart';

/// 书架布局设置页面
class BookshelfLayoutSettingsPage extends ConsumerStatefulWidget {
  const BookshelfLayoutSettingsPage({super.key});

  @override
  ConsumerState<BookshelfLayoutSettingsPage> createState() =>
      _BookshelfLayoutSettingsPageState();
}

class _BookshelfLayoutSettingsPageState
    extends ConsumerState<BookshelfLayoutSettingsPage> {
  late BookshelfSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(bookshelfSettingsProvider);
  }

  void _updateSettings(BookshelfSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
  }

  void _onConfirm() {
    final notifier = ref.read(bookshelfSettingsProvider.notifier);

    // 应用所有设置
    if (_settings.layoutType != ref.read(bookshelfLayoutProvider)) {
      notifier.updateLayoutType(_settings.layoutType);
    }
    notifier.updateGroupingStyle(_settings.groupingStyle);
    notifier.updateSortType(_settings.sortType);
    notifier.updateShowUnreadMark(_settings.showUnreadMark);
    notifier.updateShowLastUpdateTime(_settings.showLastUpdateTime);
    notifier.updateShowPendingUpdateCount(_settings.showPendingUpdateCount);
    notifier.updateShowQuickScrollBar(_settings.showQuickScrollBar);
    notifier.updateSelectedTag(_settings.selectedTag);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架布局'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分组样式
            _buildSectionTitle('分组样式'),
            _buildGroupingStyleSection(),

            const Divider(height: 1),

            // 显示选项
            _buildSectionTitle('显示选项'),
            _buildSwitchTile(
              title: '显示未读标志',
              value: _settings.showUnreadMark,
              onChanged: (value) {
                _updateSettings(_settings.copyWith(showUnreadMark: value));
              },
              primaryColor: primaryColor,
            ),
            _buildSwitchTile(
              title: '显示上次更新时间',
              value: _settings.showLastUpdateTime,
              onChanged: (value) {
                _updateSettings(_settings.copyWith(showLastUpdateTime: value));
              },
              primaryColor: primaryColor,
            ),
            _buildSwitchTile(
              title: '显示等待更新数量',
              value: _settings.showPendingUpdateCount,
              onChanged: (value) {
                _updateSettings(
                    _settings.copyWith(showPendingUpdateCount: value));
              },
              primaryColor: primaryColor,
            ),
            _buildSwitchTile(
              title: '显示快速滚动条',
              value: _settings.showQuickScrollBar,
              onChanged: (value) {
                _updateSettings(_settings.copyWith(showQuickScrollBar: value));
              },
              primaryColor: primaryColor,
            ),

            // 标签
            _buildSectionTitle('标签'),
            _buildTagSection(),

            const Divider(height: 1),

            // 视图选项
            _buildSectionTitle('视图'),
            _buildViewOptions(primaryColor),

            const Divider(height: 1),

            // 排序选项
            _buildSectionTitle('排序'),
            _buildSortOptions(primaryColor),

            const SizedBox(height: 80), // 为底部按钮留出空间
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: isDark ? Colors.brown[300] : Colors.brown[700],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _onConfirm,
                child: Text(
                  '确定',
                  style: TextStyle(
                    color: isDark ? Colors.brown[300] : Colors.brown[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGroupingStyleSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('分组样式'),
          const Spacer(),
          GestureDetector(
            onTap: () {
              _showGroupingStyleDialog();
            },
            child: Text(
              _getGroupingStyleText(_settings.groupingStyle),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupingStyleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择分组样式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: GroupingStyle.values.map((style) {
            return RadioListTile<GroupingStyle>(
              title: Text(_getGroupingStyleText(style)),
              value: style,
              groupValue: _settings.groupingStyle,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings.copyWith(groupingStyle: value);
                  });
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  String _getGroupingStyleText(GroupingStyle style) {
    switch (style) {
      case GroupingStyle.none:
        return '不分组';
      case GroupingStyle.byTag:
        return '按标签';
      case GroupingStyle.byAuthor:
        return '按作者';
    }
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color primaryColor,
  }) {
    return CustomSwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildTagSection() {
    return InkWell(
      onTap: () => _showTagSelectorDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Text('标签'),
            const Spacer(),
            Text(
              _settings.selectedTag ?? '全部',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  /// 显示标签选择对话框
  Future<void> _showTagSelectorDialog() async {
    // 获取所有书籍的标签
    final allBooks = await BookService.instance.getBookshelfBooks();
    final tags = <String>{};
    for (final book in allBooks) {
      if (book.customTag != null && book.customTag!.isNotEmpty) {
        tags.add(book.customTag!);
      }
    }
    final tagList = tags.toList()..sort();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择标签'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 全部选项
                RadioListTile<String?>(
                  title: const Text('全部'),
                  value: null,
                  groupValue: _settings.selectedTag,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(selectedTag: value);
                    });
                    Navigator.pop(context);
                  },
                ),
                // 标签列表
                ...tagList.map((tag) {
                  return RadioListTile<String?>(
                    title: Text(tag),
                    value: tag,
                    groupValue: _settings.selectedTag,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(selectedTag: value);
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewOptions(Color primaryColor) {
    return Column(
      children: [
        _buildRadioTile(
          title: '列表',
          value: BookshelfLayoutType.list,
          groupValue: _settings.layoutType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(layoutType: value));
            }
          },
          primaryColor: primaryColor,
        ),
        _buildRadioTile(
          title: '网格三列',
          value: BookshelfLayoutType.grid3,
          groupValue: _settings.layoutType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(layoutType: value));
            }
          },
          primaryColor: primaryColor,
        ),
        _buildRadioTile(
          title: '网格四列',
          value: BookshelfLayoutType.grid4,
          groupValue: _settings.layoutType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(layoutType: value));
            }
          },
          primaryColor: primaryColor,
        ),
        _buildRadioTile(
          title: '网格五列',
          value: BookshelfLayoutType.grid5,
          groupValue: _settings.layoutType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(layoutType: value));
            }
          },
          primaryColor: primaryColor,
        ),
        _buildRadioTile(
          title: '网格六列',
          value: BookshelfLayoutType.grid6,
          groupValue: _settings.layoutType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(layoutType: value));
            }
          },
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildSortOptions(Color primaryColor) {
    return Column(
      children: [
        _buildRadioTile(
          title: '按阅读时间',
          value: SortType.byReadTime,
          groupValue: _settings.sortType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(sortType: value));
            }
          },
          primaryColor: primaryColor,
        ),
        _buildRadioTile(
          title: '按更新时间',
          value: SortType.byUpdateTime,
          groupValue: _settings.sortType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(sortType: value));
            }
          },
          primaryColor: primaryColor,
        ),
        _buildRadioTile(
          title: '按书名',
          value: SortType.byBookName,
          groupValue: _settings.sortType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(sortType: value));
            }
          },
          primaryColor: primaryColor,
        ),
        _buildRadioTile(
          title: '手动排序',
          value: SortType.manual,
          groupValue: _settings.sortType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(sortType: value));
            }
          },
          primaryColor: primaryColor,
        ),
        _buildRadioTile(
          title: '综合排序',
          value: SortType.comprehensive,
          groupValue: _settings.sortType,
          onChanged: (value) {
            if (value != null) {
              _updateSettings(_settings.copyWith(sortType: value));
            }
          },
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildRadioTile<T>({
    required String title,
    required T value,
    required T? groupValue,
    required ValueChanged<T?> onChanged,
    required Color primaryColor,
  }) {
    return RadioListTile<T>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: primaryColor,
      dense: true,
    );
  }
}
