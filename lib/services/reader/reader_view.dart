import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/page_range.dart';
import 'reading_position_manager.dart';
import 'reader_painter.dart';
import 'reader_controller.dart';

/// 阅读器视图组件 (参考Gemini文档: 渲染组件 ReaderView.md)
///
/// 使用PageView + CustomPaint实现高性能阅读器
/// 支持手势翻页、点击区域识别
class ReaderView extends StatefulWidget {
  /// 阅读控制器
  final ReaderController controller;

  /// 章节标题(可选)
  final String? chapterTitle;

  /// 点击中间区域回调(通常用于显示菜单)
  final VoidCallback? onTapCenter;

  /// 是否显示高级信息(电池、时间等)
  final bool showAdvancedInfo;

  const ReaderView({
    Key? key,
    required this.controller,
    this.chapterTitle,
    this.onTapCenter,
    this.showAdvancedInfo = false,
  }) : super(key: key);

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.controller.state.currentPage,
    );

    // 监听控制器状态变化
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;

    setState(() {
      // 如果页码变化，跳转到新页面
      if (_pageController.hasClients) {
        final targetPage = widget.controller.state.currentPage;
        if (_pageController.page?.round() != targetPage) {
          _pageController.jumpToPage(targetPage);
        }
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;

    // 加载中
    if (state.isPaginating) {
      return Container(
        color: widget.controller.config.backgroundColor,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 错误
    if (state.hasError) {
      return Container(
        color: widget.controller.config.backgroundColor,
        child: Center(
          child: Text(
            '分页失败: ${state.error}',
            style: TextStyle(
              color: widget.controller.config.textColor,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // 无内容
    if (state.pages.isEmpty) {
      return Container(
        color: widget.controller.config.backgroundColor,
        child: Center(
          child: Text(
            '暂无内容',
            style: TextStyle(
              color: widget.controller.config.textColor,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // 正常显示
    return _buildPageView(state);
  }

  /// 构建PageView
  Widget _buildPageView(PaginationState state) {
    return GestureDetector(
      onTapUp: (details) => _handleTap(details, context),
      child: PageView.builder(
        controller: _pageController,
        itemCount: state.pages.length,
        onPageChanged: (index) {
          widget.controller.goToPage(index);
        },
        itemBuilder: (context, index) {
          return _buildPage(index, state);
        },
      ),
    );
  }

  /// 构建单个页面
  Widget _buildPage(int index, PaginationState state) {
    final range = state.pages[index];
    final pageContent = range.getContent(state.content);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.showAdvancedInfo) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: AdvancedReaderPainter(
              content: pageContent,
              config: widget.controller.config,
              chapterTitle: widget.chapterTitle,
              currentPageIndex: index,
              totalPages: state.totalPages,
              batteryLevel: _getBatteryLevel(),
              currentTime: DateTime.now(),
            ),
          );
        } else {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: ReaderPainter(
              content: pageContent,
              config: widget.controller.config,
              currentPageIndex: index,
              totalPages: state.totalPages,
            ),
          );
        }
      },
    );
  }

  /// 处理点击事件 (参考Gemini文档的点击区域识别)
  ///
  /// Legado用户习惯:
  /// - 左侧1/3: 上一页
  /// - 右侧1/3: 下一页
  /// - 中间1/3: 显示菜单
  void _handleTap(TapUpDetails details, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;

    if (tapX < screenWidth / 3) {
      // 左侧 - 上一页
      widget.controller.previousPage();
    } else if (tapX > screenWidth * 2 / 3) {
      // 右侧 - 下一页
      widget.controller.nextPage();
    } else {
      // 中间 - 显示菜单
      widget.onTapCenter?.call();
    }
  }

  /// 获取电池电量(0.0-1.0)
  double _getBatteryLevel() {
    // TODO: 实际项目中使用battery_plus插件获取
    return 0.8;
  }
}

/// 简化版阅读器视图
///
/// 直接传入分页数据和配置，无需ReaderController
class SimpleReaderView extends StatefulWidget {
  final String fullContent;
  final List<PageRange> pages;
  final ReadingConfig config;
  final int initialPage;
  final void Function(int page)? onPageChanged;
  final VoidCallback? onTapCenter;

  const SimpleReaderView({
    Key? key,
    required this.fullContent,
    required this.pages,
    required this.config,
    this.initialPage = 0,
    this.onPageChanged,
    this.onTapCenter,
  }) : super(key: key);

  @override
  State<SimpleReaderView> createState() => _SimpleReaderViewState();
}

class _SimpleReaderViewState extends State<SimpleReaderView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return Container(
        color: widget.config.backgroundColor,
        child: const Center(child: Text('暂无内容')),
      );
    }

    return GestureDetector(
      onTapUp: (details) => _handleTap(details, context),
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.pages.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
          widget.onPageChanged?.call(index);
        },
        itemBuilder: (context, index) {
          final range = widget.pages[index];
          final pageContent = range.getContent(widget.fullContent);

          return CustomPaint(
            painter: ReaderPainter(
              content: pageContent,
              config: widget.config,
              currentPageIndex: index,
              totalPages: widget.pages.length,
            ),
          );
        },
      ),
    );
  }

  void _handleTap(TapUpDetails details, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;

    if (tapX < screenWidth / 3) {
      // 上一页
      if (_currentPage > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (tapX > screenWidth * 2 / 3) {
      // 下一页
      if (_currentPage < widget.pages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // 显示菜单
      widget.onTapCenter?.call();
    }
  }
}

/// 音量键翻页支持
class VolumeKeyHandler {
  /// 启用音量键翻页
  ///
  /// [onVolumeUp] 音量+回调
  /// [onVolumeDown] 音量-回调
  static void enable({
    required VoidCallback onVolumeUp,
    required VoidCallback onVolumeDown,
  }) {
    // TODO: 使用volume_controller插件实现
    // 这需要监听物理按键事件
  }

  /// 禁用音量键翻页
  static void disable() {
    // TODO: 移除音量键监听
  }
}
