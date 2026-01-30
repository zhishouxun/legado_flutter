import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/book_source.dart';
import '../../../services/source/login_info_service.dart';
import '../../../services/network/network_service.dart';
import '../../../utils/js_engine.dart' as js_engine;
import '../../../utils/app_log.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 表单登录对话框
class FormLoginDialog extends BaseBottomSheetStateful {
  final BookSource source;
  final VoidCallback? onLoginSuccess;

  const FormLoginDialog({
    super.key,
    required this.source,
    this.onLoginSuccess,
  }) : super(
          title: '登录',
          heightFactor: 0.7,
        );

  @override
  State<FormLoginDialog> createState() => _FormLoginDialogState();
}

class _FormLoginDialogState extends BaseBottomSheetState<FormLoginDialog> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, RowUiData> _uiData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _parseLoginUi();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _parseLoginUi() async {
    final loginUi = widget.source.loginUi;
    if (loginUi == null || loginUi.isEmpty) return;

    try {
      // 获取已保存的登录信息
      final savedLoginInfo = await LoginInfoService.instance.getLoginInfo(
        widget.source.bookSourceUrl,
      );

      final jsonData = jsonDecode(loginUi);
      if (jsonData is List) {
        for (int i = 0; i < jsonData.length; i++) {
          final item = jsonData[i] as Map<String, dynamic>;
          final type = item['type'] as String? ?? 'text';
          final name = item['name'] as String? ?? '';
          final action = item['action'] as String?;

          _uiData[i] = RowUiData(
            name: name,
            type: type,
            action: action,
          );

          if (type == 'text' || type == 'password') {
            final controller = TextEditingController();
            // 如果有保存的登录信息，填充到输入框
            if (savedLoginInfo.containsKey(name)) {
              controller.text = savedLoginInfo[name]!;
            }
            _controllers[i] = controller;
          }
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLog.instance.put('解析登录UI失败: $e');
    }
  }

  Map<String, String> _getLoginData() {
    final loginData = <String, String>{};
    for (final entry in _controllers.entries) {
      final uiData = _uiData[entry.key];
      if (uiData != null &&
          (uiData.type == 'text' || uiData.type == 'password')) {
        final value = entry.value.text.trim();
        if (value.isNotEmpty) {
          loginData[uiData.name] = value;
        }
      }
    }
    return loginData;
  }

  Future<void> _login() async {
    final loginData = _getLoginData();

    if (loginData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写登录信息')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 保存登录信息
      await LoginInfoService.instance.saveLoginInfo(
        widget.source.bookSourceUrl,
        loginData,
      );

      // 如果有登录URL，执行登录请求
      if (widget.source.loginUrl != null &&
          widget.source.loginUrl!.isNotEmpty) {
        await _executeLogin(loginData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
        widget.onLoginSuccess?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLog.instance.put('登录失败: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e')),
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

  /// 执行登录请求
  Future<void> _executeLogin(Map<String, String> loginData) async {
    final loginUrl = widget.source.loginUrl;
    if (loginUrl == null || loginUrl.isEmpty) return;

    // 构建完整URL
    final fullUrl =
        NetworkService.joinUrl(widget.source.bookSourceUrl, loginUrl);

    // 解析请求头
    final headers = NetworkService.parseHeaders(widget.source.header);

    // 如果有登录JS，执行JS来构建请求
    // 参考项目：source.login()
    // 这里简化处理，直接发送POST请求
    try {
      final response = await NetworkService.instance.post(
        fullUrl,
        data: loginData,
        headers: headers,
      );

      // 检查响应
      if (response.statusCode != 200) {
        throw Exception('登录请求失败: ${response.statusCode}');
      }

      // 如果有loginCheckJs，执行检查
      if (widget.source.loginCheckJs != null &&
          widget.source.loginCheckJs!.isNotEmpty) {
        final checkResult = await _checkLoginStatus(response.data);
        if (!checkResult) {
          throw Exception('登录验证失败');
        }
      }
    } catch (e) {
      AppLog.instance.put('执行登录请求失败: $e', error: e);
      rethrow;
    }
  }

  /// 检查登录状态
  Future<bool> _checkLoginStatus(dynamic responseData) async {
    final loginCheckJs = widget.source.loginCheckJs;
    if (loginCheckJs == null || loginCheckJs.isEmpty) {
      return true; // 没有检查JS，默认成功
    }

    try {
      // 执行登录检查JS
      final jsCode = '''
        ${widget.source.jsLib ?? ''}
        $loginCheckJs
      ''';

      final result = await js_engine.JSEngine.evalJS(
        jsCode,
        bindings: {
          'result': responseData,
          'source': widget.source.toJson(),
        },
      );

      // 检查结果（JS应该返回true/false或字符串）
      if (result is bool) {
        return result;
      } else if (result is String) {
        return result.toLowerCase() == 'true' || result == '1';
      }
      return false;
    } catch (e) {
      AppLog.instance.put('登录状态检查失败: $e', error: e);
      return false;
    }
  }

  /// 处理按钮点击
  Future<void> _handleButtonClick(RowUiData uiData) async {
    if (uiData.action == null || uiData.action!.isEmpty) return;

    final action = uiData.action!;

    // 检查是否是URL
    if (action.startsWith('http://') || action.startsWith('https://')) {
      // 打开URL
      final uri = Uri.parse(action);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // 执行JavaScript
      try {
        final loginData = _getLoginData();
        final jsCode = '''
          ${widget.source.jsLib ?? ''}
          $action
        ''';

        await js_engine.JSEngine.evalJS(
          jsCode,
          bindings: {
            'result': loginData,
            'source': widget.source.toJson(),
          },
        );
      } catch (e) {
        AppLog.instance.put('执行按钮JS失败: $e', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('执行失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 书源名称提示
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            widget.source.bookSourceName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // 表单内容
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _uiData.entries.map((entry) {
                final index = entry.key;
                final uiData = entry.value;

                if (uiData.type == 'text' || uiData.type == 'password') {
                  final controller = _controllers[index];
                  if (controller == null) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: controller,
                      obscureText: uiData.type == 'password',
                      decoration: InputDecoration(
                        labelText: uiData.name,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                } else if (uiData.type == 'button') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton(
                      onPressed:
                          _isLoading ? null : () => _handleButtonClick(uiData),
                      child: Text(uiData.name),
                    ),
                  );
                }

                return const SizedBox.shrink();
              }).toList(),
            ),
          ),
        ),
        // 底部按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 登录UI行数据
class RowUiData {
  final String name;
  final String type;
  final String? action;

  RowUiData({
    required this.name,
    required this.type,
    this.action,
  });
}
