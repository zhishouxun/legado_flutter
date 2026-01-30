import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';

/// Markdown查看器页面
/// 用于显示更新日志、许可证、免责声明、隐私政策等Markdown文件
class MarkdownViewerPage extends StatefulWidget {
  final String title;
  final String assetPath;

  const MarkdownViewerPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<MarkdownViewerPage> createState() => _MarkdownViewerPageState();
}

class _MarkdownViewerPageState extends State<MarkdownViewerPage> {
  String _content = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final content = await rootBundle.loadString(widget.assetPath);
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载文件失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isLoading || _errorMessage != null
                ? null
                : () => _shareContent(),
            tooltip: '分享',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Markdown(
                  data: _content,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 16, height: 1.6),
                    h1: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    h2: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    h3: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    h4: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    code: TextStyle(
                      fontSize: 14,
                      backgroundColor: Colors.grey[200],
                      fontFamily: 'monospace',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    blockquote: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                    listBullet: const TextStyle(fontSize: 16),
                    tableHead: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    tableBody: const TextStyle(fontSize: 16),
                  ),
                ),
    );
  }

  Future<void> _shareContent() async {
    try {
      await Share.share(
        _content,
        subject: widget.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }
}
