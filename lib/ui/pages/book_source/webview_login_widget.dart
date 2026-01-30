import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../data/models/book_source.dart';
import '../../../services/network/network_service.dart';
import '../../../services/cookie_service.dart';
import '../../../utils/js_engine.dart' as js_engine;
import '../../../utils/app_log.dart';

/// WebView登录组件
class WebViewLoginWidget extends StatefulWidget {
  final BookSource source;
  final VoidCallback? onLoginSuccess;

  const WebViewLoginWidget({
    super.key,
    required this.source,
    this.onLoginSuccess,
  });

  @override
  State<WebViewLoginWidget> createState() => _WebViewLoginWidgetState();
}

class _WebViewLoginWidgetState extends State<WebViewLoginWidget> {
  late WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final loginUrl = widget.source.loginUrl;
    if (loginUrl == null || loginUrl.isEmpty) {
      return;
    }

    // 构建完整URL
    final fullUrl = NetworkService.joinUrl(widget.source.bookSourceUrl, loginUrl);

    // 解析请求头
    final headers = NetworkService.parseHeaders(widget.source.header);

    // 创建WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _progress = 0;
            });
            // 保存Cookie
            _saveCookies(url);
          },
          onProgress: (int progress) {
            setState(() {
              _progress = progress;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _progress = 100;
            });
            // 保存Cookie
            _saveCookies(url);
            
            // 如果正在检查登录状态，关闭页面
            if (_checking) {
              widget.onLoginSuccess?.call();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('加载失败: ${error.description}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      )
      ..setBackgroundColor(Colors.white)
      ..loadRequest(
        Uri.parse(fullUrl),
        headers: headers,
      );
  }

  Future<void> _saveCookies(String url) async {
    try {
      // 从WebView获取Cookie
      // 注意：webview_flutter的Cookie获取方式可能不同
      // 这里使用JavaScript来获取Cookie
      final cookiesStr = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      
      // 解析Cookie字符串
      final cookies = <String, String>{};
      final cookieStr = cookiesStr.toString();
      if (cookieStr.isNotEmpty) {
        final cookieList = cookiesStr.toString().split(';');
        for (final cookie in cookieList) {
          final parts = cookie.trim().split('=');
          if (parts.length == 2) {
            cookies[parts[0].trim()] = parts[1].trim();
          }
        }
      }
      
      // 保存到Cookie服务
      await CookieService.instance.saveCookiesForSource(
        widget.source.bookSourceUrl,
        cookies,
      );
    } catch (e) {
    }
  }

  Future<void> _checkLogin() async {
    if (_checking) return;

    setState(() {
      _checking = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在检查登录状态...')),
      );
    }

    try {
      // 获取页面HTML内容
      final html = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      // 如果有loginCheckJs，执行检查
      if (widget.source.loginCheckJs != null && 
          widget.source.loginCheckJs!.isNotEmpty) {
        final checkResult = await _checkLoginStatus(html.toString());
        if (checkResult) {
          // 登录成功，保存Cookie并关闭
          await _saveCookies(widget.source.loginUrl ?? '');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('登录成功')),
            );
            widget.onLoginSuccess?.call();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('登录验证失败，请重新登录')),
            );
          }
        }
      } else {
        // 没有检查JS，默认成功
        await _saveCookies(widget.source.loginUrl ?? '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录成功')),
          );
          widget.onLoginSuccess?.call();
        }
      }
    } catch (e) {
      AppLog.instance.put('检查登录状态失败: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查登录状态失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  /// 检查登录状态
  Future<bool> _checkLoginStatus(String html) async {
    final loginCheckJs = widget.source.loginCheckJs;
    if (loginCheckJs == null || loginCheckJs.isEmpty) {
      return true; // 没有检查JS，默认成功
    }

    try {
      // 执行登录检查JS
      final jsCode = '''
        ${widget.source.jsLib ?? ''}
        var html = `$html`;
        $loginCheckJs
      ''';

      final result = await js_engine.JSEngine.evalJS(
        jsCode,
        bindings: {
          'html': html,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('登录 ${widget.source.bookSourceName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: _checkLogin,
            tooltip: '检查登录状态',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading && _progress < 100)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

