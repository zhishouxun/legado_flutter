import 'package:flutter/material.dart';
import '../../../services/source/check_source_service.dart';

/// 书源校验结果页面
class CheckSourceResultPage extends StatefulWidget {
  final List<CheckSourceResult> results;

  const CheckSourceResultPage({
    super.key,
    required this.results,
  });

  @override
  State<CheckSourceResultPage> createState() => _CheckSourceResultPageState();
}

class _CheckSourceResultPageState extends State<CheckSourceResultPage> {
  String _filter = 'all'; // all, success, failed
  String _sortBy = 'name'; // name, respondTime, success

  List<CheckSourceResult> get _filteredResults {
    var results = widget.results;

    // 过滤
    if (_filter == 'success') {
      results = results.where((r) => r.success).toList();
    } else if (_filter == 'failed') {
      results = results.where((r) => !r.success).toList();
    }

    // 排序
    results.sort((a, b) {
      switch (_sortBy) {
        case 'respondTime':
          return b.respondTime.compareTo(a.respondTime);
        case 'success':
          return b.success.toString().compareTo(a.success.toString());
        case 'name':
        default:
          return a.sourceName.compareTo(b.sourceName);
      }
    });

    return results;
  }

  Map<String, dynamic> get _statistics {
    final total = widget.results.length;
    final success = widget.results.where((r) => r.success).length;
    final failed = total - success;
    final avgRespondTime = total > 0
        ? widget.results.map((r) => r.respondTime).reduce((a, b) => a + b) ~/ total
        : 0;

    return {
      'total': total,
      'success': success,
      'failed': failed,
      'avgRespondTime': avgRespondTime,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _statistics;
    final filteredResults = _filteredResults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('校验结果'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'name',
                child: Text('按名称排序'),
              ),
              const PopupMenuItem(
                value: 'respondTime',
                child: Text('按响应时间排序'),
              ),
              const PopupMenuItem(
                value: 'success',
                child: Text('按成功状态排序'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计信息
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('总数', stats['total'].toString(), Colors.blue),
                    _buildStatItem('成功', stats['success'].toString(), Colors.green),
                    _buildStatItem('失败', stats['failed'].toString(), Colors.red),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '平均响应时间: ${stats['avgRespondTime']}ms',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 过滤按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('全部')),
                      ButtonSegment(value: 'success', label: Text('成功')),
                      ButtonSegment(value: 'failed', label: Text('失败')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _filter = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 结果列表
          Expanded(
            child: filteredResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '没有符合条件的书源',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredResults.length,
                    itemBuilder: (context, index) {
                      final result = filteredResults[index];
                      return _buildResultItem(result);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildResultItem(CheckSourceResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: Icon(
          result.success ? Icons.check_circle : Icons.cancel,
          color: result.success ? Colors.green : Colors.red,
        ),
        title: Text(
          result.sourceName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: result.success ? null : Colors.red,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              result.sourceUrl,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '响应时间: ${result.respondTime}ms',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Text(
                  result.success ? '✓ 成功' : '✗ 失败',
                  style: TextStyle(
                    fontSize: 12,
                    color: result.success ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 校验项结果
                const Text(
                  '校验项:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...result.checkItems.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          entry.value ? Icons.check : Icons.close,
                          size: 16,
                          color: entry.value ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 14,
                            color: entry.value ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                
                // 错误信息
                if (result.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '错误信息:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      result.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
                
                // 校验摘要
                const SizedBox(height: 16),
                Text(
                  '摘要: ${result.getSummary()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

