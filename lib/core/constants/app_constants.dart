/// 应用常量定义
/// 参考项目：io.legado.app.constant.AppConst
class AppConstants {
  AppConstants._();

  // ========== 应用信息 ==========
  /// 应用标签
  static const String appTag = 'Legado';
  
  /// 应用名称
  static const String appName = 'Legado';
  
  /// 应用版本（运行时从 package_info 获取）
  static const String appVersion = '1.0.0';

  // ========== 通知渠道ID ==========
  /// 下载通知渠道ID
  static const String channelIdDownload = 'channel_download';
  
  /// 朗读通知渠道ID
  static const String channelIdReadAloud = 'channel_read_aloud';
  
  /// Web服务通知渠道ID
  static const String channelIdWeb = 'channel_web';

  // ========== HTTP相关 ==========
  /// User-Agent 头部名称
  static const String uaName = 'User-Agent';

  // ========== 线程和并发 ==========
  /// 最大线程数
  static const int maxThread = 9;

  // ========== WebDAV ==========
  /// 默认 WebDAV ID
  static const int defaultWebdavId = -1;

  // ========== 数据库 ==========
  /// 数据库名称
  static const String databaseName = 'legado.db';
  
  /// 数据库版本（当前版本：18）
  static const int databaseVersion = 18;

  // ========== 网络 ==========
  /// 默认超时时间（秒）
  static const int defaultTimeout = 30;
  
  /// 最大重试次数
  static const int maxRetryCount = 3;

  // ========== 缓存 ==========
  /// 默认缓存大小（100MB）
  static const int defaultCacheSize = 100 * 1024 * 1024;
  
  /// 最大缓存大小（500MB）
  static const int maxCacheSize = 500 * 1024 * 1024;

  // ========== 阅读器 ==========
  /// 默认字体大小
  static const int defaultFontSize = 18;
  
  /// 最小字体大小
  static const int minFontSize = 12;
  
  /// 最大字体大小
  static const int maxFontSize = 36;
  
  /// 默认行高
  static const double defaultLineHeight = 1.6;

  // ========== 分页 ==========
  /// 默认分页大小
  static const int defaultPageSize = 20;
  
  /// 最大分页大小
  static const int maxPageSize = 100;

  // ========== 预下载 ==========
  /// 预下载章节数量
  static const int preDownloadChapterCount = 3;
  
  /// 最大并发下载数
  static const int maxConcurrentDownloads = 2;

  // ========== Web服务 ==========
  /// 默认 Web 服务端口
  static const int defaultWebPort = 1234;
  
  /// 默认 WebSocket 端口
  static const int defaultWebSocketPort = 1235;

  // ========== 文件格式 ==========
  /// 支持的图片格式
  static const List<String> supportedImageFormats = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif'
  ];
  
  /// 支持的书籍格式
  static const List<String> supportedBookFormats = [
    '.txt',
    '.epub',
    '.mobi',
    '.azw',
    '.azw3'
  ];

  // ========== 字符集 ==========
  /// 支持的字符集列表
  static const List<String> charsets = [
    'UTF-8',
    'GB2312',
    'GB18030',
    'GBK',
    'Unicode',
    'UTF-16',
    'UTF-16LE',
    'ASCII',
  ];

  // ========== 文件路径键 ==========
  /// 图片路径键
  static const String imagePathKey = 'imagePath';

  // ========== 正则表达式模式（字符串形式，用于配置）==========
  /// URL 模式
  static const String urlPattern = r'https?://[^\s]+';
  
  /// 邮箱模式
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
}

