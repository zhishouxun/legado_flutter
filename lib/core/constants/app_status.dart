/// 应用状态常量定义
/// 参考项目：io.legado.app.constant.Status
class AppStatus {
  AppStatus._();

  // ========== 播放状态 ==========
  /// 停止状态
  static const int stop = 0;

  /// 播放状态
  static const int play = 1;

  /// 暂停状态
  static const int pause = 3;

  // ========== 书籍类型状态 ==========
  /// 文本类型 (8)
  static const int bookTypeText = 8;

  /// 更新失败 (16)
  static const int bookTypeUpdateError = 16;

  /// 音频类型 (32)
  static const int bookTypeAudio = 32;

  /// 图片类型 (64)
  static const int bookTypeImage = 64;

  /// Web 文件类型 (128)
  static const int bookTypeWebFile = 128;

  /// 本地类型 (256)
  static const int bookTypeLocal = 256;

  /// 压缩包类型 (512)
  static const int bookTypeArchive = 512;

  /// 未加入书架 (1024)
  static const int bookTypeNotShelf = 1024;

  // ========== 书源类型 ==========
  /// 默认/文本类型
  static const int sourceTypeDefault = 0;

  /// 音频类型
  static const int sourceTypeAudio = 1;

  /// 图片类型
  static const int sourceTypeImage = 2;

  /// 文件类型
  static const int sourceTypeFile = 3;

  // ========== 页面模式 ==========
  /// 滚动模式
  static const int pageModeScroll = 0;

  /// 翻页模式
  static const int pageModePage = 1;

  // ========== 页面动画类型 ==========
  /// 覆盖动画
  static const int pageAnimCover = 0;

  /// 滑动动画
  static const int pageAnimSlide = 1;

  /// 仿真动画
  static const int pageAnimSimulation = 2;

  /// 滚动动画
  static const int pageAnimScroll = 3;

  /// 无动画
  static const int pageAnimNone = 4;

  // ========== 源类型 ==========
  /// 书籍源
  static const int sourceTypeBook = 0;

  /// RSS 源
  static const int sourceTypeRss = 1;
}

