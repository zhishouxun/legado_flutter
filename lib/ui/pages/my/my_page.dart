import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_config.dart';
import '../../../config/theme_config.dart';
import '../about/about_page.dart';
import '../bookmark/all_bookmark_page.dart';
import '../read_record/read_record_page.dart';
import '../book_source/book_source_manage_page.dart';
import '../txt_toc_rule/txt_toc_rule_manage_page.dart';
import '../dict_rule/dict_rule_manage_page.dart';
import '../replace_rule/replace_rule_manage_page.dart';
import '../backup/backup_restore_page.dart';
import '../theme/theme_settings_page.dart';
import '../file/file_manage_page.dart';
import '../settings/other_settings_page.dart';
import '../help/help_page.dart';
import '../cache/cache_manage_page.dart';
import '../../widgets/common/custom_switch_list_tile.dart';
import '../../../services/web/web_service_manager.dart';

/// 我的页面
class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final webServiceEnabled = ref.watch(webServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HelpPage(),
                ),
              );
            },
            tooltip: '帮助',
          ),
        ],
      ),
      body: ListView(
        children: [
          // 书源管理
          ListTile(
            leading: const Icon(Icons.source),
            title: const Text('书源管理'),
            subtitle: const Text('管理书源'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BookSourceManagePage(),
                ),
              );
            },
          ),
          // TXT目录规则
          ListTile(
            leading: const Icon(Icons.rule),
            title: const Text('TXT目录规则'),
            subtitle: const Text('配置TXT目录规则'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TxtTocRuleManagePage(),
                ),
              );
            },
          ),
          // 替换规则
          ListTile(
            leading: const Icon(Icons.find_replace),
            title: const Text('替换规则'),
            subtitle: const Text('净化替换规则'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ReplaceRuleManagePage(),
                ),
              );
            },
          ),
          // 字典规则
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('字典规则'),
            subtitle: const Text('配置字典规则'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DictRuleManagePage(),
                ),
              );
            },
          ),
          // 主题模式
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题模式'),
            subtitle: Text(_getThemeModeText(themeMode)),
            onTap: () {
              _showThemeModeDialog(context, ref);
            },
          ),
          // Web服务
          GestureDetector(
            onLongPress: webServiceEnabled
                ? () => _showWebServiceMenu(context, ref)
                : null,
            child: CustomSwitchListTile(
              secondary: const Icon(Icons.web),
              title: const Text('Web服务'),
              subtitle: _buildWebServiceSubtitle(ref, webServiceEnabled),
              value: webServiceEnabled,
              onChanged: (value) async {
                await ref
                    .read(webServiceProvider.notifier)
                    .setWebService(value);
              },
            ),
          ),
          const Divider(),
          // 设置分类标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '设置',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          // 备份恢复/WebDAV设置
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份恢复'),
            subtitle: const Text('WebDAV设置'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupRestorePage(),
                ),
              );
            },
          ),
          // 主题设置
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('主题设置'),
            subtitle: const Text('自定义主题'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ThemeSettingsPage(),
                ),
              );
            },
          ),
          // 其他设置
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('其他设置'),
            subtitle: const Text('更多设置选项'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OtherSettingsPage(),
                ),
              );
            },
          ),
          const Divider(),
          // 其他分类标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '其他',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          // 书签
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text('书签'),
            subtitle: const Text('所有书签'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AllBookmarkPage(),
                ),
              );
            },
          ),
          // 阅读记录
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('阅读记录'),
            subtitle: const Text('阅读历史记录'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ReadRecordPage(),
                ),
              );
            },
          ),
          // 缓存管理
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('缓存管理'),
            subtitle: const Text('管理书籍缓存'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CacheManagePage(),
                ),
              );
            },
          ),
          // 文件管理
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('文件管理'),
            subtitle: const Text('管理文件'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FileManagePage(),
                ),
              );
            },
          ),
          // 关于
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
          // 退出（仅在某些平台显示）
          if (Theme.of(context).platform == TargetPlatform.android ||
              Theme.of(context).platform == TargetPlatform.iOS)
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('退出'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('退出应用'),
                    content: const Text('确定要退出应用吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // 退出应用
                          SystemNavigator.pop();
                        },
                        child: const Text('退出'),
                      ),
                    ],
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

  /// 构建Web服务副标题
  Widget _buildWebServiceSubtitle(WidgetRef ref, bool enabled) {
    if (!enabled) {
      return const Text('开启Web服务');
    }

    final manager = WebServiceManager.instance;
    if (manager.isRunning && manager.hostAddress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Web服务已开启'),
          Text(
            manager.hostAddress!,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      );
    }
    return const Text('Web服务已开启');
  }

  /// 显示Web服务操作菜单
  void _showWebServiceMenu(BuildContext context, WidgetRef ref) {
    final manager = WebServiceManager.instance;
    if (!manager.isRunning || manager.hostAddress == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制地址'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: manager.hostAddress!));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('地址已复制到剪贴板')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('浏览器打开'),
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse(manager.hostAddress!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('无法打开链接: ${manager.hostAddress}')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
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
}

/// Web服务Provider
final webServiceProvider = NotifierProvider<WebServiceNotifier, bool>(() {
  return WebServiceNotifier();
});

/// Web服务Notifier
class WebServiceNotifier extends Notifier<bool> {
  @override
  bool build() {
    return AppConfig.getWebService() ?? false;
  }

  Future<void> setWebService(bool value) async {
    await AppConfig.setWebService(value);
    state = value;

    // 启动/停止Web服务
    if (value) {
      final success = await WebServiceManager.instance.start();
      if (!success) {
        // 如果启动失败，恢复状态
        await AppConfig.setWebService(false);
        state = false;
      }
    } else {
      await WebServiceManager.instance.stop();
    }
  }
}
