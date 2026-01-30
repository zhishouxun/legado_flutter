import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_chapter.dart';
import '../../../data/models/manga_footer_config.dart';
import '../../../services/book/book_service.dart';
import '../../../services/media/manga_service.dart';
import '../../../services/read_record_service.dart';
import '../../../config/app_config.dart';
import '../../../utils/app_log.dart';
import 'chapter_list_page.dart';
import 'manga_color_filter_dialog.dart';
import 'manga_epaper_dialog.dart';
import 'manga_footer_setting_dialog.dart';
import '../../widgets/reader/manga_image_widget.dart';
import '../../widgets/common/custom_switch_list_tile.dart';
import '../bookshelf/book_info/book_info_page.dart';
import '../bookshelf/book_info/change_source_dialog.dart';

/// 漫画阅读页面
class MangaReaderPage extends ConsumerStatefulWidget {
  final Book book;
  final int initialChapterIndex;

  const MangaReaderPage({
    super.key,
    required this.book,
    this.initialChapterIndex = 0,
  });

  @override
  ConsumerState<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends ConsumerState<MangaReaderPage>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late int _currentChapterIndex;
  int _currentImageIndex = 0;
  List<BookChapter> _chapters = [];
  final Map<int, List<String>> _chapterImages = {}; // 章节索引 -> 图片URL列表
  final Set<int> _loadingChapters = {}; // 正在加载的章节索引
  final Set<int> _preloadingChapters = {}; // 正在预加载的章节索引
  bool _isLoading = true;
  bool _showMenu = false;
  Timer? _autoPageTimer; // 自动翻页定时器
  MangaFooterConfig? _footerConfig; // 页脚配置
  ScrollController? _webtoonScrollController; // Webtoon模式滚动控制器
  final Map<int, double> _imageLoadProgress = {}; // 图片加载进度（章节索引 -> 进度0-1）

