import 'package:flutter/material.dart';
import '../../../services/source/check_source_service.dart';
import '../../../utils/app_log.dart';

/// 书源校验配置页面
class CheckSourceConfigPage extends StatefulWidget {
  const CheckSourceConfigPage({super.key});

  @override
  State<CheckSourceConfigPage> createState() => _CheckSourceConfigPageState();
}

class _CheckSourceConfigPageState extends State<CheckSourceConfigPage> {
  final _keywordController = TextEditingController();
  final _timeoutController = TextEditingController();

  bool _checkSearch = true;
  bool _checkDiscovery = true;
  bool _checkInfo = true;
  bool _checkCategory = true;
  bool _checkContent = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final checkService = CheckSourceService.instance;
      await checkService.init();

      final config = checkService.config;
      _keywordController.text = config.keyword;
      _timeoutController.text = (config.timeout ~/ 1000).toString();
      _checkSearch = config.checkSearch;
      _checkDiscovery = config.checkDiscovery;
      _checkInfo = config.checkInfo;
      _checkCategory = config.checkCategory;
      _checkContent = config.checkContent;
    } catch (e) {
      AppLog.instance.put('加载校验配置失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载配置失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    try {
      final timeoutSeconds = int.tryParse(_timeoutController.text);
      if (timeoutSeconds == null || timeoutSeconds < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('超时时间必须是大于0的整数')),
        );
        return;
      }

      final checkService = CheckSourceService.instance;
      await checkService.init();

      final config = checkService.config;
      config.keyword = _keywordController.text.trim();
      config.timeout = timeoutSeconds * 1000;
      config.checkSearch = _checkSearch;
      config.checkDiscovery = _checkDiscovery;
      config.checkInfo = _checkInfo;
      config.checkCategory = _checkCategory;
      config.checkContent = _checkContent;

      await config.save();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLog.instance.put('保存校验配置失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('校验配置'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('校验配置'),
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 校验关键字
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '校验关键字',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '用于搜索测试的关键字',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(
                      hintText: '请输入关键字',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 超时时间
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '超时时间',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '每个校验项的超时时间（秒）',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _timeoutController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '请输入超时时间（秒）',
                      border: OutlineInputBorder(),
                      suffixText: '秒',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 校验项选择
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '校验项',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '选择需要校验的功能项',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('搜索'),
                    subtitle: const Text('校验搜索功能是否正常'),
                    value: _checkSearch,
                    onChanged: (value) {
                      setState(() {
                        _checkSearch = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('发现'),
                    subtitle: const Text('校验发现页功能是否正常'),
                    value: _checkDiscovery,
                    onChanged: (value) {
                      setState(() {
                        _checkDiscovery = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('详情'),
                    subtitle: const Text('校验书籍详情页解析是否正常'),
                    value: _checkInfo,
                    onChanged: (value) {
                      setState(() {
                        _checkInfo = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('目录'),
                    subtitle: const Text('校验章节列表获取是否正常'),
                    value: _checkCategory,
                    onChanged: (value) {
                      setState(() {
                        _checkCategory = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('正文'),
                    subtitle: const Text('校验章节内容获取是否正常'),
                    value: _checkContent,
                    onChanged: (value) {
                      setState(() {
                        _checkContent = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 配置摘要
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '配置摘要',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final items = <String>[];
                      if (_checkSearch) items.add('搜索');
                      if (_checkDiscovery) items.add('发现');
                      if (_checkInfo) items.add('详情');
                      if (_checkCategory) items.add('目录');
                      if (_checkContent) items.add('正文');

                      final timeoutSeconds = _timeoutController.text.isEmpty
                          ? '180'
                          : _timeoutController.text;

                      return Text(
                        '超时: $timeoutSeconds秒, 校验项: ${items.isEmpty ? '无' : items.join('、')}',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
