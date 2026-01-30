import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../data/models/rss_source.dart';
import '../../../data/models/rss_article.dart';
import '../../../data/models/book_source_rule.dart';
import '../../../services/rss_service.dart';
import '../../../services/rss_read_record_service.dart';
import '../../../services/network/network_service.dart';
import '../../../utils/parsers/rule_parser.dart';
import '../../../utils/app_log.dart';
import '../../../config/app_config.dart';

/// RSS阅读页面
class RssReadPage extends StatefulWidget {
  final RssSource source;
  final RssArticle article;

  const RssReadPage({
    super.key,
    required this.source,
    required this.article,
  });

  @override
  State<RssReadPage> createState() => _RssReadPageState();
}

class _RssReadPageState extends State<RssReadPage> {
  bool _isLoading = false;
  String? _content;
  bool _isStarred = false;
  bool _checkingStar = true;
  bool _useWebView = false; // 是否使用WebView模式

  @override
  void initState() {
    super.initState();
    _loadContent();
    _markAsRead();
    _checkStarStatus();
  }

  Future<void> _checkStarStatus() async {
    final isStarred = await RssService.instance.isStarred(
      widget.article.origin,
      widget.article.link,
    );
    if (mounted) {
      setState(() {
        _isStarred = isStarred;
        _checkingStar = false;
      });
    }
  }

  Future<void> _toggleStar() async {
    if (_isStarred) {
      // 取消收藏
      final success = await RssService.instance.deleteRssStar(
        widget.article.origin,
        widget.article.link,
      );
      if (success && mounted) {
        setState(() {
          _isStarred = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已取消收藏')),
          );
        }
      }
    } else {
      // 添加收藏
      final success = await RssService.instance.addStarFromArticle(widget.article);
      if (success && mounted) {
        setState(() {
          _isStarred = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已添加收藏')),
          );
        }
      }
    }
  }