  // 阅读时长记录（参考项目：ReadManga.kt）
  int _readStartTime = 0; // 开始阅读时间（毫秒时间戳）
  Timer? _readTimeTimer; // 阅读时长定时器
  static const Duration _readTimeSaveInterval =
      Duration(seconds: 30); // 每30秒保存一次

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentChapterIndex = widget.initialChapterIndex;
    _pageController = PageController();
    _initReadTimeRecord();
    _loadFooterConfig();
    _loadChapters();
    _startAutoPageIfEnabled();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用进入后台时，保存阅读时长并暂停记录
    // 当应用回到前台时，恢复记录
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 应用进入后台：保存当前阅读时长
      _saveReadTime();
    } else if (state == AppLifecycleState.resumed) {
      // 应用回到前台：恢复阅读时长记录
      if (AppConfig.getEnableReadRecord()) {
        _readStartTime = DateTime.now().millisecondsSinceEpoch;
      }
    }
  }

  /// 初始化阅读时长记录
  /// 参考项目：ReadManga.upReadTime
  void _initReadTimeRecord() {
    if (!AppConfig.getEnableReadRecord()) {
      return;
    }

    // 记录开始阅读时间
    _readStartTime = DateTime.now().millisecondsSinceEpoch;

    // 启动定时器，定期保存阅读时长
    _readTimeTimer = Timer.periodic(_readTimeSaveInterval, (timer) {
      _saveReadTime();
    });
  }

  /// 保存阅读时长
  /// 参考项目：ReadManga.upReadTime
  Future<void> _saveReadTime() async {
    if (!AppConfig.getEnableReadRecord()) {
      return;
    }

    if (_readStartTime == 0) {
      return;
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final readTime = now - _readStartTime;

      if (readTime > 0) {
        // 增加阅读时长
        await ReadRecordService.instance.addReadTime(
          widget.book.name,
          readTime,
        );

        // 重置开始时间
        _readStartTime = now;
      }
    } catch (e) {
      AppLog.instance.put('保存阅读时长失败: $e', error: e);
    }
  }

  /// 更新最后阅读时间（不增加阅读时长）
  Future<void> _updateLastRead() async {
    if (!AppConfig.getEnableReadRecord()) {
      return;
    }

    try {
      await ReadRecordService.instance.updateLastRead(widget.book.name);
    } catch (e) {
      AppLog.instance.put('更新最后阅读时间失败: $e', error: e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // 保存阅读时长
    _saveReadTime();

    // 取消定时器
    _readTimeTimer?.cancel();
    _readTimeTimer = null;
    _autoPageTimer?.cancel();
    _autoPageTimer = null;

    _pageController.dispose();
    _webtoonScrollController?.dispose();
    super.dispose();
  }

  /// 加载页脚配置
  void _loadFooterConfig() {
    final configStr = AppConfig.getMangaFooterConfig();
    _footerConfig = MangaFooterConfig.fromJsonString(configStr);
  }

  Future<void> _loadChapters() async {
    try {
      final chapters = await BookService.instance.getChapterList(widget.book);
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoading = false;
        });
        // 加载当前章节的图片（会自动预加载相邻章节）
        if (_chapters.isNotEmpty) {
          _loadChapterImages(_currentChapterIndex);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 加载章节图片（参考项目：ReadManga.loadContent）
  Future<void> _loadChapterImages(int chapterIndex,
      {bool isPreload = false}) async {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return;
    if (_chapterImages.containsKey(chapterIndex)) return; // 已加载
    if (_loadingChapters.contains(chapterIndex)) return; // 正在加载
    if (isPreload && _preloadingChapters.contains(chapterIndex)) {
      return; // 正在预加载
    }

    if (isPreload) {
      _preloadingChapters.add(chapterIndex);
    } else {
      _loadingChapters.add(chapterIndex);
    }

    final chapter = _chapters[chapterIndex];

    try {
      // 更新加载进度
      if (mounted && !isPreload) {
        setState(() {
          _imageLoadProgress[chapterIndex] = 0.0;
        });
      }

      final images =
          await MangaService.instance.getChapterImages(chapter, widget.book);

      if (mounted) {
        setState(() {
          _chapterImages[chapterIndex] = images;
          _loadingChapters.remove(chapterIndex);
          _preloadingChapters.remove(chapterIndex);
          _imageLoadProgress[chapterIndex] = 1.0;
        });

        // 清理内存：限制缓存的章节数量
        _cleanupImageCache();

        // 预加载相邻章节的图片（只在非预加载时触发）
        if (!isPreload) {
          _preloadAdjacentChapters(chapterIndex);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingChapters.remove(chapterIndex);
          _preloadingChapters.remove(chapterIndex);
          _imageLoadProgress.remove(chapterIndex);
        });
      }
      AppLog.instance.put('加载章节图片失败: ${chapter.title}', error: e);
    }
  }

  /// 清理图片缓存（限制内存使用）
  void _cleanupImageCache() {
    final retainNum = AppConfig.getImageRetainNum();
    if (retainNum <= 0) return; // 0表示不限制

    final currentIndex = _currentChapterIndex;
    final keysToRemove = <int>[];

    // 找出需要清理的章节
    for (final key in _chapterImages.keys) {
      final distance = (key - currentIndex).abs();
      if (distance > retainNum) {
        keysToRemove.add(key);
      }
    }

    // 清理缓存
    if (keysToRemove.isNotEmpty) {
      setState(() {
        for (final key in keysToRemove) {
          _chapterImages.remove(key);
          _imageLoadProgress.remove(key);
        }
      });
      AppLog.instance.put('清理了 ${keysToRemove.length} 个章节的图片缓存');
    }
  }

  /// 预加载相邻章节的图片（参考项目：ReadManga预加载机制）
  void _preloadAdjacentChapters(int currentIndex) {
    final preDownloadNum = AppConfig.getMangaPreDownloadNum();
    if (preDownloadNum <= 0) {
      // 如果预下载数量为0，只预加载相邻章节
      _preloadAdjacentChaptersOnly(currentIndex);
      return;
    }

    // 限制并发预加载数量（最多同时预加载3个章节）
    int concurrentCount = 0;
    const maxConcurrent = 3;

    // 预加载后续章节（根据配置的数量）
    for (int i = 1;
        i <= preDownloadNum && currentIndex + i < _chapters.length;
        i++) {
      if (concurrentCount >= maxConcurrent) break;

      final nextIndex = currentIndex + i;
      if (!_chapterImages.containsKey(nextIndex) &&
          !_loadingChapters.contains(nextIndex) &&
          !_preloadingChapters.contains(nextIndex)) {
        _loadChapterImages(nextIndex, isPreload: true);
        concurrentCount++;
      }
    }

    // 预加载前面的章节（最多5章）
    for (int i = 1; i <= 5 && currentIndex - i >= 0; i++) {
      if (concurrentCount >= maxConcurrent) break;

      final prevIndex = currentIndex - i;
      if (!_chapterImages.containsKey(prevIndex) &&
          !_loadingChapters.contains(prevIndex) &&
          !_preloadingChapters.contains(prevIndex)) {
        _loadChapterImages(prevIndex, isPreload: true);
        concurrentCount++;
      }
    }
  }

  /// 只预加载相邻章节（上一章和下一章）
  void _preloadAdjacentChaptersOnly(int currentIndex) {
    // 预加载上一章
    if (currentIndex > 0) {
      final prevIndex = currentIndex - 1;
      if (!_chapterImages.containsKey(prevIndex) &&
          !_loadingChapters.contains(prevIndex)) {
        _loadChapterImages(prevIndex);
      }
    }

    // 预加载下一章
    if (currentIndex < _chapters.length - 1) {
      final nextIndex = currentIndex + 1;
      if (!_chapterImages.containsKey(nextIndex) &&
          !_loadingChapters.contains(nextIndex)) {
        _loadChapterImages(nextIndex);
      }
    }
  }

  void _onImagePageChanged(int index) {
    setState(() {
      _currentImageIndex = index;
    });

    // 更新阅读进度
    _updateReadingProgress();

    // 如果到达最后一页，预加载下一章
    final images = _chapterImages[_currentChapterIndex] ?? [];
    if (index == images.length - 1) {
      _preloadAdjacentChapters(_currentChapterIndex);
    }
  }

  void _onChapterChanged(int newChapterIndex) {
    if (newChapterIndex < 0 || newChapterIndex >= _chapters.length) return;

    setState(() {
      _currentChapterIndex = newChapterIndex;
      _currentImageIndex = 0;
    });

    // 加载新章节的图片
    _loadChapterImages(newChapterIndex);

    // 跳转到新章节的第一页
    if (AppConfig.getEnableMangaHorizontalScroll()) {
      // Webtoon模式：滚动到顶部
      if (_webtoonScrollController?.hasClients ?? false) {
        _webtoonScrollController!.jumpTo(0);
      }
    } else {
      // 普通模式：跳转到第一页
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }

    // 更新阅读进度和最后阅读时间
    _updateReadingProgress();
    _updateLastRead();
  }

  void _updateReadingProgress() {
    if (_currentChapterIndex < _chapters.length) {
      final chapter = _chapters[_currentChapterIndex];
      BookService.instance.updateReadingProgress(
        widget.book.bookUrl,
        _currentChapterIndex,
        _currentImageIndex,
        chapter.title,
      );
    }
  }

  void _showChapterList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterListPage(
          chapters: _chapters,
          currentChapterIndex: _currentChapterIndex,
          onChapterSelected: (index) {
            Navigator.pop(context);
            _onChapterChanged(index);
          },
        ),
      ),
    );
  }

  /// 构建图片手势检测器
  Widget _buildImageGestureDetector(String imageUrl, int index) {
    final disableClickScroll = AppConfig.getDisableClickScroll();

    return GestureDetector(
      onTap: disableClickScroll ? null : _toggleMenu,
      onTapDown: disableClickScroll
          ? (details) {
              // 点击左侧/右侧区域切换页面
              final screenWidth = MediaQuery.of(context).size.width;
              final tapX = details.globalPosition.dx;
              final leftRegion = screenWidth * 0.3; // 左侧30%区域
              final rightRegion = screenWidth * 0.7; // 右侧30%区域

              if (tapX < leftRegion) {
                // 点击左侧，上一页
                _previousPage();
              } else if (tapX > rightRegion) {
                // 点击右侧，下一页
                _nextPage();
              } else {
                // 点击中间，显示/隐藏菜单
                _toggleMenu();
              }
            }
          : null,
      onHorizontalDragEnd: (details) {
        // 左右滑动切换章节
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            // 向右滑动，上一章
            if (_currentChapterIndex > 0) {
              _onChapterChanged(_currentChapterIndex - 1);
            }
          } else if (details.primaryVelocity! < 0) {
            // 向左滑动，下一章
            if (_currentChapterIndex < _chapters.length - 1) {
              _onChapterChanged(_currentChapterIndex + 1);
            }
          }
        }
      },
      onDoubleTap: () {
        // 双击切换菜单
        _toggleMenu();
      },
      onLongPress: () {
        // 长按显示菜单
        if (!_showMenu) {
          _toggleMenu();
        }
      },
      child: Center(
        child: _buildImageWithScale(imageUrl, index),
      ),
    );
  }

  /// 上一页
  void _previousPage() {
    if (_currentImageIndex > 0) {
      if (_pageController.hasClients) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (_currentChapterIndex > 0) {
      _onChapterChanged(_currentChapterIndex - 1);
    }
  }

  /// 下一页
  void _nextPage() {
    final images = _chapterImages[_currentChapterIndex] ?? [];
    if (_currentImageIndex < images.length - 1) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (_currentChapterIndex < _chapters.length - 1) {
      _onChapterChanged(_currentChapterIndex + 1);
    } else {
      // 已到最后一页，停止自动翻页
      _stopAutoPage();
    }
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
      // 显示菜单时暂停自动翻页，隐藏时恢复
      if (_showMenu) {
        _stopAutoPage();
      } else {
        _startAutoPageIfEnabled();
      }
    });
  }

  /// 开始自动翻页（如果启用）
  void _startAutoPageIfEnabled() {
    if (_showMenu) return; // 菜单显示时不自动翻页

    final speed = AppConfig.getMangaAutoPageSpeed();
    if (speed > 0) {
      final duration = Duration(seconds: speed);
      _autoPageTimer?.cancel();
      _autoPageTimer = Timer.periodic(duration, (timer) {
        if (!_showMenu && mounted) {
          _autoNextPage();
        }
      });
    }
  }

  /// 停止自动翻页
  void _stopAutoPage() {
    _autoPageTimer?.cancel();
    _autoPageTimer = null;
  }

  /// 自动翻到下一页
  void _autoNextPage() {
    final images = _chapterImages[_currentChapterIndex] ?? [];
    if (_currentImageIndex < images.length - 1) {
      // 下一页
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (_currentChapterIndex < _chapters.length - 1) {
      // 下一章
      _onChapterChanged(_currentChapterIndex + 1);
    } else {
      // 已到最后一页，停止自动翻页
      _stopAutoPage();
    }
  }

  /// 显示颜色滤镜设置对话框
  void _showColorFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MangaColorFilterDialog(
        onConfigChanged: (config) {
          setState(() {}); // 刷新图片显示
        },
      ),
    );
  }

  /// 显示电子墨水设置对话框
  void _showEpaperDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MangaEpaperDialog(
        onThresholdChanged: (threshold) {
          setState(() {}); // 刷新图片显示
        },
      ),
    );
  }

  /// 显示页脚设置对话框
  void _showFooterSettingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MangaFooterSettingDialog(
        onConfigChanged: (config) {
          setState(() {
            _footerConfig = config;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chapters.isEmpty
              ? const Center(
                  child: Text('暂无章节', style: TextStyle(color: Colors.white)))
              : _buildReader(),
    );
  }

  Widget _buildReader() {
    final images = _chapterImages[_currentChapterIndex] ?? [];
    final isWebtoonMode = AppConfig.getEnableMangaHorizontalScroll();

    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '加载中: ${_chapters[_currentChapterIndex].title}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    // Webtoon模式：垂直滚动列表
    if (isWebtoonMode) {
      return _buildWebtoonReader(images);
    }

    // 普通模式：分页查看
    return Stack(
      children: [
        // 图片查看器
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: _onImagePageChanged,
          itemBuilder: (context, index) {
            return _buildImageGestureDetector(
              images[index],
              index,
            );
          },
        ),
        // 菜单栏
        if (_showMenu) _buildMenu(images.length),
        // 页脚/进度指示器
        if (!(_footerConfig?.hideFooter ?? false) && !_showMenu)
          _buildFooter(images.length),
      ],
    );
  }

  /// 构建页脚
  Widget _buildFooter(int imageCount) {
    final config = _footerConfig ?? MangaFooterConfig();
    final chapter = _chapters[_currentChapterIndex];
    final progress =
        ((_currentImageIndex + 1) / imageCount * 100).toStringAsFixed(1);

    final List<String> footerItems = [];

    if (!config.hideChapterLabel && !config.hideChapter) {
      footerItems.add('章节: ${_currentChapterIndex + 1}');
    } else if (!config.hideChapter) {
      footerItems.add('${_currentChapterIndex + 1}');
    }

    if (!config.hidePageNumberLabel && !config.hidePageNumber) {
      footerItems.add('页码: ${_currentImageIndex + 1}/$imageCount');
    } else if (!config.hidePageNumber) {
      footerItems.add('${_currentImageIndex + 1}/$imageCount');
    }

    if (!config.hideProgressRatioLabel && !config.hideProgressRatio) {
      footerItems.add('进度: $progress%');
    } else if (!config.hideProgressRatio) {
      footerItems.add('$progress%');
    }

    if (!config.hideChapterName) {
      footerItems.add(chapter.title);
    }

    if (footerItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          footerItems.join(' • '),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          textAlign: config.footerOrientation == MangaFooterAlignment.center
              ? TextAlign.center
              : TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildMenu(int imageCount) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部栏
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                widget.book.name,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    _showSettingsMenu();
                  },
                  tooltip: '设置',
                ),
                IconButton(
                  icon: const Icon(Icons.list, color: Colors.white),
                  onPressed: _showChapterList,
                  tooltip: '章节列表',
                ),
              ],
            ),
            // 控制按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 上一章
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: _currentChapterIndex > 0
                        ? () => _onChapterChanged(_currentChapterIndex - 1)
                        : null,
                    tooltip: '上一章',
                  ),
                  // 上一页
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: _currentImageIndex > 0
                        ? () {
                            if (_pageController.hasClients) {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          }
                        : null,
                    tooltip: '上一页',
                  ),
                  // 下一页
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: _currentImageIndex < imageCount - 1
                        ? () {
                            if (_pageController.hasClients) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          }
                        : _currentChapterIndex < _chapters.length - 1
                            ? () => _onChapterChanged(_currentChapterIndex + 1)
                            : null,
                    tooltip: '下一页',
                  ),
                  // 下一章
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: _currentChapterIndex < _chapters.length - 1
                        ? () => _onChapterChanged(_currentChapterIndex + 1)
                        : null,
                    tooltip: '下一章',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示设置菜单
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 显示设置
              _buildMenuSection('显示设置', [
                ListTile(
                  leading: const Icon(Icons.palette, color: Colors.white),
                  title:
                      const Text('颜色滤镜', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showColorFilterDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.contrast, color: Colors.white),
                  title:
                      const Text('电子墨水', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showEpaperDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_fields, color: Colors.white),
                  title:
                      const Text('页脚设置', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showFooterSettingDialog();
                  },
                ),
                CustomSwitchListTile(
                  secondary:
                      const Icon(Icons.filter_b_and_w, color: Colors.white),
                  title:
                      const Text('灰度模式', style: TextStyle(color: Colors.white)),
                  value: AppConfig.getEnableMangaGray(),
                  onChanged: (value) {
                    AppConfig.setEnableMangaGray(value);
                    setState(() {}); // 刷新图片显示
                  },
                ),
                CustomSwitchListTile(
                  secondary: const Icon(Icons.swap_horiz, color: Colors.white),
                  title: const Text('横向滚动模式',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Webtoon模式',
                      style: TextStyle(color: Colors.white70)),
                  value: AppConfig.getEnableMangaHorizontalScroll(),
                  onChanged: (value) {
                    AppConfig.setEnableMangaHorizontalScroll(value);
                    setState(() {}); // 刷新显示模式
                  },
                ),
              ]),
              const Divider(color: Colors.white24),
              // 阅读设置
              _buildMenuSection('阅读设置', [
                ListTile(
                  leading: Icon(
                    AppConfig.getMangaAutoPageSpeed() > 0
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  title: Text(
                    AppConfig.getMangaAutoPageSpeed() > 0 ? '停止自动翻页' : '开启自动翻页',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: AppConfig.getMangaAutoPageSpeed() > 0
                      ? Text(
                          '当前速度: ${AppConfig.getMangaAutoPageSpeed()}秒/页',
                          style: const TextStyle(color: Colors.white70),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (AppConfig.getMangaAutoPageSpeed() > 0) {
                      AppConfig.setMangaAutoPageSpeed(0);
                      _stopAutoPage();
                    } else {
                      _showAutoPageSpeedDialog();
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.white),
                  title: const Text('预下载数量',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '${AppConfig.getMangaPreDownloadNum()} 章',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showPreDownloadNumDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.storage, color: Colors.white),
                  title: const Text('图片保留数量',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    AppConfig.getImageRetainNum() == 0
                        ? '不限制'
                        : '${AppConfig.getImageRetainNum()} 章',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showImageRetainNumDialog();
                  },
                ),
              ]),
              const Divider(color: Colors.white24),
              // 其他功能
              _buildMenuSection('其他功能', [
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.white),
                  title:
                      const Text('刷新章节', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _refreshCurrentChapter();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.white),
                  title:
                      const Text('书籍信息', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showBookInfo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.white),
                  title:
                      const Text('换源', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangeSourceDialog();
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  /// 显示自动翻页速度选择对话框
  void _showAutoPageSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动翻页速度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final speed in [3, 5, 10, 15, 20, 30])
              ListTile(
                title: Text('$speed秒/页'),
                selected: AppConfig.getMangaAutoPageSpeed() == speed,
                onTap: () {
                  AppConfig.setMangaAutoPageSpeed(speed);
                  _startAutoPageIfEnabled();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 显示预下载数量设置对话框
  void _showPreDownloadNumDialog() {
    final currentNum = AppConfig.getMangaPreDownloadNum();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('预下载数量'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final num in [0, 3, 5, 10, 15, 20])
              ListTile(
                title: Text(num == 0 ? '关闭' : '$num 章'),
                selected: currentNum == num,
                onTap: () {
                  AppConfig.setMangaPreDownloadNum(num);
                  Navigator.pop(context);
                  // 如果设置了预下载，立即开始预加载
                  if (num > 0) {
                    _preloadAdjacentChapters(_currentChapterIndex);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 显示图片保留数量设置对话框
  void _showImageRetainNumDialog() {
    final currentNum = AppConfig.getImageRetainNum();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('图片保留数量'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '限制内存中缓存的章节数量，0表示不限制',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            ...([0, 5, 10, 15, 20, 30].map((num) => ListTile(
                  title: Text(num == 0 ? '不限制' : '$num 章'),
                  selected: currentNum == num,
                  onTap: () {
                    AppConfig.setImageRetainNum(num);
                    Navigator.pop(context);
                    // 立即清理缓存
                    _cleanupImageCache();
                  },
                ))),
          ],
        ),
      ),
    );
  }

  /// 刷新当前章节
  void _refreshCurrentChapter() {
    setState(() {
      _chapterImages.remove(_currentChapterIndex);
      _loadingChapters.remove(_currentChapterIndex);
    });
    _loadChapterImages(_currentChapterIndex);
  }

  /// 显示书籍信息
  void _showBookInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookInfoPage(
          bookUrl: widget.book.bookUrl,
          bookName: widget.book.name,
          author: widget.book.author,
          sourceUrl: widget.book.origin,
          coverUrl: widget.book.coverUrl,
          intro: widget.book.intro,
        ),
      ),
    );
  }

  /// 显示换源对话框
  void _showChangeSourceDialog() {
    // 导入换源对话框
    showDialog(
      context: context,
      builder: (context) => ChangeSourceDialog(
        oldBook: widget.book,
        onSourceChanged: (source, newBook, chapters) async {
          // 更新书籍信息
          try {
            await BookService.instance.updateBook(newBook);
            await BookService.instance.saveChapters(chapters);

            // 重新加载章节
            setState(() {
              _chapterImages.clear();
              _loadingChapters.clear();
            });
            await _loadChapters();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('换源成功')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('换源失败: $e')),
              );
            }
          }
        },
      ),
    );
  }

  /// 构建带缩放功能的图片
  Widget _buildImageWithScale(String imageUrl, int index) {
    final disableScale = AppConfig.getDisableMangaScale();
    final progress = _imageLoadProgress[_currentChapterIndex] ?? 0.0;
    final isLoading = _loadingChapters.contains(_currentChapterIndex) ||
        _preloadingChapters.contains(_currentChapterIndex);

    Widget imageWidget = MangaImageWidget(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
    );

    // 如果禁用缩放，直接返回图片
    if (disableScale) {
      return Stack(
        children: [
          imageWidget,
          // 加载进度指示器
          if (isLoading && progress < 1.0)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          value: progress > 0 ? progress : null),
                      if (progress > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // 启用缩放功能
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: imageWidget,
        ),
        // 加载进度指示器
        if (isLoading && progress < 1.0)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        value: progress > 0 ? progress : null),
                    if (progress > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 构建Webtoon模式阅读器（垂直滚动）
  Widget _buildWebtoonReader(List<String> images) {
    final hideTitle = AppConfig.getHideMangaTitle();

    // 初始化滚动控制器
    _webtoonScrollController ??= ScrollController()
      ..addListener(() {
        // 监听滚动位置，更新当前图片索引
        if (!_webtoonScrollController!.hasClients) return;

        final scrollPosition = _webtoonScrollController!.offset;
        final viewportHeight = MediaQuery.of(context).size.height;

        // 使用更精确的计算方式：根据每个图片的实际高度计算
        // 简化实现：使用平滑的索引计算
        double accumulatedHeight = 0;
        int estimatedIndex = 0;

        // 估算每个图片的高度（假设为视口高度的1.2倍，实际应该根据图片尺寸计算）
        final estimatedImageHeight = viewportHeight * 1.2;

        for (int i = 0; i < images.length; i++) {
          accumulatedHeight += estimatedImageHeight;
          if (scrollPosition < accumulatedHeight) {
            estimatedIndex = i;
            break;
          }
        }

        // 确保索引在有效范围内
        if (estimatedIndex >= images.length) {
          estimatedIndex = images.length - 1;
        }

        if (_currentImageIndex != estimatedIndex) {
          setState(() {
            _currentImageIndex = estimatedIndex;
          });
          _updateReadingProgress();
        }
      });

    return Stack(
      children: [
        // 垂直滚动列表
        ListView.builder(
          controller: _webtoonScrollController,
          itemCount: images.length,
          itemBuilder: (context, index) {
            return Column(
              children: [
                // 章节标题（如果未隐藏）
                if (!hideTitle && index == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.black.withOpacity(0.5),
                    child: Text(
                      _chapters[_currentChapterIndex].title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // 图片
                GestureDetector(
                  onTap: _toggleMenu,
                  onVerticalDragEnd: (details) {
                    // 垂直滑动切换章节
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! > 0) {
                        // 向下滑动，上一章
                        if (_currentChapterIndex > 0) {
                          _onChapterChanged(_currentChapterIndex - 1);
                        }
                      } else if (details.primaryVelocity! < 0) {
                        // 向上滑动，下一章
                        if (_currentChapterIndex < _chapters.length - 1) {
                          _onChapterChanged(_currentChapterIndex + 1);
                        }
                      }
                    }
                  },
                  child: MangaImageWidget(
                    imageUrl: images[index],
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ],
            );
          },
        ),
        // 菜单栏
        if (_showMenu) _buildMenu(images.length),
        // 页脚
        if (!(_footerConfig?.hideFooter ?? false) && !_showMenu)
          _buildFooter(images.length),
      ],
    );
  }
}
