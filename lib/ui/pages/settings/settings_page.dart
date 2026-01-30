import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../providers/bookshelf_layout_provider.dart';
import '../book_source/book_source_manage_page.dart';
import '../replace_rule/replace_rule_manage_page.dart';
import '../about/about_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题模式'),
            subtitle: Text(_getThemeModeText(themeMode)),
            onTap: () {
              _showThemeModeDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.grid_view),
            title: const Text('书架布局'),
            subtitle: Text(_getLayoutText(ref.watch(bookshelfLayoutProvider))),
            onTap: () {
              _showLayoutDialog(context, ref);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('书源管理'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BookSourceManagePage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.rule),
            title: const Text('替换规则'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ReplaceRuleManagePage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AboutPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  void _showThemeModeDialog(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.read(themeModeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('浅色'),
              value: ThemeMode.light,
              groupValue: currentThemeMode,
              onChanged: (value) {
                if (value != null) {
                  setThemeMode(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('深色'),
              value: ThemeMode.dark,
              groupValue: currentThemeMode,
              onChanged: (value) {
                if (value != null) {
                  setThemeMode(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('跟随系统'),
              value: ThemeMode.system,
              groupValue: currentThemeMode,
              onChanged: (value) {
                if (value != null) {
                  setThemeMode(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getLayoutText(BookshelfLayoutType layout) {
    switch (layout) {
      case BookshelfLayoutType.list:
        return '列表布局';
      case BookshelfLayoutType.grid2:
        return '网格布局 - 2列';
      case BookshelfLayoutType.grid3:
        return '网格布局 - 3列';
      case BookshelfLayoutType.grid4:
        return '网格布局 - 4列';
      case BookshelfLayoutType.grid5:
        return '网格布局 - 5列';
      case BookshelfLayoutType.grid6:
        return '网格布局 - 6列';
    }
  }

  void _showLayoutDialog(BuildContext context, WidgetRef ref) {
    final currentLayout = ref.read(bookshelfLayoutProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('书架布局'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<BookshelfLayoutType>(
              title: const Text('列表布局'),
              subtitle: const Text('单列列表，显示详细信息'),
              value: BookshelfLayoutType.list,
              groupValue: currentLayout,
              onChanged: (value) {
                if (value != null) {
                  setBookshelfLayout(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<BookshelfLayoutType>(
              title: const Text('网格布局 - 2列'),
              subtitle: const Text('2列网格，紧凑显示'),
              value: BookshelfLayoutType.grid2,
              groupValue: currentLayout,
              onChanged: (value) {
                if (value != null) {
                  setBookshelfLayout(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<BookshelfLayoutType>(
              title: const Text('网格布局 - 3列'),
              subtitle: const Text('3列网格，平衡显示'),
              value: BookshelfLayoutType.grid3,
              groupValue: currentLayout,
              onChanged: (value) {
                if (value != null) {
                  setBookshelfLayout(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<BookshelfLayoutType>(
              title: const Text('网格布局 - 4列'),
              subtitle: const Text('4列网格，密集显示'),
              value: BookshelfLayoutType.grid4,
              groupValue: currentLayout,
              onChanged: (value) {
                if (value != null) {
                  setBookshelfLayout(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<BookshelfLayoutType>(
              title: const Text('网格布局 - 5列'),
              subtitle: const Text('5列网格，最密集显示'),
              value: BookshelfLayoutType.grid5,
              groupValue: currentLayout,
              onChanged: (value) {
                if (value != null) {
                  setBookshelfLayout(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<BookshelfLayoutType>(
              title: const Text('网格布局 - 6列'),
              subtitle: const Text('6列网格，超密集显示'),
              value: BookshelfLayoutType.grid6,
              groupValue: currentLayout,
              onChanged: (value) {
                if (value != null) {
                  setBookshelfLayout(ref, value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
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
}

