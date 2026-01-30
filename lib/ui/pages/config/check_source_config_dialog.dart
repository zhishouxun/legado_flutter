import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../core/constants/prefer_key.dart';
import '../../../utils/cache_manager.dart';

/// 书源检查配置对话框
/// 参考项目：io.legado.app.ui.config.CheckSourceConfig
class CheckSourceConfigDialog extends StatefulWidget {
  const CheckSourceConfigDialog({super.key});

  @override
  State<CheckSourceConfigDialog> createState() => _CheckSourceConfigDialogState();
}

class _CheckSourceConfigDialogState extends State<CheckSourceConfigDialog> {
  final TextEditingController _timeoutController = TextEditingController();
  final TextEditingController _keywordController = TextEditingController();
  bool _checkSearch = true;
  bool _checkDiscovery = true;
  bool _checkInfo = false;
  bool _checkCategory = false;
  bool _checkContent = false;

  @override
  void initState() {
    super.initState();
    _loadConfig().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timeoutController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    // 超时时间（秒）
    final timeout = AppConfig.getInt(PreferKey.checkSourceTimeout, defaultValue: 180000);
    _timeoutController.text = (timeout ~/ 1000).toString();

    // 关键字（优先从AppConfig加载，否则从CacheManager加载）
    String keyword = AppConfig.getString(PreferKey.checkSourceKeyword);
    if (keyword.isEmpty) {
      // 从CacheManager加载（兼容旧配置）
      try {
        final keywordValue = await CacheManager.instance.get('checkSourceKeyword');
        keyword = keywordValue ?? '我的';
      } catch (e) {
        keyword = '我的';
      }
    }
    _keywordController.text = keyword;

    // 检查项
    _checkSearch = AppConfig.getBool(PreferKey.checkSourceSearch, defaultValue: true);
    _checkDiscovery = AppConfig.getBool(PreferKey.checkSourceDiscovery, defaultValue: true);
    _checkInfo = AppConfig.getBool(PreferKey.checkSourceInfo, defaultValue: false);
    _checkCategory = AppConfig.getBool(PreferKey.checkSourceCategory, defaultValue: false);
    _checkContent = AppConfig.getBool(PreferKey.checkSourceContent, defaultValue: false);
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    final timeoutText = _timeoutController.text.trim();
    if (timeoutText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('超时时间不能为空')),
      );
      return;
    }

    final timeout = int.tryParse(timeoutText);
    if (timeout == null || timeout < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('超时时间必须是大于0的整数')),
      );
      return;
    }
    
    if (timeout > 600) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('超时时间不能超过600秒（10分钟）')),
      );
      return;
    }

    // 保存超时时间（毫秒）
    await AppConfig.setInt(PreferKey.checkSourceTimeout, timeout * 1000);

    // 保存关键字
    final keyword = _keywordController.text.trim();
    if (keyword.isNotEmpty) {
      await AppConfig.setString(PreferKey.checkSourceKeyword, keyword);
      // 同时保存到CacheManager（兼容旧代码）
      await CacheManager.instance.put('checkSourceKeyword', keyword);
    }

    // 保存检查项
    await AppConfig.setBool(PreferKey.checkSourceSearch, _checkSearch);
    await AppConfig.setBool(PreferKey.checkSourceDiscovery, _checkDiscovery);
    await AppConfig.setBool(PreferKey.checkSourceInfo, _checkInfo);
    await AppConfig.setBool(PreferKey.checkSourceCategory, _checkCategory);
    await AppConfig.setBool(PreferKey.checkSourceContent, _checkContent);
    
    // 同时保存到CacheManager（兼容旧代码）
    await CacheManager.instance.put('checkSearch', _checkSearch.toString());
    await CacheManager.instance.put('checkDiscovery', _checkDiscovery.toString());
    await CacheManager.instance.put('checkInfo', _checkInfo.toString());
    await CacheManager.instance.put('checkCategory', _checkCategory.toString());
    await CacheManager.instance.put('checkContent', _checkContent.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置已保存'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('书源检查配置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 关键字
            TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                labelText: '检查关键字',
                hintText: '我的',
                border: OutlineInputBorder(),
                helperText: '用于搜索测试的关键字（留空使用默认值"我的"）',
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            
            // 超时时间
            TextField(
              controller: _timeoutController,
              decoration: const InputDecoration(
                labelText: '超时时间（秒）',
                hintText: '请输入超时时间',
                border: OutlineInputBorder(),
                helperText: '检查书源时的超时时间，单位为秒',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // 检查项
            const Text(
              '检查项',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 搜索
            CheckboxListTile(
              title: const Text('搜索'),
              subtitle: const Text('检查书源搜索功能'),
              value: _checkSearch,
              onChanged: (value) {
                setState(() {
                  _checkSearch = value ?? true;
                  // 搜索和发现至少选一个
                  if (!_checkSearch && !_checkDiscovery) {
                    _checkDiscovery = true;
                  }
                });
              },
            ),

            // 发现
            CheckboxListTile(
              title: const Text('发现'),
              subtitle: const Text('检查书源发现功能'),
              value: _checkDiscovery,
              onChanged: (value) {
                setState(() {
                  _checkDiscovery = value ?? true;
                  // 搜索和发现至少选一个
                  if (!_checkSearch && !_checkDiscovery) {
                    _checkSearch = true;
                  }
                });
              },
            ),

            // 详情
            CheckboxListTile(
              title: const Text('详情'),
              subtitle: const Text('检查书源详情功能'),
              value: _checkInfo,
              onChanged: (value) {
                setState(() {
                  _checkInfo = value ?? false;
                  // 如果取消详情，同时取消分类和正文
                  if (!_checkInfo) {
                    _checkCategory = false;
                    _checkContent = false;
                  }
                });
              },
            ),

            // 分类
            CheckboxListTile(
              title: const Text('分类'),
              subtitle: const Text('检查书源分类功能'),
              value: _checkCategory,
              enabled: _checkInfo,
              onChanged: _checkInfo
                  ? (value) {
                      setState(() {
                        _checkCategory = value ?? false;
                        // 如果取消分类，同时取消正文
                        if (!_checkCategory) {
                          _checkContent = false;
                        }
                      });
                    }
                  : null,
            ),

            // 正文
            CheckboxListTile(
              title: const Text('正文'),
              subtitle: const Text('检查书源正文功能'),
              value: _checkContent,
              enabled: _checkCategory,
              onChanged: _checkCategory
                  ? (value) {
                      setState(() {
                        _checkContent = value ?? false;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _saveConfig,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

