import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_source.dart';
import '../../../services/source/book_source_service.dart';
import 'webview_login_widget.dart';
import 'form_login_dialog.dart';

/// 书源登录页面
class SourceLoginPage extends ConsumerStatefulWidget {
  final String sourceUrl;

  const SourceLoginPage({
    super.key,
    required this.sourceUrl,
  });

  @override
  ConsumerState<SourceLoginPage> createState() => _SourceLoginPageState();
}

class _SourceLoginPageState extends ConsumerState<SourceLoginPage> {
  BookSource? _source;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  Future<void> _loadSource() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final source = await BookSourceService.instance.getBookSourceByUrl(widget.sourceUrl);
      if (source == null) {
        throw Exception('未找到书源');
      }

      setState(() {
        _source = source;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showLogin() {
    if (_source == null) return;

    // 如果有loginUi，显示表单登录对话框
    if (_source!.loginUi != null && _source!.loginUi!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => FormLoginDialog(
          source: _source!,
          onLoginSuccess: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop(true); // 返回并通知登录成功
          },
        ),
      );
    } else {
      // 否则显示WebView登录页面
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WebViewLoginWidget(
            source: _source!,
            onLoginSuccess: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // 返回并通知登录成功
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_source?.bookSourceName ?? '书源登录'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '加载失败',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSource,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _source == null
                  ? const Center(child: Text('书源不存在'))
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login,
                              size: 64,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _source!.bookSourceName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_source!.loginUrl != null)
                              Text(
                                '登录地址: ${_source!.loginUrl}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _showLogin,
                              icon: const Icon(Icons.login),
                              label: const Text('开始登录'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

