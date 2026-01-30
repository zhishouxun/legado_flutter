/// 滚动模式修正实现说明
/// 
/// 要实现您需要的滚动模式（上下滚动，松手后不自动翻页到下一章），需要修改以下内容：
/// 
/// 1. 修改 _buildScrollMode 函数，使鼠标滚轮事件只滚动当前章节内容：
/// 
/// ```dart
/// Widget _buildScrollMode() {
///   final volumeKeyPage =
///       AppConfig.getBool(PreferKey.volumeKeyPage, defaultValue: true);
///
///   Widget content = Listener(
///     onPointerSignal: (event) {
///       // 处理鼠标滚轮事件（桌面端）
///       if (event is PointerScrollEvent) {
///         final mouseWheelPage =
///             AppConfig.getBool('mouse_wheel_page', defaultValue: true);
///         if (!mouseWheelPage) return;
///
///         final scrollDelta = event.scrollDelta.dy;
///
///         // 获取当前章节的滚动控制器
///         final scrollController = _chapterScrollControllers[_currentChapterIndex];
///         
///         if (scrollController != null) {
///           // 直接滚动当前章节内容，而不是跳转到其他章节
///           final newPosition = (scrollController.offset + scrollDelta).clamp(0.0, scrollController.position.maxScrollExtent);
///           scrollController.animateTo(
///             newPosition,
///             duration: const Duration(milliseconds: 100),
///             curve: Curves.easeInOut,
///           );
///         }
///       }
///     },
///     child: Stack(
///       children: [
///         Listener(
///           onPointerDown: (event) {
///             _touchStart = event.localPosition;
///             _touchStartTime = DateTime.now();
///             _isDragging = false;
///           },
///           onPointerUp: (event) {
///             // 如果触摸时间很短（小于300ms）且没有拖拽，认为是点击
///             if (_touchStart != null && _touchStartTime != null) {
///               final duration = DateTime.now().difference(_touchStartTime!);
///               final distance = (_touchStart! - event.localPosition).distance;
///               // 点击判断：时间短（<300ms）且移动距离小（<10px）
///               if (duration.inMilliseconds < 300 &&
///                   distance < 10 &&
///                   !_isDragging) {
///                 _handleTap(_touchStart!);
///               }
///             }
///             _touchStart = null;
///             _touchStartTime = null;
///             _isDragging = false;
///           },
///           onPointerCancel: (event) {
///             _touchStart = null;
///             _touchStartTime = null;
///             _isDragging = false;
///           },
///           onPointerMove: (event) {
///             // 如果移动距离超过阈值，认为是拖拽
///             if (_touchStart != null) {
///               final distance = (_touchStart! - event.localPosition).distance;
///               if (distance > 10) {
///                 _isDragging = true;
///               }
///             }
///           },
///           behavior: HitTestBehavior.translucent,
///           child: PageView.builder(
///             controller: _pageController,
///             itemCount: _chapters.length,
///             onPageChanged: (index) {
///               // 当切换章节时，重置滚动位置
///               _onChapterChanged(index);
///               
///               // 确保当前章节的滚动控制器已创建
///               if (!_chapterScrollControllers.containsKey(index)) {
///                 _chapterScrollControllers[index] = ScrollController();
///               }
///             },
///             itemBuilder: (context, index) {
///               return _buildScrollChapterPage(index);
///             },
///           ),
///         ),
///         _buildMenuBar(),
///       ],
///     ),
///   );
///
///   // 如果启用了音量键翻页，包装 RawKeyboardListener
///   if (volumeKeyPage) {
///     content = RawKeyboardListener(
///       focusNode: FocusNode()..requestFocus(),
///       onKey: (RawKeyEvent event) {
///         if (event is RawKeyDownEvent) {
///           _handleVolumeKey(event.logicalKey);
///         }
///       },
///       child: content,
///     );
///   }
///
///   return content;
/// }
/// ```
/// 
/// 2. 修改 _buildScrollChapterPage 函数，确保每个章节页面有自己的滚动控制器：
/// 
/// ```dart
/// Widget _buildScrollChapterPage(int index) {
///   var content = _chapterContents[index] ?? '加载中...';
///   final chapter = _chapters[index];
///   final chapterTitle = chapter.title;
///
///   final textStyle = TextStyle(
///     fontSize: _readConfig.fontSize,
///     height: _readConfig.lineHeight,
///     letterSpacing: _readConfig.letterSpacing,
///     color: Color(_readConfig.textColor),
///     fontWeight: _readConfig.fontWeight == 0
///         ? FontWeight.w300
///         : (_readConfig.fontWeight == 2 ? FontWeight.bold : FontWeight.normal),
///     fontFamily: _readConfig.fontFamily,
///   );
///
///   // 计算标题字号（titleSize 是相对值，0为基础）
///   final titleFontSize = _readConfig.fontSize + (_readConfig.titleSize * 0.5);
///   final titleStyle = textStyle.copyWith(
///     fontWeight: FontWeight.bold,
///     fontSize: titleFontSize,
///   );
///
///   return Container(
///     decoration: _buildBackgroundDecoration(_readConfig),
///     child: Column(
///       children: [
///         // 页眉
///         _buildHeader(),
///         // 正文内容区域
///         Expanded(
///           child: Container(
///             padding: EdgeInsets.only(
///               top: _readConfig.paddingTop,
///               bottom: _readConfig.paddingBottom,
///               left: _readConfig.paddingLeft,
///               right: _readConfig.paddingRight,
///             ),
///             child: Builder(
///               builder: (context) {
///                 // 获取或创建该章节的 ScrollController
///                 if (!_chapterScrollControllers.containsKey(index)) {
///                   _chapterScrollControllers[index] = ScrollController();
///                 }
///                 final scrollController = _chapterScrollControllers[index]!;
///
///                 return SingleChildScrollView(
///                   controller: scrollController,
///                   child: Column(
///                     crossAxisAlignment: CrossAxisAlignment.start,
///                     children: [
///                       // 章节标题（根据 titleMode 决定是否显示和对齐方式）
///                       if (chapterTitle.isNotEmpty &&
///                           _readConfig.titleMode != 2)
///                         Padding(
///                           padding: EdgeInsets.only(
///                             top: _readConfig.titleTopSpacing.toDouble(),
///                             bottom: _readConfig.titleBottomSpacing.toDouble(),
///                           ),
///                           child: Text(
///                             chapterTitle,
///                             style: titleStyle,
///                             textAlign: _readConfig.titleMode == 1
///                                 ? TextAlign.center
///                                 : TextAlign.left,
///                           ),
///                         ),
///                       // 章节内容 - 支持高亮显示
///                       _buildTextWidget(
///                         content: content,
///                         style: textStyle,
///                         searchKeyword: _searchKeyword,
///                         searchPosition: _searchChapterIndex == index
///                             ? _searchPosition
///                             : null,
///                         pageStartPosition: 0, // 滚动模式下，页面从0开始
///                       ),
///                     ],
///                   ),
///                 );
///               },
///             ),
///           ),
///         ),
///         // 页脚（包含章节标题和页码信息）
///         _buildFooter(chapterTitle),
///       ],
///     ),
///   );
/// }
/// ```
/// 
/// 3. 确保在 dispose 方法中正确清理章节滚动控制器：
/// 
/// ```dart
/// @override
/// void dispose() {
///   // ... 其他清理代码 ...
///
///   // 释放所有章节的 ScrollController
///   for (final controller in _chapterScrollControllers.values) {
///     controller.dispose();
///   }
///   _chapterScrollControllers.clear();
///
///   // ... 其他清理代码 ...
///   super.dispose();
/// }
/// ```
/// 
/// 这些修改将确保：
/// 1. 滚动模式下，用户只能滚动当前章节内容，不会自动切换到其他章节
/// 2. 鼠标滚轮只影响当前章节的滚动位置
/// 3. 松手后保持当前位置，不自动翻页
/// 4. 滑动模式（翻页模式）依然支持左右滑动翻页功能