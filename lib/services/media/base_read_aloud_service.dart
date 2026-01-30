import 'dart:async';
import '../../core/base/base_service.dart';
import '../../utils/app_log.dart';
import '../receiver/reader_controller.dart';

/// 朗读服务基类
/// 参考项目：io.legado.app.service.BaseReadAloudService
abstract class BaseReadAloudService extends BaseService {
  /// 是否正在运行
  bool _isRunning = false;

  /// 是否已暂停
  bool _isPaused = false;

  /// 当前朗读的段落列表
  List<String> _paragraphs = [];

  /// 当前朗读的段落索引
  int _currentParagraphIndex = -1;

  /// 段落开始位置（用于段落内定位）
  int _paragraphStartPos = 0;

  /// 是否按页朗读
  bool _readAloudByPage = false;

  /// 当前章节
  String? _currentChapterUrl;

  /// 当前页面索引
  int _currentPageIndex = 0;

  /// 定时器（分钟）
  int _timerMinute = 0;
  Timer? _timer;

  /// 已朗读的字符数（参考项目：readAloudNumber）
  /// 用于计算当前朗读位置在整章中的索引
  int _readAloudNumber = 0;

  /// 当前朗读位置（在整章中的字符索引）
  int _ttsProgress = 0;

  /// 回调
  Function()? onStart;
  Function()? onComplete;
  Function(String)? onError;
  Function(int, int)? onProgress; // (start, end) - 段落内的进度

  /// TTS进度回调（参考项目：EventBus.TTS_PROGRESS）
  /// chapterPosition: 在整章中的字符索引
  /// 用于高亮显示当前朗读位置
  Function(int chapterPosition)? onTtsProgress;

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 是否已暂停
  bool get isPaused => _isPaused;

  /// 当前段落索引
  int get currentParagraphIndex => _currentParagraphIndex;

  /// 段落总数
  int get paragraphCount => _paragraphs.length;

  /// 当前TTS进度（在整章中的字符索引）
  int get ttsProgress => _ttsProgress;

  /// 已朗读字符数
  int get readAloudNumber => _readAloudNumber;

  /// 获取段落列表（子类可访问）
  List<String> get paragraphs => List.unmodifiable(_paragraphs);

  /// 获取当前段落索引（子类可访问）
  int get currentParagraphIndexInternal => _currentParagraphIndex;

  /// 设置当前段落索引（子类可访问）
  void setCurrentParagraphIndex(int index) {
    _currentParagraphIndex =
        index.clamp(0, _paragraphs.isNotEmpty ? _paragraphs.length - 1 : 0);
  }

  /// 获取已朗读字符数（子类可访问）
  int get readAloudNumberInternal => _readAloudNumber;

  /// 设置已朗读字符数（子类可访问）
  void setReadAloudNumber(int number) {
    _readAloudNumber = number;
  }

  /// 更新TTS进度（参考项目：BaseReadAloudService.upTtsProgress）
  /// 发送进度事件到监听器
  void upTtsProgress(int chapterPosition) {
    _ttsProgress = chapterPosition;
    onTtsProgress?.call(chapterPosition);
  }

  /// 计算段落在整章中的起始位置
  /// 参考项目：TextChapter.getReadLength
  int getParagraphStartPosition(int paragraphIndex) {
    int position = 0;
    for (int i = 0; i < paragraphIndex && i < _paragraphs.length; i++) {
      position += _paragraphs[i].length + 1; // +1 为换行符
    }
    return position;
  }

  /// 是否按页朗读
  bool get readAloudByPage => _readAloudByPage;

  /// 定时器（分钟）
  int get timerMinute => _timerMinute;

  /// 开始朗读
  /// 参考项目：BaseReadAloudService.play()
  Future<void> play() async {
    if (_isRunning && !_isPaused) {
      return;
    }

    _isRunning = true;
    _isPaused = false;

    // 启动定时器
    if (_timerMinute > 0) {
      _startTimer();
    }

    onStart?.call();
    await playStart();
  }

  /// 子类实现具体的播放逻辑
  Future<void> playStart();

