import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../services/storage/webdav_service.dart';

/// 备份恢复配置页面 - WebDAV设置
class BackupConfigPage extends StatefulWidget {
  const BackupConfigPage({super.key});

  @override
  State<BackupConfigPage> createState() => _BackupConfigPageState();
}

class _BackupConfigPageState extends State<BackupConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dirController = TextEditingController();
  final _deviceNameController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _dirController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    setState(() {
      _urlController.text = AppConfig.getString('webdav_url',
          defaultValue: WebDavService.defaultWebDavUrl);
      _accountController.text =
          AppConfig.getString('webdav_account', defaultValue: '');
      _passwordController.text =
          AppConfig.getString('webdav_password', defaultValue: '');
      _dirController.text =
          AppConfig.getString('webdav_dir', defaultValue: 'legado');
      _deviceNameController.text =
          AppConfig.getString('webdav_device_name', defaultValue: 'device');
    });
  }

  /// 测试连接
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _connectionStatus = null;
    });

    try {
      await WebDavService.instance.configure(
        url: _urlController.text.trim(),
        username: _accountController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final isOk = await WebDavService.instance.check();
      if (isOk) {
        setState(() {
          _connectionStatus = '连接成功';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WebDAV连接成功')),
          );
        }
      } else {
        setState(() {
          _connectionStatus = '连接失败';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WebDAV连接失败，请检查配置')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _connectionStatus = '连接错误: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接错误: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AppConfig.setString('webdav_url', _urlController.text.trim());
      await AppConfig.setString(
          'webdav_account', _accountController.text.trim());
      await AppConfig.setString(
          'webdav_password', _passwordController.text.trim());
      await AppConfig.setString('webdav_dir', _dirController.text.trim());
      await AppConfig.setString(
          'webdav_device_name', _deviceNameController.text.trim());

      // 重新配置WebDAV服务
      await WebDavService.instance.configure(
        url: _urlController.text.trim(),
        username: _accountController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份恢复设置'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveConfig,
              tooltip: '保存',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // WebDAV URL
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'WebDAV服务器地址',
                hintText: 'https://dav.jianguoyun.com/dav/',
                border: OutlineInputBorder(),
                helperText: '支持坚果云、Nextcloud等WebDAV服务',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入WebDAV服务器地址';
                }
                final uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasScheme) {
                  return '请输入有效的URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 账号
            TextFormField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '请输入WebDAV用户名',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 密码
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '密码',
                hintText: '请输入WebDAV密码',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_passwordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_passwordVisible,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 目录
            TextFormField(
              controller: _dirController,
              decoration: const InputDecoration(
                labelText: '备份目录（可选）',
                hintText: 'legado',
                border: OutlineInputBorder(),
                helperText: '留空则使用根目录',
              ),
            ),
            const SizedBox(height: 16),

            // 设备名称
            TextFormField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: '设备名称（可选）',
                hintText: 'device',
                border: OutlineInputBorder(),
                helperText: '用于备份文件名标识',
              ),
            ),
            const SizedBox(height: 24),

            // 测试连接按钮
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testConnection,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('测试连接'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_connectionStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                _connectionStatus!,
                style: TextStyle(
                  color: _connectionStatus!.contains('成功')
                      ? Colors.green
                      : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),

            // 说明
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '使用说明',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 支持坚果云、Nextcloud等WebDAV服务\n'
                      '• 坚果云默认地址：https://dav.jianguoyun.com/dav/\n'
                      '• 备份文件将自动上传到WebDAV服务器\n'
                      '• 可以从WebDAV恢复备份数据',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
