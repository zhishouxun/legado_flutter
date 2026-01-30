import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../utils/app_log.dart';
import 'app_log_item.dart';
import 'app_log_filter_widget.dart';

/// 应用日志查看页面
class AppLogPage extends StatefulWidget {
  const AppLogPage({super.key});

  @override
  State<AppLogPage> createState() => _AppLogPageState();
}

class _AppLogPageState extends State<AppLogPage> {
  List<LogEntry> _filteredLogs = [];
  String _searchQuery = '';
  LogLevel _filterLevel = LogLevel.all;
  bool _showErrorsOnly = false;

  @override
  void initState() {
    super.initState();
    _updateFilteredLogs();
    // 监听日志变化
    AppLog.instance.logsNotifier.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    AppLog.instance.logsNotifier.removeListener(_onLogsChanged);
    super.dispose();
  }

  void _onLogsChanged() {
    if (mounted) {
      setState(() {
        _updateFilteredLogs();
      });
    }
  }

  void _updateFilteredLogs() {
    var logs = AppLog.instance.logs;

    // 按错误筛选
    if (_showErrorsOnly) {
      logs = logs.where((log) => log.error != null).toList();
    }

    // 按级别筛选
    if (_filterLevel != LogLevel.all) {
      logs = logs.where((log) {
        if (_filterLevel == LogLevel.error) {
          return log.error != null;
        } else if (_filterLevel == LogLevel.warning) {
          return log.message.toLowerCase().contains('warning') ||
              log.message.toLowerCase().contains('警告');
        } else if (_filterLevel == LogLevel.info) {
          return log.error == null;
        }
        return true;
      }).toList();
    }

    // 按搜索关键词筛选
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      logs = logs.where((log) {
        return log.message.toLowerCase().contains(query) ||
            (log.error != null && log.error!.toLowerCase().contains(query));
      }).toList();
    }

    setState(() {
      _filteredLogs = logs;
    });
  }

  Future<void> _exportLogs() async {
    if (_filteredLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有日志可导出')),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('应用日志导出');
      buffer.writeln('导出时间: ${DateTime.now().toString()}');
      buffer.writeln('日志数量: ${_filteredLogs.length}');
      buffer.writeln('=' * 50);
      buffer.writeln();

      for (final log in _filteredLogs) {
        buffer.writeln('[${log.formattedTime}] ${log.message}');
        if (log.error != null) {
          buffer.writeln('错误: ${log.error}');
        }
        if (log.stackTrace != null) {
          buffer.writeln('堆栈: ${log.stackTrace}');
        }
        buffer.writeln('-' * 50);
      }

      await Share.share(
        buffer.toString(),
        subject: '应用日志',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _copyLogs() async {
    if (_filteredLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有日志可复制')),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      for (final log in _filteredLogs) {
        buffer.writeln('[${log.formattedTime}] ${log.message}');
        if (log.error != null) {
          buffer.writeln('错误: ${log.error}');
        }
        if (log.stackTrace != null) {
          buffer.writeln('堆栈: ${log.stackTrace}');
        }
        buffer.writeln();
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已复制到剪贴板')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('复制失败: $e')),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有日志吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      AppLog.instance.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已清除')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: '复制日志',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportLogs,
            tooltip: '导出日志',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearLogs();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 8),
                    Text('清除日志'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选和搜索栏
          AppLogFilterWidget(
            searchQuery: _searchQuery,
            filterLevel: _filterLevel,
            showErrorsOnly: _showErrorsOnly,
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
                _updateFilteredLogs();
              });
            },
            onFilterLevelChanged: (level) {
              setState(() {
                _filterLevel = level;
                _updateFilteredLogs();
              });
            },
            onShowErrorsOnlyChanged: (value) {
              setState(() {
                _showErrorsOnly = value;
                _updateFilteredLogs();
              });
            },
          ),
          const Divider(height: 1),
          // 日志列表
          Expanded(
            child: _filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _filterLevel != LogLevel.all || _showErrorsOnly
                              ? '没有匹配的日志'
                              : '暂无日志',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[index];
                      return AppLogItem(
                        log: log,
                        onTap: () {
                          _showLogDetail(log);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showLogDetail(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('日志详情'),
        content: SingleChildScrollView(
          child: SelectableText(
            log.fullMessage,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: log.fullMessage));
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 日志级别
enum LogLevel {
  all,
  info,
  warning,
  error,
}

