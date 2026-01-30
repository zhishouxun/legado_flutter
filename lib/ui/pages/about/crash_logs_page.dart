import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import '../../../services/crash_log_service.dart';
import 'crash_log_item.dart';

/// 崩溃日志查看页面
class CrashLogsPage extends StatefulWidget {
  const CrashLogsPage({super.key});

  @override
  State<CrashLogsPage> createState() => _CrashLogsPageState();
}

class _CrashLogsPageState extends State<CrashLogsPage> {
  List<File> _crashLogFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCrashLogs();
  }

  Future<void> _loadCrashLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await CrashLogService.instance.getCrashLogFiles();
      if (mounted) {
        setState(() {
          _crashLogFiles = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载崩溃日志失败: $e')),
        );
      }
    }
  }

  Future<void> _showCrashLogDetail(File file) async {
    final content = await CrashLogService.instance.readCrashLogFile(file);
    if (content == null || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(path.basename(file.path)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              }
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () async {
              await Share.share(
                content,
                subject: path.basename(file.path),
              );
            },
            child: const Text('分享'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllCrashLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有崩溃日志吗？此操作不可恢复。'),
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

    final success = await CrashLogService.instance.clearAllCrashLogs();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('崩溃日志已清除')),
        );
        _loadCrashLogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('清除崩溃日志失败')),
        );
      }
    }
  }

  Future<void> _deleteCrashLog(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${path.basename(file.path)} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await CrashLogService.instance.deleteCrashLogFile(file);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('崩溃日志已删除')),
        );
        _loadCrashLogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除崩溃日志失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('崩溃日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCrashLogs,
            tooltip: '刷新',
          ),
          if (_crashLogFiles.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _clearAllCrashLogs();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 8),
                      Text('清除所有'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _crashLogFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bug_report_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无崩溃日志',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCrashLogs,
                  child: ListView.builder(
                    itemCount: _crashLogFiles.length,
                    itemBuilder: (context, index) {
                      final file = _crashLogFiles[index];
                      return CrashLogItem(
                        file: file,
                        onTap: () => _showCrashLogDetail(file),
                        onDelete: () => _deleteCrashLog(file),
                      );
                    },
                  ),
                ),
    );
  }
}

