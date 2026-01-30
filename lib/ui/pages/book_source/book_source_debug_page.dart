import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_source.dart';
import '../../../services/source/book_source_service.dart';
import '../../../services/source/book_source_debug_service.dart';
import 'debug_result_list.dart';
import 'debug_input_widget.dart';
import 'debug_help_widget.dart';

/// 书源调试页面
class BookSourceDebugPage extends ConsumerStatefulWidget {
  final String sourceUrl;

  const BookSourceDebugPage({
    super.key,
    required this.sourceUrl,
  });

  @override
  ConsumerState<BookSourceDebugPage> createState() => _BookSourceDebugPageState();
}

class _BookSourceDebugPageState extends ConsumerState<BookSourceDebugPage> {
  BookSource? _source;
  bool _isLoading = false;
  final List<DebugMessage> _messages = [];
  String? _searchSrc;
  String? _bookSrc;
  String? _tocSrc;
  String? _contentSrc;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  Future<void> _loadSource() async {
    try {
      final source = await BookSourceService.instance.getBookSourceByUrl(widget.sourceUrl);
      setState(() {
        _source = source;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载书源失败: $e')),
        );
      }
    }
  }

  void _addMessage(DebugMessage message) {
    setState(() {
      _messages.add(message);
    });
  }

  void _clearMessages() {
    setState(() {
      _messages.clear();
      _searchSrc = null;
      _bookSrc = null;
      _tocSrc = null;
      _contentSrc = null;
    });
  }

  void _onDebugComplete() {
    setState(() {
      _isLoading = false;
    });
  }

  void _onDebugStart() {
    setState(() {
      _isLoading = true;
    });
  }


  void _showHtmlDialog(String title, String? html) {
    if (html == null || html.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无HTML源码')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: SingleChildScrollView(
            child: SelectableText(
              html,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_source == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('书源调试')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('调试: ${_source!.bookSourceName}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'search':
                  _showHtmlDialog('搜索页HTML', _searchSrc);
                  break;
                case 'book':
                  _showHtmlDialog('详情页HTML', _bookSrc);
                  break;
                case 'toc':
                  _showHtmlDialog('目录页HTML', _tocSrc);
                  break;
                case 'content':
                  _showHtmlDialog('正文页HTML', _contentSrc);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20),
                    SizedBox(width: 8),
                    Text('搜索页HTML'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'book',
                child: Row(
                  children: [
                    Icon(Icons.book, size: 20),
                    SizedBox(width: 8),
                    Text('详情页HTML'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'toc',
                child: Row(
                  children: [
                    Icon(Icons.list, size: 20),
                    SizedBox(width: 8),
                    Text('目录页HTML'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'content',
                child: Row(
                  children: [
                    Icon(Icons.article, size: 20),
                    SizedBox(width: 8),
                    Text('正文页HTML'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 输入区域
          DebugInputWidget(
            source: _source!,
            onDebug: (key) {
              _clearMessages();
              _onDebugStart();
              _startDebug(key);
            },
          ),
          // 帮助提示区域
          DebugHelpWidget(
            source: _source!,
            onSelectKey: (key) {
              _clearMessages();
              _onDebugStart();
              _startDebug(key);
            },
          ),
          const Divider(),
          // 调试结果列表
          Expanded(
            child: Stack(
              children: [
                DebugResultList(messages: _messages),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDebug(String key) async {
    final debugService = BookSourceDebugService.instance;
    debugService.clear();
    
    // 设置回调
    debugService.onMessage = (state, message) {
      _addMessage(DebugMessage(
        state: state,
        message: message,
        timestamp: DateTime.now(),
      ));
      
      // 保存HTML源码
      if (state == 10) {
        setState(() {
          _searchSrc = debugService.getSearchSrc();
        });
      } else if (state == 20) {
        setState(() {
          _bookSrc = debugService.getBookSrc();
        });
      } else if (state == 30) {
        setState(() {
          _tocSrc = debugService.getTocSrc();
        });
      } else if (state == 40) {
        setState(() {
          _contentSrc = debugService.getContentSrc();
        });
      }
      
      // 调试完成
      if (state == 1000 || state == -1) {
        _onDebugComplete();
      }
    };
    
    // 开始调试
    await debugService.startDebug(_source!, key);
  }
}

/// 调试消息
class DebugMessage {
  final int state; // 状态：1=进行中, 1000=完成, -1=错误
  final String message;
  final DateTime timestamp;

  DebugMessage({
    required this.state,
    required this.message,
    required this.timestamp,
  });
}

