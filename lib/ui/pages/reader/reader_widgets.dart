part of 'reader_page.dart';

/// 抽离 UI 控件到此文件
extension ReaderWidgetsFix on _ReaderPageState {
  /// 构建菜单栏
  Widget _buildMenuBar() {
    if (!_showMenu) return const SizedBox.shrink();
    return Positioned.fill(
      child: Material(
        // 关键修复：提供 Material 祖先并占据全屏
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => setState(() => _showMenu = false),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.book.name,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 功能按钮栏（透明背景）
        Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircleButton(Icons.search, () => _showSearchContent()),
              _buildCircleButton(Icons.auto_stories, () => _showAutoRead()),
              _buildCircleButton(Icons.refresh, () => _refreshChapter()),
              _buildCircleButton(
                _readConfig.backgroundColor == 0xFF000000
                    ? Icons.wb_sunny
                    : Icons.nightlight_round,
                () => _toggleDayNight(),
              ),
            ],
          ),
        ),
        // 进度条和主功能按钮栏（黑色背景）
        Container(
          color: Colors.black.withOpacity(0.85),
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProgressSlider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomItem(
                        Icons.list, "目录", () => _showChapterList()),
                    _buildBottomItem(Icons.headset, "朗读", () => _startTts()),
                    _buildBottomItem(Icons.palette_outlined, "界面",
                        () => _showThemeSettings()),
                    _buildBottomItem(
                        Icons.settings, "设置", () => _showMoreSettings()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _buildProgressSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // 上一章按钮
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white),
            onPressed: _currentChapterIndex > 0
                ? () {
                    // 跳转到上一章，显示最后一页
                    final prevChapterIndex = _currentChapterIndex - 1;
                    final prevChapter = _prevTextChapter;
                    int lastPageIndex = 0;

                    if (prevChapter != null && prevChapter.pages.isNotEmpty) {
                      lastPageIndex = prevChapter.pages.length - 1;
                    }

                    _onChapterChanged(prevChapterIndex,
                        targetPageIndex: lastPageIndex);
                  }
                : null,
            iconSize: 24,
          ),
          // 进度条
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: Slider(
                value: _currentChapterIndex.toDouble(),
                min: 0,
                max: math.max(0, _chapters.length - 1).toDouble(),
                onChanged: (v) {
                  setState(() => _currentChapterIndex = v.toInt());
                },
                onChangeEnd: (v) {
                  _onChapterChanged(v.toInt());
                },
              ),
            ),
          ),
          // 下一章按钮
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white),
            onPressed: _currentChapterIndex < _chapters.length - 1
                ? () {
                    // 跳转到下一章，显示第一页
                    _onChapterChanged(_currentChapterIndex + 1,
                        targetPageIndex: 0);
                  }
                : null,
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTextWidget({
    required String content,
    required TextStyle style,
    String? searchKeyword,
    int? searchPosition,
    int? pageStartPosition,
  }) {
    return Text(
      content,
      style: style,
      textAlign: TextAlign.justify,
    );
  }

  BoxDecoration _buildBackgroundDecoration(ReadConfig config) {
    return BoxDecoration(
      color: Color(config.backgroundColor),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      alignment: Alignment.centerLeft,
      child: Text(
        _chapters.isNotEmpty ? _chapters[_currentChapterIndex].title : "",
        style: TextStyle(
            fontSize: 12, color: Color(_readConfig.textColor).withOpacity(0.5)),
      ),
    );
  }

  Widget _buildFooter(String chapterTitle) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${_currentPageIndex + 1}/${_curTextChapter?.pageSize ?? 1}",
            style: TextStyle(
                fontSize: 12,
                color: Color(_readConfig.textColor).withOpacity(0.5)),
          ),
          Text(
            "${_currentTime.hour}:${_currentTime.minute.toString().padLeft(2, '0')}",
            style: TextStyle(
                fontSize: 12,
                color: Color(_readConfig.textColor).withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}