  /// 停止朗读
  /// 参考项目：BaseReadAloudService.playStop()
  Future<void> stop() async {
    _isRunning = false;
    _isPaused = false;
    _cancelTimer();
    await playStop();
    onComplete?.call();
  }

  /// 子类实现具体的停止逻辑
  Future<void> playStop();

  /// 暂停朗读
  /// 参考项目：BaseReadAloudService.pauseReadAloud()
  Future<void> pause() async {
    if (!_isRunning || _isPaused) {
      return;
    }

    _isPaused = true;
    _cancelTimer();
    await pauseReadAloud();
  }

  /// 子类实现具体的暂停逻辑
  Future<void> pauseReadAloud();

  /// 继续朗读
  /// 参考项目：BaseReadAloudService.resumeReadAloud()
  Future<void> resume() async {
    if (!_isRunning || !_isPaused) {
      return;
    }

    _isPaused = false;

    // 重新启动定时器
    if (_timerMinute > 0) {
      _startTimer();
    }

    await resumeReadAloud();
  }

  /// 子类实现具体的继续逻辑
  Future<void> resumeReadAloud();

  /// 切换到上一段
  /// 参考项目：BaseReadAloudService.prevP()
  Future<bool> prevParagraph() async {
    if (_paragraphs.isEmpty || _currentParagraphIndex <= 0) {
      AppLog.instance.put('没有上一段可切换');
      return false;
    }

    _currentParagraphIndex--;
    _paragraphStartPos = 0;
    await playParagraph(_currentParagraphIndex);
    return true;
  }

  /// 切换到下一段
  /// 参考项目：BaseReadAloudService.nextP()
  Future<bool> nextParagraph() async {
    if (_paragraphs.isEmpty ||
        _currentParagraphIndex >= _paragraphs.length - 1) {
      AppLog.instance.put('没有下一段可切换');
      return false;
    }

    _currentParagraphIndex++;
    _paragraphStartPos = 0;
    await playParagraph(_currentParagraphIndex);
    return true;
  }

  /// 切换到上一章
  /// 参考项目：BaseReadAloudService.prevChapter()
  Future<bool> prevChapter() async {
    return await ReaderController.instance.moveToPrevChapter();
  }

  /// 切换到下一章
  /// 参考项目：BaseReadAloudService.nextChapter()
  Future<bool> nextChapter() async {
    return await ReaderController.instance.moveToNextChapter();
  }

  /// 播放指定段落（子类实现）
  Future<void> playParagraph(int paragraphIndex);

  /// 设置朗读内容
  /// 参考项目：BaseReadAloudService.newReadAloud()
  void setContent(
    List<String> paragraphs, {
    int startParagraphIndex = 0,
    int startPos = 0,
    bool readAloudByPage = false,
    String? chapterUrl,
    int pageIndex = 0,
  }) {
    _paragraphs = List.from(paragraphs);
    _currentParagraphIndex =
        startParagraphIndex.clamp(0, _paragraphs.length - 1);
    _paragraphStartPos = startPos;
    _readAloudByPage = readAloudByPage;
    _currentChapterUrl = chapterUrl;
    _currentPageIndex = pageIndex;
  }

  /// 设置定时器
  /// 参考项目：BaseReadAloudService.setTimer()
  void setTimer(int minute) {
    _timerMinute = minute;
    _cancelTimer();

    if (minute > 0 && _isRunning && !_isPaused) {
      _startTimer();
    }
  }

  /// 启动定时器
  void _startTimer() {
    _cancelTimer();

    if (_timerMinute <= 0) return;

    _timer = Timer(Duration(minutes: _timerMinute), () {
      AppLog.instance.put('定时器到期，停止朗读');
      stop();
    });
  }

  /// 取消定时器
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 添加定时时间
  /// 参考项目：BaseReadAloudService.addTimer()
  void addTimer(int minute) {
    setTimer(_timerMinute + minute);
  }

  @override
  Future<void> onDispose() async {
    await stop();
    _cancelTimer();
    _paragraphs.clear();
    _currentParagraphIndex = -1;
    _paragraphStartPos = 0;
  }
}
