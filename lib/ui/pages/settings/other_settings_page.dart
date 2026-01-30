import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_config.dart';
import '../../../services/reader/cache_service.dart';
import '../../../utils/app_log.dart';
import '../../widgets/common/custom_switch_list_tile.dart';
import '../welcome/welcome_config_page.dart';
import '../config/cover_config_page.dart';

/// 其他设置页面
class OtherSettingsPage extends StatefulWidget {
  const OtherSettingsPage({super.key});

  @override
  State<OtherSettingsPage> createState() => _OtherSettingsPageState();
}

class _OtherSettingsPageState extends State<OtherSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('其他设置'),
      ),
      body: ListView(
        children: [
          // 网络设置
          _buildSectionTitle('网络设置'),
          _buildUserAgentSetting(),
          _buildPreDownloadNumSetting(),
          _buildThreadCountSetting(),
          _buildWebPortSetting(),
          const Divider(),

          // 缓存管理
          _buildSectionTitle('缓存管理'),
          _buildCacheSizeInfo(),
          _buildClearCacheSetting(),
          const Divider(),

          // 其他
          _buildSectionTitle('其他'),
          _buildRecordLogSetting(),
          _buildShowDiscoverySetting(),
          _buildShowRssSetting(),
          _buildWelcomeConfigSetting(),
          _buildCoverConfigSetting(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  /// User Agent设置
  Widget _buildUserAgentSetting() {
    // 使用 getUserAgentWithDefault() 获取 User-Agent（包括默认值）
    final userAgent = AppConfig.getUserAgentWithDefault();
    return ListTile(
      leading: const Icon(Icons.language),
      title: const Text('User Agent'),
      subtitle: Text(userAgent),
      onTap: () => _showUserAgentDialog(),
    );
  }

  /// 预下载数量设置
  Widget _buildPreDownloadNumSetting() {
    final preDownloadNum = AppConfig.getInt('pre_download_num', defaultValue: 0);
    return ListTile(
      leading: const Icon(Icons.download),
      title: const Text('预下载数量'),
      subtitle: Text('$preDownloadNum 章'),
      onTap: () => _showNumberPickerDialog(
        title: '预下载数量',
        currentValue: preDownloadNum,
        minValue: 0,
        maxValue: 9999,
        onChanged: (value) async {
          await AppConfig.setInt('pre_download_num', value);
          setState(() {});
        },
      ),
    );
  }

  /// 线程数设置
  Widget _buildThreadCountSetting() {
    final threadCount = AppConfig.getInt('thread_count', defaultValue: 10);
    return ListTile(
      leading: const Icon(Icons.speed),
      title: const Text('线程数'),
      subtitle: Text('$threadCount 个'),
      onTap: () => _showNumberPickerDialog(
        title: '线程数',
        currentValue: threadCount,
        minValue: 1,
        maxValue: 999,
        onChanged: (value) async {
          await AppConfig.setInt('thread_count', value);
          setState(() {});
        },
      ),
    );
  }

  /// Web端口设置
  Widget _buildWebPortSetting() {
    final webPort = AppConfig.getInt('web_port', defaultValue: 1122);
    return ListTile(
      leading: const Icon(Icons.web),
      title: const Text('Web服务端口'),
      subtitle: Text('$webPort'),
      onTap: () => _showNumberPickerDialog(
        title: 'Web服务端口',
        currentValue: webPort,
        minValue: 1024,
        maxValue: 60000,
        onChanged: (value) async {
          await AppConfig.setInt('web_port', value);
          setState(() {});
        },
      ),
    );
  }

  /// 缓存大小信息
  Widget _buildCacheSizeInfo() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getCacheInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            leading: Icon(Icons.storage),
            title: Text('缓存大小'),
            subtitle: Text('计算中...'),
          );
        }

        final info = snapshot.data!;
        final totalSize = info['totalSize'] as int;
        final fileCount = info['fileCount'] as int;

        return ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('缓存大小'),
          subtitle: Text('${_formatFileSize(totalSize)} • $fileCount 个文件'),
        );
      },
    );
  }

  /// 清除缓存设置
  Widget _buildClearCacheSetting() {
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: Colors.red),
      title: const Text('清除所有缓存', style: TextStyle(color: Colors.red)),
      subtitle: const Text('清除所有书籍的章节缓存'),
      onTap: () => _showClearCacheDialog(),
    );
  }

  /// 记录日志设置
  Widget _buildRecordLogSetting() {
    final recordLog = AppConfig.getBool('record_log', defaultValue: false);
    return CustomSwitchListTile(
      secondary: const Icon(Icons.bug_report),
      title: const Text('记录日志'),
      subtitle: const Text('开启后记录应用运行日志'),
      value: recordLog,
      onChanged: (value) async {
        await AppConfig.setBool('record_log', value);
        setState(() {});
      },
    );
  }

  /// 显示发现设置
  Widget _buildShowDiscoverySetting() {
    final showDiscovery = AppConfig.getBool('show_discovery', defaultValue: true);
    return CustomSwitchListTile(
      secondary: const Icon(Icons.explore),
      title: const Text('显示发现'),
      subtitle: const Text('在书架页面显示发现功能'),
      value: showDiscovery,
      onChanged: (value) async {
        await AppConfig.setBool('show_discovery', value);
        setState(() {});
      },
    );
  }

  /// 欢迎页配置设置
  Widget _buildWelcomeConfigSetting() {
    return ListTile(
      leading: const Icon(Icons.wb_sunny),
      title: const Text('欢迎页配置'),
      subtitle: const Text('自定义启动页样式'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const WelcomeConfigPage(),
          ),
        );
      },
    );
  }

  /// 显示RSS设置
  Widget _buildShowRssSetting() {
    final showRss = AppConfig.getBool('show_rss', defaultValue: true);
    return CustomSwitchListTile(
      secondary: const Icon(Icons.rss_feed),
      title: const Text('显示RSS'),
      subtitle: const Text('在书架页面显示RSS功能'),
      value: showRss,
      onChanged: (value) async {
        await AppConfig.setBool('show_rss', value);
        setState(() {});
      },
    );
  }

  /// 封面配置设置
  Widget _buildCoverConfigSetting() {
    return ListTile(
      leading: const Icon(Icons.image),
      title: const Text('封面配置'),
      subtitle: const Text('设置默认封面和显示选项'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CoverConfigPage(),
          ),
        );
      },
    );
  }

  /// 显示User Agent对话框
  Future<void> _showUserAgentDialog() async {
    // 使用 getUserAgentWithDefault() 显示默认值，而不是留空
    final defaultUserAgent = AppConfig.getUserAgentWithDefault();
    final customUserAgent = AppConfig.getString('user_agent', defaultValue: '');
    // 如果有自定义值，使用自定义值；否则显示默认值
    final initialValue = customUserAgent.isNotEmpty ? customUserAgent : defaultUserAgent;
    
    final controller = TextEditingController(text: initialValue);

    String? result;
    try {
      result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('User Agent'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '留空使用默认User Agent',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                // 如果输入的内容等于默认值，清空配置（使用默认值）
                if (text == defaultUserAgent) {
                  Navigator.of(context).pop('');
                } else {
                  Navigator.of(context).pop(text);
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } finally {
      // 确保在对话框关闭后清理 controller，避免 UndoHistoryState 断言失败
      controller.dispose();
    }

    if (result != null) {
      await AppConfig.setString('user_agent', result);
      setState(() {});
    }
  }

  /// 显示数字选择器对话框
  Future<void> _showNumberPickerDialog({
    required String title,
    required int currentValue,
    required int minValue,
    required int maxValue,
    required Function(int) onChanged,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());

    int? result;
    try {
      result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
          decoration: InputDecoration(
            labelText: '请输入 $minValue - $maxValue 之间的数字',
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= minValue && value <= maxValue) {
                Navigator.of(context).pop(value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入 $minValue - $maxValue 之间的数字')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    } finally {
      // 确保在对话框关闭后清理 controller，避免 UndoHistoryState 断言失败
      controller.dispose();
    }

    if (result != null) {
      onChanged(result);
    }
  }

  /// 显示清除缓存对话框
  Future<void> _showClearCacheDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await CacheService.instance.clearAllCache();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除')),
        );
        setState(() {}); // 刷新缓存大小显示
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('清除缓存失败')),
        );
      }
    } catch (e) {
      AppLog.instance.put('清除缓存失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除缓存失败: $e')),
        );
      }
    }
  }

  /// 获取缓存信息
  Future<Map<String, dynamic>> _getCacheInfo() async {
    try {
      final cacheDir = await CacheService.instance.getCacheDir();
      if (!await cacheDir.exists()) {
        return {'totalSize': 0, 'fileCount': 0};
      }

      int totalSize = 0;
      int fileCount = 0;

      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
            fileCount++;
          } catch (e) {
            // 跳过无法访问的文件
          }
        }
      }

      return {'totalSize': totalSize, 'fileCount': fileCount};
    } catch (e) {
      return {'totalSize': 0, 'fileCount': 0};
    }
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

