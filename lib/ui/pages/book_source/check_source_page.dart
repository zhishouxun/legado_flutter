import 'package:flutter/material.dart';
import '../../../data/models/book_source.dart';
import '../../../services/source/book_source_service.dart';
import '../../../services/source/check_source_service.dart';
import '../../../utils/app_log.dart';
import 'check_source_result_page.dart';
import '../config/check_source_config_dialog.dart';

/// 书源批量校验页面
class CheckSourcePage extends StatefulWidget {
  final List<BookSource>? initialSources;

  const CheckSourcePage({
    super.key,
    this.initialSources,
  });

  @override
  State<CheckSourcePage> createState() => _CheckSourcePageState();
}

class _CheckSourcePageState extends State<CheckSourcePage> {
  final CheckSourceService _checkService = CheckSourceService.instance;
  
  List<BookSource> _sources = [];
  Set<String> _selectedUrls = {};
  bool _isChecking = false;
  bool _isPaused = false;
  int _currentIndex = 0;
  int _totalCount = 0;
  CheckSourceResult? _currentResult;

  @override
  void initState() {
    super.initState();
    _initService();
    _loadSources();
  }

  Future<void> _initService() async {
    try {
      await _checkService.init();
    } catch (e) {
      AppLog.instance.put('初始化校验服务失败', error: e);
    }
  }

  Future<void> _loadSources() async {
    try {
      if (widget.initialSources != null) {
        _sources = widget.initialSources!;
      } else {
        _sources = await BookSourceService.instance.getAllBookSources();
      }
      
      // 默认全选
      _selectedUrls = _sources.map((s) => s.bookSourceUrl).toSet();
      
      setState(() {});
    } catch (e) {
      AppLog.instance.put('加载书源列表失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _startCheck() async {
    if (_selectedUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个书源')),
      );
      return;
    }

    final selectedSources = _sources
        .where((s) => _selectedUrls.contains(s.bookSourceUrl))
        .toList();

    setState(() {
      _isChecking = true;
      _isPaused = false;
      _currentIndex = 0;
      _totalCount = selectedSources.length;
      _currentResult = null;
    });

    // 设置回调
    _checkService.onProgress = (current, total, result) {
      if (mounted) {
        setState(() {
          _currentIndex = current;
          _totalCount = total;
          _currentResult = result;
        });
      }
    };

    _checkService.onComplete = (results) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isPaused = false;
        });

        // 显示结果页面
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CheckSourceResultPage(results: results),
          ),
        );
      }
    };

    try {
      await _checkService.startCheck(selectedSources);
    } catch (e) {
      AppLog.instance.put('批量校验失败', error: e);
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isPaused = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('校验失败: $e')),
        );
      }
    }
  }

  void _pauseCheck() {
    _checkService.pause();
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeCheck() {
    _checkService.resume();
    setState(() {
      _isPaused = false;
    });
  }

  void _stopCheck() {
    _checkService.stop();
    setState(() {
      _isChecking = false;
      _isPaused = false;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedUrls.length == _sources.length) {
        _selectedUrls.clear();
      } else {
        _selectedUrls = _sources.map((s) => s.bookSourceUrl).toSet();
      }
    });
  }

  void _toggleSource(String url) {
    setState(() {
      if (_selectedUrls.contains(url)) {
        _selectedUrls.remove(url);
      } else {
        _selectedUrls.add(url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源校验'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const CheckSourceConfigDialog(),
              );
            },
            tooltip: '校验配置',
          ),
        ],
      ),
      body: Column(
        children: [
          // 操作栏
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '已选择: ${_selectedUrls.length}/${_sources.length}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    _selectedUrls.length == _sources.length ? '取消全选' : '全选',
                  ),
                ),
                if (!_isChecking) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _startCheck,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始校验'),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  if (_isPaused)
                    ElevatedButton.icon(
                      onPressed: _resumeCheck,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('继续'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _pauseCheck,
                      icon: const Icon(Icons.pause),
                      label: const Text('暂停'),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _stopCheck,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 进度显示
          if (_isChecking) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _totalCount > 0 ? _currentIndex / _totalCount : 0,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '进度: $_currentIndex/$_totalCount',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (_currentResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '当前: ${_currentResult!.sourceName}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _currentResult!.success ? '✓ 成功' : '✗ 失败',
                      style: TextStyle(
                        fontSize: 12,
                        color: _currentResult!.success ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // 书源列表
          Expanded(
            child: ListView.builder(
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final source = _sources[index];
                final isSelected = _selectedUrls.contains(source.bookSourceUrl);
                
                return CheckboxListTile(
                  title: Text(source.bookSourceName),
                  subtitle: Text(
                    source.bookSourceUrl,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: isSelected,
                  onChanged: _isChecking
                      ? null
                      : (value) => _toggleSource(source.bookSourceUrl),
                  secondary: Icon(
                    source.enabled ? Icons.check_circle : Icons.cancel,
                    color: source.enabled ? Colors.green : Colors.grey,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

