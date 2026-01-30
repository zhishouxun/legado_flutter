import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../utils/app_log.dart';
import '../../../utils/helpers/source/source_verification_help.dart';
import '../../../utils/helpers/source/source_help.dart';
import '../../../core/constants/app_status.dart';
import '../../../config/app_config.dart';
import '../../../core/constants/prefer_key.dart';
import '../../../services/cookie_service.dart';

/// 通用WebView浏览器页面
/// 参考项目：io.legado.app.ui.browser.WebViewActivity
class BrowserPage extends StatefulWidget {
  /// 要加载的URL
  final String url;
  
  /// 要加载的HTML内容（如果提供，将优先使用）
  final String? html;
  
  /// 页面标题
  final String? title;
  
  /// 书源名称（副标题）
  final String? sourceName;
  
  /// 书源来源（用于验证结果保存）
  final String? sourceOrigin;
  
  /// 是否启用书源验证结果保存
  final bool sourceVerificationEnable;
  
  /// 成功后是否重新获取
  final bool refetchAfterSuccess;
  
  /// 自定义请求头
  final Map<String, String>? headers;

  const BrowserPage({
    super.key,
    required this.url,
    this.html,
    this.title,
    this.sourceName,
    this.sourceOrigin,
    this.sourceVerificationEnable = false,
    this.refetchAfterSuccess = true,
    this.headers,
  });

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;
  bool _isFullScreen = false;
  String? _currentTitle;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title ?? '加载中...';
    _initWebView();
  }

  void _initWebView() {
    // 构建完整URL
    final fullUrl = widget.url;
    
    // 解析请求头
    final headers = widget.headers ?? {};

    // 获取User Agent（优先使用配置的，否则使用默认）
    String? userAgent = AppConfig.getUserAgent();
    if (userAgent.isEmpty) {
      userAgent = null; // 使用系统默认
    }

    // 创建WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    
    // 设置User Agent（如果配置了）
    if (userAgent != null) {
      _controller.setUserAgent(userAgent);
    }
    
    _controller
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
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
              _progress = 100;
            });
            // 保存Cookie
            _saveCookies(url);
            
            // 更新导航状态
            final canGoForward = await _controller.canGoForward();
            if (mounted) {
              setState(() {
                _canGoForward = canGoForward;
              });
            }
            
            // 更新标题
            _controller.getTitle().then((title) {
              if (title != null && title.isNotEmpty && mounted) {
                _controller.currentUrl().then((currentUrl) {
                  if (mounted) {
                    setState(() {
                      if (title != url && title != currentUrl) {
                        _currentTitle = title;
                      } else {
                        _currentTitle = widget.title ?? '网页';
                      }
                    });
                  }
                });
              }
            });
            
            // 重新注入图片长按脚本（页面加载完成后）
            _injectImageLongPressScript();
            
            // 检查Cloudflare挑战
            if (widget.sourceVerificationEnable) {
              _checkCloudflare();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              // 显示错误信息，并提供重试选项
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('加载失败: ${error.description}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: '重试',
                    textColor: Colors.white,
                    onPressed: () {
                      // 重新加载页面
                      _controller.reload();
                    },
                  ),
                ),
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // 处理特殊URL scheme
            final uri = Uri.tryParse(request.url);
            if (uri != null) {
              if (uri.scheme == 'legado' || uri.scheme == 'yuedu') {
                // 处理legado://或yuedu://协议
                _handleLegadoScheme(uri);
                return NavigationDecision.prevent;
              } else if (uri.scheme != 'http' && uri.scheme != 'https') {
                // 其他非HTTP协议，询问是否打开
                _showOpenExternalDialog(request.url);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setBackgroundColor(Theme.of(context).scaffoldBackgroundColor)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // 处理来自JS的消息（图片长按事件）
          if (message.message.isNotEmpty) {
            try {
              final data = message.message;
              if (data.startsWith('image:')) {
                final imageUrl = data.substring(6);
                _showImageSaveOptions(imageUrl);
              }
            } catch (e) {
              AppLog.instance.put('处理JS消息失败', error: e);
            }
          }
        },
      );

    // 注入JavaScript来监听图片长按事件
    _injectImageLongPressScript();

    // 加载内容
    if (widget.html != null && widget.html!.isNotEmpty) {
      _controller.loadHtmlString(
        widget.html!,
        baseUrl: fullUrl,
      );
    } else {
      _controller.loadRequest(
        Uri.parse(fullUrl),
        headers: headers,
      );
    }
  }

  /// 注入JavaScript来监听图片长按事件
  void _injectImageLongPressScript() {
    _controller.runJavaScript('''
      (function() {
        // 监听所有图片的长按事件
        document.addEventListener('contextmenu', function(e) {
          var target = e.target;
          if (target.tagName === 'IMG') {
            e.preventDefault();
            var imgUrl = target.src || target.getAttribute('data-src') || target.getAttribute('data-original');
            if (imgUrl) {
              FlutterChannel.postMessage('image:' + imgUrl);
            }
          }
        }, true);
        
        // 也监听触摸长按事件（移动端）
        var touchStartTime = 0;
        var touchStartElement = null;
        document.addEventListener('touchstart', function(e) {
          touchStartTime = Date.now();
          touchStartElement = e.target;
        }, true);
        
        document.addEventListener('touchend', function(e) {
          if (touchStartElement && Date.now() - touchStartTime > 500) {
            if (touchStartElement.tagName === 'IMG') {
              var imgUrl = touchStartElement.src || touchStartElement.getAttribute('data-src') || touchStartElement.getAttribute('data-original');
              if (imgUrl) {
                FlutterChannel.postMessage('image:' + imgUrl);
              }
            }
          }
          touchStartElement = null;
        }, true);
      })();
    ''');
  }

  /// 保存Cookie
  Future<void> _saveCookies(String url) async {
    try {
      // 从WebView获取Cookie
      final cookiesStr = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      
      final cookieStrValue = cookiesStr.toString();
      if (cookieStrValue.isNotEmpty && cookieStrValue != 'null' && cookieStrValue != 'undefined') {
        // 解析Cookie字符串
        final cookies = <String, String>{};
        final cookieStr = cookieStrValue.replaceAll('"', '');
        if (cookieStr.isNotEmpty && cookieStr != 'null') {
          final cookieList = cookieStr.split(';');
          for (final cookie in cookieList) {
            final parts = cookie.trim().split('=');
            if (parts.length == 2) {
              cookies[parts[0].trim()] = parts[1].trim();
            }
          }
        }
        
        // 保存到Cookie服务
        if (cookies.isNotEmpty && widget.sourceOrigin != null) {
          await CookieService.instance.saveCookiesForSource(
            widget.sourceOrigin!,
            cookies,
          );
        }
      }
    } catch (e) {
      AppLog.instance.put('保存Cookie失败: $url', error: e);
    }
  }

  /// 检查Cloudflare挑战
  Future<void> _checkCloudflare() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        '!!window._cf_chl_opt',
      );
      // 如果检测到Cloudflare挑战
      if (result == true || result.toString().toLowerCase() == 'true') {
        // 等待一段时间后检查是否已解决
        await Future.delayed(const Duration(seconds: 2));
        final resolved = await _controller.runJavaScriptReturningResult(
          'document.body && document.body.innerHTML.length > 100',
        );
        // 如果挑战已解决，自动保存验证结果
        if (resolved == true || resolved.toString().toLowerCase() == 'true') {
          await _saveVerificationResult();
        }
      }
    } catch (e) {
      // 忽略错误
      AppLog.instance.put('检查Cloudflare挑战失败', error: e);
    }
  }

  /// 处理legado://协议
  void _handleLegadoScheme(Uri uri) {
    // TODO: 处理legado://协议，可能需要跳转到在线导入页面
    AppLog.instance.put('处理legado协议: ${uri.toString()}');
  }

  /// 显示打开外部浏览器对话框
  void _showOpenExternalDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳转到其他应用'),
        content: Text('是否要打开: $url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }

  /// 切换全屏模式
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// 复制URL
  Future<void> _copyUrl() async {
    final currentUrl = await _controller.currentUrl();
    final url = currentUrl ?? widget.url;
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL已复制到剪贴板')),
      );
    }
  }

  /// 在外部浏览器打开
  Future<void> _openInExternalBrowser() async {
    final currentUrl = await _controller.currentUrl();
    final url = currentUrl ?? widget.url;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开URL')),
        );
      }
    }
  }

  /// 保存验证结果
  Future<void> _saveVerificationResult() async {
    if (!widget.sourceVerificationEnable || widget.sourceOrigin == null) {
      return;
    }

    try {
      // 显示保存中提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在保存验证结果...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      // 获取当前页面HTML
      final htmlResult = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      if (htmlResult is String && htmlResult.isNotEmpty) {
        final unescapedHtml = htmlResult.replaceAll('\\"', '"').replaceAll('\\n', '\n');
        final cleanHtml = unescapedHtml.trim().replaceAll(RegExp(r'^"|"$'), '');
        SourceVerificationHelp.setResult(widget.sourceOrigin!, cleanHtml);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('验证结果已保存'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // 如果配置了成功后重新获取，延迟关闭页面
          if (widget.refetchAfterSuccess) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('获取页面内容失败');
      }
    } catch (e) {
      AppLog.instance.put('保存验证结果失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 显示图片保存选项
  void _showImageSaveOptions(String imageUrl) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save),
              title: const Text('保存图片'),
              onTap: () {
                Navigator.pop(context);
                _saveImage(imageUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('选择保存文件夹'),
              onTap: () {
                Navigator.pop(context);
                _selectSaveFolder();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 保存图片
  Future<void> _saveImage(String imageUrl) async {
    try {
      // 下载图片（带重试机制）
      http.Response? response;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          response = await http.get(Uri.parse(imageUrl)).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('下载超时');
            },
          );
          if (response.statusCode == 200) {
            break;
          } else if (response.statusCode >= 500 && retryCount < maxRetries - 1) {
            // 服务器错误，重试
            retryCount++;
            await Future.delayed(Duration(seconds: retryCount));
            continue;
          } else {
            throw Exception('下载图片失败: ${response.statusCode}');
          }
        } catch (e) {
          if (retryCount < maxRetries - 1) {
            retryCount++;
            await Future.delayed(Duration(seconds: retryCount));
            continue;
          }
          rethrow;
        }
      }
      
      if (response == null || response.statusCode != 200) {
        throw Exception('下载图片失败');
      }

      // 获取保存路径（优先使用配置的路径）
      String savePath = AppConfig.getString(PreferKey.imageSavePath);
      if (savePath.isEmpty) {
        // 如果没有配置，使用默认路径
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        savePath = imagesDir.path;
      }

      // 生成文件名
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 确保文件名有扩展名
      final finalFileName = fileName.contains('.')
          ? fileName
          : '$fileName.jpg';

      // 保存图片
      final file = File('$savePath/$finalFileName');
      await file.writeAsBytes(response.bodyBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片已保存到: ${file.path}')),
        );
      }
    } catch (e) {
      AppLog.instance.put('保存图片失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存图片失败: $e')),
        );
      }
    }
  }

  /// 选择保存文件夹
  Future<void> _selectSaveFolder() async {
    try {
      // 使用file_picker选择保存位置
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存文件夹',
      );

      if (result != null) {
        // 保存路径到配置
        await AppConfig.setString(PreferKey.imageSavePath, result);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已选择文件夹: $result')),
          );
        }
      }
    } catch (e) {
      AppLog.instance.put('选择文件夹失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.sourceVerificationEnable && widget.sourceOrigin != null) {
      SourceVerificationHelp.checkResult(widget.sourceOrigin!);
    }
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullScreen,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_isFullScreen) {
          _toggleFullScreen();
          return;
        }
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: _isFullScreen
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      _controller.goBack();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentTitle ?? widget.title ?? '网页',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (widget.sourceName != null)
                      Text(
                        widget.sourceName!,
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                actions: [
                  // 前进按钮
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _canGoForward
                        ? () async {
                            if (await _controller.canGoForward()) {
                              _controller.goForward();
                            }
                          }
                        : null,
                  ),
                  if (widget.sourceVerificationEnable)
                    IconButton(
                      icon: const Icon(Icons.check_circle),
                      onPressed: _saveVerificationResult,
                      tooltip: '保存验证结果',
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'open_browser',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_browser, size: 20),
                            SizedBox(width: 8),
                            Text('在外部浏览器打开'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy_url',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 20),
                            SizedBox(width: 8),
                            Text('复制URL'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'full_screen',
                        child: Row(
                          children: [
                            Icon(
                              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(_isFullScreen ? '退出全屏' : '全屏'),
                          ],
                        ),
                      ),
                      if (widget.sourceOrigin != null) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'disable_source',
                          child: Row(
                            children: [
                              Icon(Icons.block, size: 20),
                              SizedBox(width: 8),
                              Text('禁用书源'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete_source',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('删除书源', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'open_browser':
                          _openInExternalBrowser();
                          break;
                        case 'copy_url':
                          _copyUrl();
                          break;
                        case 'full_screen':
                          _toggleFullScreen();
                          break;
                        case 'disable_source':
                          _disableSource();
                          break;
                        case 'delete_source':
                          _deleteSource();
                          break;
                      }
                    },
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
                  value: _progress / 100.0,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 禁用书源
  Future<void> _disableSource() async {
    if (widget.sourceOrigin == null) return;
    
    try {
      await SourceHelp.enableSource(
        widget.sourceOrigin!,
        AppStatus.sourceTypeBook,
        false,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已禁用书源')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLog.instance.put('禁用书源失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('禁用失败: $e')),
        );
      }
    }
  }

  /// 删除书源
  Future<void> _deleteSource() async {
    if (widget.sourceOrigin == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书源'),
        content: Text('确定要删除书源 "${widget.sourceName ?? widget.sourceOrigin}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SourceHelp.deleteBookSource(widget.sourceOrigin!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除书源')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        AppLog.instance.put('删除书源失败', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }
}