  /// 加载RSS文章内容
  /// 参考项目：ReadRssViewModel.loadContent
  Future<void> _loadContent() async {
    // 如果已有内容，直接使用
    if (widget.article.content != null && widget.article.content!.isNotEmpty) {
      setState(() {
        _content = widget.article.content;
      });
      return;
    }

    // 如果有描述，先显示描述
    if (widget.article.description != null && widget.article.description!.isNotEmpty) {
      setState(() {
        _content = widget.article.description;
      });
    }

    // 检查是否有内容规则
    final ruleContent = widget.source.ruleContent;
    if (ruleContent == null || ruleContent.isEmpty) {
      // 没有内容规则，使用描述或链接
      setState(() {
        _content = widget.article.description ?? '暂无内容';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 从网络获取文章内容
      // 参考项目：Rss.getContentAwait
      final response = await NetworkService.instance.get(
        widget.article.link,
        headers: NetworkService.parseHeaders(widget.source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);
      
      if (html.isEmpty) {
        throw Exception('获取内容为空');
      }

      // 使用规则解析内容
      // 参考项目：AnalyzeRule.getString(ruleContent)
      final contentRule = ContentRule(content: ruleContent);
      final content = await RuleParser.parseContentRule(
        html,
        contentRule,
        baseUrl: NetworkService.joinUrl(widget.article.origin, widget.article.link),
        bookName: null,
        bookOrigin: null,
      );

      if (content != null && content.isNotEmpty) {
        // 更新文章内容
        final updatedArticle = widget.article.copyWith(content: content);
        await RssService.instance.addOrUpdateRssArticle(updatedArticle);
        
        setState(() {
          _content = content;
          _isLoading = false;
        });
      } else {
        // 解析失败，使用描述
        setState(() {
          _content = widget.article.description ?? '暂无内容';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLog.instance.put('加载RSS文章内容失败: ${widget.article.title}', error: e);
      setState(() {
        _content = widget.article.description ?? '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead() async {
    // 记录RSS阅读记录
    await RssReadRecordService.instance.markAsRead(
      widget.article.origin,
      widget.article.link,
      title: widget.article.title,
    );
    if (!widget.article.read) {
      await RssService.instance.markArticleAsRead(
        widget.article.origin,
        widget.article.link,
        true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 切换显示模式
          IconButton(
            icon: Icon(_useWebView ? Icons.text_fields : Icons.web),
            onPressed: () {
              setState(() {
                _useWebView = !_useWebView;
              });
            },
            tooltip: _useWebView ? '文本模式' : 'WebView模式',
          ),
          // 收藏按钮
          if (!_checkingStar)
            IconButton(
              icon: Icon(_isStarred ? Icons.star : Icons.star_border),
              onPressed: _toggleStar,
              tooltip: _isStarred ? '取消收藏' : '收藏',
            ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              try {
                final uri = Uri.parse(widget.article.link);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('无法打开链接')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('打开链接失败: $e')),
                  );
                }
              }
            },
            tooltip: '浏览器打开',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _useWebView && _content != null && _content!.isNotEmpty
              ? _buildWebViewContent()
              : _buildTextContent(),
    );
  }

  /// 构建WebView内容显示
  Widget _buildWebViewContent() {
    // 构建HTML内容
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 16px;
      font-size: 16px;
      line-height: 1.6;
      color: ${isDark ? '#ffffff' : '#000000'};
      background-color: ${isDark ? '#121212' : '#ffffff'};
    }
    img {
      max-width: 100%;
      height: auto;
    }
    a {
      color: ${Theme.of(context).colorScheme.primary.value.toRadixString(16)};
    }
  </style>
</head>
<body>
  ${widget.article.pubDate != null && widget.article.pubDate!.isNotEmpty 
      ? '<p style="color: #666; font-size: 12px;">发布时间: ${widget.article.pubDate}</p>' 
      : ''}
  ${widget.article.image != null && widget.article.image!.isNotEmpty 
      ? '<img src="${widget.article.image}" alt="文章图片" />' 
      : ''}
  ${_content ?? '暂无内容'}
</body>
</html>
''';

    // 获取基础URL
    final baseUrl = NetworkService.joinUrl(widget.article.origin, widget.article.link);
    
    // 创建WebViewController
    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(widget.source.enableJs ? JavaScriptMode.unrestricted : JavaScriptMode.disabled)
      ..setBackgroundColor(Theme.of(context).scaffoldBackgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // 注入图片长按脚本（延迟执行以确保页面加载完成）
            Future.delayed(const Duration(milliseconds: 100), () {
              _injectImageLongPressScript(controller);
            });
          },
          onWebResourceError: (WebResourceError error) {
            AppLog.instance.put('WebView加载错误: ${error.description}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('加载错误: ${error.description}')),
              );
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // 处理图片长按保存
          if (message.message.startsWith('image:')) {
            final imageUrl = message.message.substring(6);
            _showImageSaveOptions(imageUrl);
          }
        },
      );

    // 设置User Agent
    final userAgent = AppConfig.getUserAgent();
    if (userAgent.isNotEmpty) {
      controller.setUserAgent(userAgent);
    }

    // 加载HTML内容
    if (widget.source.loadWithBaseUrl) {
      controller.loadHtmlString(htmlContent, baseUrl: baseUrl);
    } else {
      controller.loadHtmlString(htmlContent);
    }

    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.1),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  /// 注入图片长按脚本
  void _injectImageLongPressScript(WebViewController controller) {
    controller.runJavaScript('''
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

  /// 构建文本内容显示
  Widget _buildTextContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.article.pubDate != null && widget.article.pubDate!.isNotEmpty) ...[
            Text(
              '发布时间: ${widget.article.pubDate}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.article.image != null && widget.article.image!.isNotEmpty) ...[
            Center(
              child: Image.network(
                widget.article.image!,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          // 使用Html widget显示HTML内容，或Text显示纯文本
          if (_content != null && _content!.isNotEmpty)
            _isHtmlContent(_content!)
                ? Html(
                    data: _content!,
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(16),
                        lineHeight: const LineHeight(1.6),
                      ),
                    },
                  )
                : Text(
                    _content!,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  )
          else
            const Text(
              '暂无内容',
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
        ],
      ),
    );
  }

  /// 检查内容是否为HTML格式
  bool _isHtmlContent(String content) {
    return content.contains('<html') ||
        content.contains('<div') ||
        content.contains('<p>') ||
        content.contains('<br') ||
        content.contains('<img') ||
        content.contains('<a href');
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
              onTap: () async {
                Navigator.pop(context);
                await _saveImage(imageUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('在浏览器中打开'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final uri = Uri.parse(imageUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('打开失败: $e')),
                    );
                  }
                }
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
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final directory = await getApplicationDocumentsDirectory();
        final imageDir = Directory('${directory.path}/images');
        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }
        
        final fileName = imageUrl.split('/').last.split('?').first;
        final file = File('${imageDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('图片已保存: ${file.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}

