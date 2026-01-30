import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/app_log.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 日志对话框
class LogDialog extends BaseBottomSheetStateful {
  const LogDialog({super.key}) : super(
          title: '应用日志',
          heightFactor: 0.8,
        );

  @override
  State<LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends BaseBottomSheetState<LogDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // 监听日志变化
    AppLog.instance.logsNotifier.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    AppLog.instance.logsNotifier.removeListener(_onLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (mounted) {
      setState(() {});
      if (_autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 操作按钮栏
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  _autoScroll ? Icons.arrow_downward : Icons.arrow_upward,
                ),
                onPressed: () {
                  setState(() {
                    _autoScroll = !_autoScroll;
                  });
                  if (_autoScroll && _scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                tooltip: _autoScroll ? '自动滚动' : '停止滚动',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {});
                },
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        // 日志列表
        Expanded(
          child: AppLog.instance.logs.isEmpty
              ? const Center(child: Text('暂无日志'))
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true, // 从底部开始显示
                  padding: const EdgeInsets.all(8),
                  itemCount: AppLog.instance.logs.length,
                  itemBuilder: (context, index) {
                    final log = AppLog.instance.logs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(
                        '${log.formattedTime} - ${log.fullMessage}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
        // 底部操作栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              TextButton.icon(
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清空'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('清空日志'),
                          content: const Text('确定要清空所有日志吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                AppLog.instance.clear();
                                setState(() {});
                                Navigator.pop(context);
                              },
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      );
                    },
              ),
              const Spacer(),
              TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('复制'),
                    onPressed: () {
                      final logs = AppLog.instance.logs;
                      if (logs.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('没有日志可复制')),
                        );
                        return;
                      }
                      final text = logs
                          .map((log) =>
                              '${log.formattedTime} - ${log.fullMessage}')
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板')),
                      );
                    },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
