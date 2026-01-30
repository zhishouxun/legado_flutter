import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;
import 'app_log_page.dart';
import 'crash_logs_page.dart';
import 'markdown_viewer_page.dart';
import '../help/help_page.dart';
import '../../../services/update/app_update_github.dart';
import '../../../services/about/log_save_service.dart';
import '../../../services/about/heap_dump_service.dart';
import '../../../config/app_config.dart';
import '../../../utils/app_log.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../dialogs/update_dialog.dart';

/// 关于页面
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _appName = 'Legado Flutter';
  String _version = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appName = packageInfo.appName;
        _version = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline),
            onPressed: () {
              _openAppStore();
            },
            tooltip: '评分',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(
                'Legado Flutter - 一个免费开源的小说阅读器',
                subject: _appName,
              );
            },
            tooltip: '分享',
          ),
        ],
      ),
      body: ListView(
        children: [
          // 应用信息卡片
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 应用图标
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.book,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // 应用名称
                Text(
                  _appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                // 版本信息
                Text(
                  '版本 $_version (Build $_buildNumber)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 16),
                // 应用描述
                Text(
                  '一个免费开源的小说阅读器\nLegado (开源阅读) Flutter 版本',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          // 链接和相关信息
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('开源地址'),
            subtitle: const Text('GitHub'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _launchURL('https://github.com/legado-flutter/legado_flutter');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('使用说明'),
            subtitle: const Text('查看使用帮助'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HelpPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('问题反馈'),
            subtitle: const Text('报告Bug或提出建议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _launchURL(
                  'https://github.com/legado-flutter/legado_flutter/issues');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('应用日志'),
            subtitle: const Text('查看应用运行日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AppLogPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('崩溃日志'),
            subtitle: const Text('查看应用崩溃记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CrashLogsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('保存日志'),
            subtitle: const Text('保存日志到备份目录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _saveLogs();
            },
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('创建堆转储'),
            subtitle: const Text('创建内存堆转储文件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _createHeapDump();
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: Text('当前版本: $_version'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _checkUpdate();
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('更新日志'),
            subtitle: Text('版本 $_version'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MarkdownViewerPage(
                    title: '更新日志',
                    assetPath: 'assets/updateLog.md',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('许可证'),
            subtitle: const Text('查看开源许可证'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MarkdownViewerPage(
                    title: '许可证',
                    assetPath: 'assets/LICENSE.md',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('免责声明'),
            subtitle: const Text('查看免责声明'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MarkdownViewerPage(
                    title: '免责声明',
                    assetPath: 'assets/disclaimer.md',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('隐私政策'),
            subtitle: const Text('查看隐私政策'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MarkdownViewerPage(
                    title: '隐私政策',
                    assetPath: 'assets/privacyPolicy.md',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('加入QQ群'),
            subtitle: const Text('加入官方QQ群'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _joinQQGroup();
            },
          ),
          const Divider(),
          // 版权信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Copyright © 2024',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Legado Flutter',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '基于 Legado (开源阅读) 项目',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接: $url')),
        );
      }
    }
  }

  /// 检查更新
  /// 参考项目：AboutFragment.checkUpdate()
  Future<void> _checkUpdate() async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在检查更新...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 使用GitHub更新服务检查更新
      final updateService = AppUpdateGitHub.instance;
      final coroutine = updateService.check();

      final updateInfo = await coroutine.future;

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      // 显示更新对话框
      showDialog(
        context: context,
        builder: (context) => UpdateDialog(updateInfo: updateInfo),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      String errorMessage;
      if (e is NoStackTraceException) {
        errorMessage = e.message;
      } else {
        errorMessage = '检查更新失败: $e';
        AppLog.instance.put('检查更新失败', error: e);
      }

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 保存日志
  /// 参考项目：AboutFragment.saveLog()
  Future<void> _saveLogs() async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在保存日志...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await LogSaveService.instance.saveLogs();

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('日志已保存至备份目录'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      String errorMessage;
      if (e is NoStackTraceException) {
        errorMessage = e.message;
      } else {
        errorMessage = '保存日志失败: $e';
        AppLog.instance.put('保存日志失败', error: e);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 创建堆转储
  /// 参考项目：AboutFragment.createHeapDump()
  Future<void> _createHeapDump() async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在创建堆转储...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await HeapDumpService.instance.createHeapDump();

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('堆转储已保存至备份目录'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      String errorMessage;
      if (e is NoStackTraceException) {
        errorMessage = e.message;
      } else {
        errorMessage = '创建堆转储失败: $e';
        AppLog.instance.put('创建堆转储失败', error: e);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 加入QQ群
  /// 参考项目：AboutFragment.joinQQGroup()
  Future<void> _joinQQGroup() async {
    try {
      // QQ群号（需要根据实际情况配置）
      // 可以通过AppConfig配置，这里使用示例群号
      final qqGroupKey = AppConfig.getString('qq_group_key', defaultValue: '');

      if (qqGroupKey.isNotEmpty) {
        // 构建QQ群URL
        final qqUrl =
            'mqqopensdkapi://bizAgent/qm/qr?url=http%3A%2F%2Fqm.qq.com%2Fcgi-bin%2Fqm%2Fqr%3Ffrom%3Dapp%26p%3Dandroid%26k%3D$qqGroupKey';
        final uri = Uri.parse(qqUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法打开QQ，请手动添加QQ群')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QQ群号未配置')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入QQ群失败: $e')),
        );
      }
    }
  }

  /// 打开应用商店评分页面
  Future<void> _openAppStore() async {
    try {
      String url;
      if (Platform.isAndroid) {
        // Android: 打开 Google Play Store
        // 注意：需要替换为实际的应用包名
        final packageName = 'com.legado.flutter'; // 需要根据实际包名修改
        url = 'https://play.google.com/store/apps/details?id=$packageName';
      } else if (Platform.isIOS) {
        // iOS: 打开 App Store
        // 注意：需要替换为实际的应用ID
        final appId = '1234567890'; // 需要根据实际App ID修改
        url = 'https://apps.apple.com/app/id$appId';
      } else {
        // 其他平台：显示提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前平台不支持应用商店评分')),
          );
        }
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开应用商店')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开应用商店失败: $e')),
        );
      }
    }
  }
}
