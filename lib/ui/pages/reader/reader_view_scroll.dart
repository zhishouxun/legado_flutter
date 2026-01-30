part of 'reader_page.dart';

/// 滚动模式相关视图
extension ReaderViewScroll on _ReaderPageState {
  /// 构建滚动模式
  Widget _buildScrollMode() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _chapters.length,
      onPageChanged: (index) {
        _onChapterChanged(index);
        if (!_chapterScrollControllers.containsKey(index)) {
          _chapterScrollControllers[index] = ScrollController();
        }
      },
      physics: const NeverScrollableScrollPhysics(), // 锁定水平滑动
      itemBuilder: (context, index) {
        return _buildScrollChapterPage(index);
      },
    );
  }

  /// 构建滚动模式的单章页面
  Widget _buildScrollChapterPage(int index) {
    var content = _curTextChapter?.content ?? '加载中...';
    if (_currentChapterIndex != index) content = "预加载中...";

    final chapter = _chapters[index];
    final chapterTitle = chapter.title;

    final textStyle = TextStyle(
      fontSize: _readConfig.fontSize,
      height: _readConfig.lineHeight,
      color: Color(_readConfig.textColor),
      fontFamily: _readConfig.fontFamily,
    );

    return Container(
      decoration: _buildBackgroundDecoration(_readConfig),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: _readConfig.paddingLeft,
                  vertical: _readConfig.paddingTop),
              controller: _chapterScrollControllers[index] ??=
                  ScrollController(),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapterTitle,
                      style: textStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: textStyle.fontSize! + 4)),
                  const SizedBox(height: 20),
                  _buildTextWidget(content: content, style: textStyle),
                ],
              ),
            ),
          ),
          _buildFooter(chapterTitle),
        ],
      ),
    );
  }
}
