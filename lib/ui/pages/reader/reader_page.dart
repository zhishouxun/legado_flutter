import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute, ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_chapter.dart';
import '../../../data/models/book_source.dart';
import '../../../services/book/book_service.dart';
import '../../../services/source/book_source_service.dart';
import '../../../services/book/local_book_service.dart';
import '../../../services/reader/cache_service.dart';
import '../../../services/reader/content_processor.dart';
import '../../../providers/book_provider.dart';
import '../../../config/app_config.dart';
import '../../../core/constants/app_status.dart';
import '../../../core/constants/prefer_key.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../utils/app_log.dart';
import '../../../services/read_record_service.dart';
import '../../../services/receiver/time_battery_listener.dart';
import '../../../services/receiver/reader_controller.dart';
import '../../../utils/helpers/book_extensions.dart';
import 'models/text_chapter.dart';
import 'models/text_page.dart';
import 'reader_settings_page.dart';
import 'chapter_list_page.dart';
import 'more_settings_dialog.dart';
import 'tts_control_widget.dart';
import 'search_content_page.dart';
import '../bookmark/bookmark_dialog.dart';
import '../../../data/models/bookmark.dart';
import 'dict_dialog.dart';
import 'auto_read_dialog.dart';
import 'content_edit_dialog.dart';
import 'effective_replaces_dialog.dart';
import '../../../services/media/tts_service.dart';
import '../../../services/reader/chapter_layout_provider.dart';
import 'widgets/simulation_page_turn.dart';

part "reader_logic.dart";
part "reader_view_scroll.dart";
part "reader_view_paged.dart";
part "reader_widgets.dart";

/// 阅读器页面
class ReaderPage extends ConsumerStatefulWidget {
  final Book book;
  final int initialChapterIndex;

  const ReaderPage({
    super.key,
    required this.book,
    this.initialChapterIndex = 0,
  });

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late int _currentChapterIndex;
  int _currentPageIndex = 0;
  List<BookChapter> _chapters = [];
  final Map<int, String> _chapterContents = {};
  final Map<int, List<String>> _chapterPages = {};
  bool _isLoading = true;
  bool _showMenu = false;
  BookSource? _bookSource;
  ReadConfig _readConfig = ReadConfig();

  TextChapter? _prevTextChapter;
  TextChapter? _curTextChapter;
  TextChapter? _nextTextChapter;

  final Set<int> _loadingChapters = {};
  final Map<int, ScrollController> _chapterScrollControllers = {};

  Offset? _touchStart;
  DateTime _currentTime = DateTime.now();
  int _currentBatteryLevel = 100;
  String _searchKeyword = "";
  int _searchChapterIndex = -1;
  int _searchPosition = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentChapterIndex = widget.initialChapterIndex;
    // 翻页模式下，PageController 控制的是当前章节内的页面索引，初始为0
    _pageController = PageController(initialPage: 0);
    
    // 从书籍加载阅读配置
    _readConfig = widget.book.readConfig ?? ReadConfig();
    
    // 根据全局主题模式调整配置颜色
    final isNightTheme = AppConfig.isNightTheme();
    if (isNightTheme && _readConfig.backgroundColor != 0xFF000000) {
      // 全局是夜间模式，但配置不是夜间，调整为夜间
      _readConfig = _readConfig.copyWith(
        backgroundColor: 0xFF000000,
        textColor: 0xFFFFFFFF,
      );
    } else if (!isNightTheme && _readConfig.backgroundColor == 0xFF000000) {
      // 全局是日间模式，但配置是夜间，调整为日间
      _readConfig = _readConfig.copyWith(
        backgroundColor: 0xFFFFFFFF,
        textColor: 0xFF000000,
      );
    }
    
    _loadChapters();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var c in _chapterScrollControllers.values) {
      c.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // 内容层：处理翻页点击
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleTap(details.localPosition),
            child: _readConfig.pageMode == AppStatus.pageModeScroll
                ? _buildScrollMode()
                : _buildPageMode(),
          ),
          // 菜单层
          _buildMenuBar(),
        ],
      ),
    );
  }

  void _handleTap(Offset position) {
    final width = MediaQuery.of(context).size.width;

    // 菜单唤起：中间区域
    if (position.dx > width / 3 && position.dx < width * 2 / 3) {
      setState(() => _showMenu = !_showMenu);
    }
    // 上一页：左侧
    else if (position.dx <= width / 3) {
      _switchToPrevious();
    }
    // 下一页：右侧
    else {
      _switchToNext();
    }
  }

  void _switchToPrevious() {
    if (_readConfig.pageMode == AppStatus.pageModeScroll) {
      _handleScrollPageTap(false);
    } else {
      if (_currentPageIndex > 0) {
        _pageController.previousPage(
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _switchToPreviousChapter();
      }
    }
  }

  void _switchToNext() {
    if (_readConfig.pageMode == AppStatus.pageModeScroll) {
      _handleScrollPageTap(true);
    } else {
      // 获取当前章节的实际页面数，与 _buildPageMode 使用相同的逻辑
      int pageCount = 1;
      final textChapter = _curTextChapter;
      if (textChapter != null &&
          textChapter.pages.isNotEmpty &&
          textChapter.chapterIndex == _currentChapterIndex) {
        pageCount = textChapter.pages.length;
      } else {
        final pages = _chapterPages[_currentChapterIndex];
        if (pages != null && pages.isNotEmpty) {
          pageCount = pages.length;
        }
      }
      
      if (_currentPageIndex < pageCount - 1) {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _switchToNextChapter();
      }
    }
  }
}
