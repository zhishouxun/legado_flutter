part of 'reader_page.dart';

/// 翻页模式相关视图
extension ReaderViewPaged on _ReaderPageState {
  /// 构建翻页模式
  Widget _buildPageMode() {
    final textChapter = _curTextChapter;
    List<String> pages;

    if (textChapter != null &&
        textChapter.pages.isNotEmpty &&
        textChapter.chapterIndex == _currentChapterIndex) {
      pages = textChapter.pages.map((page) => page.text).toList();
    } else {
      pages = _chapterPages[_currentChapterIndex] ?? [];
    }

    if (pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      key: ValueKey(_currentChapterIndex),
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      itemCount: pages.length,
      onPageChanged: (index) {
        setState(() => _currentPageIndex = index);
        _updateProgress();
      },
      itemBuilder: (context, index) {
        return _buildPageContent(pages[index]);
      },
    );
  }

  /// 构建单页内容
  Widget _buildPageContent(String content) {
    final chapter = _chapters[_currentChapterIndex];
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
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: _readConfig.paddingLeft),
              child: _buildTextWidget(content: content, style: textStyle),
            ),
          ),
          _buildFooter(chapterTitle),
        ],
      ),
    );
  }
}
