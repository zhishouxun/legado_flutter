/// 偏好设置键常量定义
/// 参考项目：io.legado.app.constant.PreferKey
class PreferKey {
  PreferKey._();

  // ========== 基础设置 ==========
  /// 语言
  static const String language = 'language';

  /// 字体缩放
  static const String fontScale = 'fontScale';

  /// 主题模式
  static const String themeMode = 'themeMode';

  /// 用户代理
  static const String userAgent = 'userAgent';

  // ========== 书架相关 ==========
  /// 显示未读
  static const String showUnread = 'showUnread';

  /// 书籍分组样式
  static const String bookGroupStyle = 'bookGroupStyle';

  /// 书架布局
  static const String bookshelfLayout = 'bookshelfLayout';

  /// 书架排序
  static const String bookshelfSort = 'bookshelfSort';

  /// 显示发现
  static const String showDiscovery = 'showDiscovery';

  /// 显示 RSS
  static const String showRss = 'showRss';

  /// 显示书架快速滚动
  static const String showBookshelfFastScroller = 'showBookshelfFastScroller';

  /// 点击标题打开书籍信息
  static const String openBookInfoByClickTitle = 'openBookInfoByClickTitle';

  /// 显示最后更新时间
  static const String showLastUpdateTime = 'showLastUpdateTime';

  /// 显示待更新数量
  static const String showWaitUpCount = 'showWaitUpCount';

  /// 自动刷新
  static const String autoRefresh = 'auto_refresh';

  /// 默认首页
  static const String defaultHomePage = 'defaultHomePage';

  // ========== 搜索相关 ==========
  /// 精确搜索模式
  static const String precisionSearch = 'precisionSearch';

  // ========== 封面相关 ==========
  /// 使用默认封面
  static const String useDefaultCover = 'useDefaultCover';

  /// 仅在 WiFi 下加载封面
  static const String loadCoverOnlyWifi = 'loadCoverOnlyWifi';

  /// 封面显示名称
  static const String coverShowName = 'coverShowName';

  /// 封面显示作者
  static const String coverShowAuthor = 'coverShowAuthor';

  /// 封面显示名称（夜间）
  static const String coverShowNameN = 'coverShowNameN';

  /// 封面显示作者（夜间）
  static const String coverShowAuthorN = 'coverShowAuthorN';

  /// 默认封面
  static const String defaultCover = 'defaultCover';

  /// 默认封面（夜间）
  static const String defaultCoverDark = 'defaultCoverDark';

  /// 图片保存路径
  static const String imageSavePath = 'imageSavePath';

  /// 书源检查超时时间（毫秒）
  static const String checkSourceTimeout = 'checkSourceTimeout';

  /// 书源检查-搜索
  static const String checkSourceSearch = 'checkSourceSearch';

  /// 书源检查-发现
  static const String checkSourceDiscovery = 'checkSourceDiscovery';

  /// 书源检查-详情
  static const String checkSourceInfo = 'checkSourceInfo';

  /// 书源检查-分类
  static const String checkSourceCategory = 'checkSourceCategory';

  /// 书源检查-正文
  static const String checkSourceContent = 'checkSourceContent';

  /// 书源检查-关键字
  static const String checkSourceKeyword = 'checkSourceKeyword';

  // ========== 阅读相关 ==========
  /// 阅读样式选择
  static const String readStyleSelect = 'readStyleSelect';

  /// 阅读正文行高
  static const String readBodyToLh = 'readBodyToLh';

  /// 文本两端对齐
  static const String textFullJustify = 'textFullJustify';

  /// 文本底端对齐
  static const String textBottomJustify = 'textBottomJustify';

  /// 展开文本菜单
  static const String expandTextMenu = 'expandTextMenu';

  /// 显示阅读标题附加
  static const String showReadTitleAddition = 'showReadTitleAddition';

  /// 阅读栏样式跟随页面
  static const String readBarStyleFollowPage = 'readBarStyleFollowPage';

  /// 内容选择朗读模式
  static const String contentSelectSpeakMod = 'contentReadAloudMod';

  /// 阅读 URL 在浏览器中打开
  static const String readUrlOpenInBrowser = 'readUrlInBrowser';

  /// 双击横向分页
  static const String doublePageHorizontal = 'doubleHorizontalPage';

  /// 页面触摸滑动
  static const String pageTouchSlop = 'pageTouchSlop';

  /// 禁用点击滚动
  static const String disableClickScroll = 'disableClickScroll';

  /// 无动画滚动页面
  static const String noAnimScrollPage = 'noAnimScrollPage';

  /// 禁用横向页面快照
  static const String disableHorizontalPageSnap = 'disableHorizontalPageSnap';

  /// 显示亮度视图
  static const String showBrightnessView = 'showBrightnessView';

  /// 亮度视图位置
  static const String brightnessVwPos = 'brightnessVwPos';

  /// 亮度（日间）
  static const String brightness = 'brightness';

  /// 亮度（夜间）
  static const String nightBrightness = 'nightBrightness';

  /// 亮度自动跟随
  static const String brightnessAuto = 'brightnessAuto';

  /// 保持屏幕常亮
  static const String keepLight = 'keep_light';

  /// 屏幕方向
  static const String screenOrientation = 'screenOrientation';

  /// 文本可选择
  static const String textSelectAble = 'selectText';

  /// 隐藏状态栏
  static const String hideStatusBar = 'hideStatusBar';

  /// 隐藏导航栏
  static const String hideNavigationBar = 'hideNavigationBar';

  /// 透明状态栏
  static const String transparentStatusBar = 'transparentStatusBar';

  /// 沉浸式导航栏
  static const String immNavigationBar = 'immNavigationBar';

  /// 填充显示缺口
  static const String paddingDisplayCutouts = 'paddingDisplayCutouts';

  /// 栏高度
  static const String barElevation = 'barElevation';

  /// 使用中文布局
  static const String useZhLayout = 'useZhLayout';

  /// 优化渲染
  static const String optimizeRender = 'optimizeRender';

  // ========== 点击操作（9个区域）==========
  /// 点击操作 - 左上
  static const String clickActionTL = 'clickActionTopLeft';

  /// 点击操作 - 中上
  static const String clickActionTC = 'clickActionTopCenter';

  /// 点击操作 - 右上
  static const String clickActionTR = 'clickActionTopRight';

  /// 点击操作 - 左中
  static const String clickActionML = 'clickActionMiddleLeft';

  /// 点击操作 - 中中
  static const String clickActionMC = 'clickActionMiddleCenter';

  /// 点击操作 - 右中
  static const String clickActionMR = 'clickActionMiddleRight';

  /// 点击操作 - 左下
  static const String clickActionBL = 'clickActionBottomLeft';

  /// 点击操作 - 中下
  static const String clickActionBC = 'clickActionBottomCenter';

  /// 点击操作 - 右下
  static const String clickActionBR = 'clickActionBottomRight';

  // ========== TTS 和朗读相关 ==========
  /// 按页朗读
  static const String readAloudByPage = 'readAloudByPage';

  /// TTS 引擎
  static const String ttsEngine = 'appTtsEngine';

  /// TTS 跟随系统
  static const String ttsFollowSys = 'ttsFollowSys';

  /// TTS 语速
  static const String ttsSpeechRate = 'ttsSpeechRate';

  /// TTS 定时器
  static const String ttsTimer = 'ttsTimer';

  /// 流式朗读音频
  static const String streamReadAloudAudio = 'streamReadAloudAudio';

  /// 通话时暂停朗读
  static const String pauseReadAloudWhilePhoneCalls =
      'pauseReadAloudWhilePhoneCalls';

  /// 媒体按钮朗读
  static const String readAloudByMediaButton = 'readAloudByMediaButton';

  /// 媒体按钮控制章节切换
  static const String mediaButtonPerNext = 'mediaButtonPerNext';

  /// 忽略音频焦点
  static const String ignoreAudioFocus = 'ignoreAudioFocus';

  /// 音频播放 WakeLock
  static const String audioPlayWakeLock = 'audioPlayWakeLock';

  // ========== 快捷键 ==========
  /// 上一章按键
  static const String prevKeys = 'prevKeyCodes';

  /// 下一章按键
  static const String nextKeys = 'nextKeyCodes';

  /// 按键长按翻页
  static const String keyPageOnLongPress = 'keyPageOnLongPress';

  /// 音量键翻页
  static const String volumeKeyPage = 'volumeKeyPage';

  /// 播放时音量键翻页
  static const String volumeKeyPageOnPlay = 'volumeKeyPageOnPlay';

  /// 鼠标滚轮翻页
  static const String mouseWheelPage = 'mouseWheelPage';

  // ========== 导出和导入 ==========
  /// 书籍导出文件名模板
  static const String bookExportFileName = 'bookExportFileName';

  /// 书籍导入文件名模板
  static const String bookImportFileName = 'bookImportFileName';

  /// 章节导出文件名模板
  static const String episodeExportFileName = 'episodeExportFileName';

  /// 导出字符集
  static const String exportCharset = 'exportCharset';

  /// 导出使用替换规则
  static const String exportUseReplace = 'exportUseReplace';

  /// 导出不包含章节名
  static const String exportNoChapterName = 'exportNoChapterName';

  /// 导出类型
  static const String exportType = 'exportType';

  /// 导出图片文件
  static const String exportPictureFile = 'exportPictureFile';

  /// 启用自定义导出
  static const String enableCustomExport = 'enableCustomExport';

  /// 导出到 WebDAV
  static const String exportToWebDav = 'webDavCacheBackup';

  /// 并行导出书籍
  static const String parallelExportBook = 'parallelExportBook';

  /// 导入保持名称
  static const String importKeepName = 'importKeepName';

  /// 导入保持分组
  static const String importKeepGroup = 'importKeepGroup';

  /// 导入保持启用
  static const String importKeepEnable = 'importKeepEnable';

  /// 本地书籍导入排序
  static const String localBookImportSort = 'localBookImportSort';

  // ========== 换源相关 ==========
  /// 换源检查作者
  static const String changeSourceCheckAuthor = 'changeSourceCheckAuthor';

  /// 换源加载目录
  static const String changeSourceLoadToc = 'changeSourceLoadToc';

  /// 换源加载信息
  static const String changeSourceLoadInfo = 'changeSourceLoadInfo';

  /// 换源加载字数
  static const String changeSourceLoadWordCount = 'changeSourceLoadWordCount';

  /// 自动换源
  static const String autoChangeSource = 'autoChangeSource';

  /// 批量换源延迟
  static const String batchChangeSourceDelay = 'batchChangeSourceDelay';

  /// 检查书源
  static const String checkSource = 'checkSource';

  /// 上传规则
  static const String uploadRule = 'uploadRule';

  /// 目录 UI 使用替换
  static const String tocUiUseReplace = 'tocUiUseReplace';

  /// 目录统计字数
  static const String tocCountWords = 'tocCountWords';

  /// 去除重复标题
  static const String removeSameTitle = 'removeSameTitle';

  /// 搜索分组
  static const String searchGroup = 'searchGroup';

  /// 搜索历史排序方式（0=时间，1=使用次数）
  static const String searchHistorySortMode = 'searchHistorySortMode';

  // ========== 其他功能 ==========
  /// 启用评论
  static const String enableReview = 'enableReview';

  /// 记录日志
  static const String recordLog = 'recordLog';

  /// 清理缓存
  static const String cleanCache = 'cleanCache';

  /// 保存标签页位置
  static const String saveTabPosition = 'saveTabPosition';

  /// 处理文本
  static const String processText = 'process_text';

  /// 字体文件夹
  static const String fontFolder = 'fontFolder';

  /// 系统字体
  static const String systemTypefaces = 'system_typefaces';

  /// 启动器图标
  static const String launcherIcon = 'launcherIcon';

  /// 默认书籍树 URI
  static const String defaultBookTreeUri = 'defaultBookTreeUri';

  /// 显示添加到书架提示
  static const String showAddToShelfAlert = 'showAddToShelfAlert';

  /// 源编辑最大行数
  static const String sourceEditMaxLine = 'sourceEditMaxLine';

  /// 收缩数据库
  static const String shrinkDatabase = 'shrinkDatabase';

  /// 记录堆转储
  static const String recordHeapDump = 'recordHeapDump';

  /// 更新到变体
  static const String updateToVariant = 'updateToVariant';

  /// 默认阅读
  static const String defaultToRead = 'defaultToRead';

  /// 自动阅读速度
  static const String autoReadSpeed = 'autoReadSpeed';

  /// 进度条行为
  static const String progressBarBehavior = 'progressBarBehavior';

  // ========== Web 服务 ==========
  /// Web 服务
  static const String webService = 'webService';

  /// Web 端口
  static const String webPort = 'webPort';

  /// Web 服务 WakeLock
  static const String webServiceWakeLock = 'webServiceWakeLock';

  /// 清除 WebView 数据
  static const String clearWebViewData = 'clearWebViewData';

  // ========== WebDAV ==========
  /// WebDAV URL
  static const String webDavUrl = 'web_dav_url';

  /// WebDAV 账号
  static const String webDavAccount = 'web_dav_account';

  /// WebDAV 密码
  static const String webDavPassword = 'web_dav_password';

  /// WebDAV 目录
  static const String webDavDir = 'webDavDir';

  /// WebDAV 设备名
  static const String webDavDeviceName = 'webDavDeviceName';

  /// 远程服务器 ID
  static const String remoteServerId = 'remoteServerId';

  // ========== 备份和恢复 ==========
  /// 备份路径
  static const String backupPath = 'backupUri';

  /// 恢复忽略
  static const String restoreIgnore = 'restoreIgnore';

  /// 仅最新备份
  static const String onlyLatestBackup = 'onlyLatestBackup';

  /// 自动检查新备份
  static const String autoCheckNewBackup = 'autoCheckNewBackup';

  // ========== 漫画相关 ==========
  /// 漫画样式选择
  static const String comicStyleSelect = 'comicStyleSelect';

  /// 显示漫画 UI
  static const String showMangaUi = 'showMangaUi';

  /// 禁用漫画缩放
  static const String disableMangaScale = 'disableMangaScale';

  /// 启用漫画横向滚动
  static const String enableMangaHorizontalScroll =
      'enableMangaHorizontalScroll';

  /// 隐藏漫画标题
  static const String hideMangaTitle = 'hideMangaTitle';

  /// 漫画颜色滤镜
  static const String mangaColorFilter = 'mangaColorFilter';

  /// 启用漫画电子墨水
  static const String enableMangaEInk = 'enableMangaEInk';

  /// 漫画电子墨水阈值
  static const String mangaEInkThreshold = 'mangaEInkThreshold';

  /// 启用漫画灰度
  static const String enableMangaGray = 'enableMangaGray';

  /// 漫画自动翻页速度
  static const String mangaAutoPageSpeed = 'mangaAutoPageSpeed';

  /// 漫画页脚配置
  static const String mangaFooterConfig = 'mangaFooterConfig';

  /// 漫画预下载数量
  static const String mangaPreDownloadNum = 'mangaPreDownloadNum';

  /// 点击预览图片
  static const String previewImageByClick = 'previewImageByClick';

  // ========== 预下载和缓存 ==========
  /// 预下载数量
  static const String preDownloadNum = 'preDownloadNum';

  /// 图片保留数量
  static const String imageRetainNum = 'imageRetainNum';

  /// 位图缓存大小
  static const String bitmapCacheSize = 'bitmapCacheSize';

  /// 自动清理过期
  static const String autoClearExpired = 'autoClearExpired';

  /// 线程数
  static const String threadCount = 'threadCount';

  /// 反锯齿
  static const String antiAlias = 'antiAlias';

  /// 使用 Cronet
  static const String cronet = 'Cronet';

  // ========== 同步相关 ==========
  /// 同步书籍进度
  static const String syncBookProgress = 'syncBookProgress';

  /// 同步书籍进度增强
  static const String syncBookProgressPlus = 'syncBookProgressPlus';

  // ========== 替换规则 ==========
  /// 替换规则默认启用
  static const String replaceEnableDefault = 'replaceEnableDefault';

  // ========== 简繁转换 ==========
  /// 简繁转换类型
  static const String chineseConverterType = 'chineseConverterType';

  // ========== 阅读记录 ==========
  /// 启用阅读记录
  static const String enableReadRecord = 'enableReadRecord';

  // ========== 共用布局 ==========
  /// 共用布局
  static const String shareLayout = 'shareLayout';

  // ========== 欢迎页 ==========
  /// 自定义欢迎页
  static const String customWelcome = 'customWelcome';

  /// 欢迎页图片
  static const String welcomeImage = 'welcomeImagePath';

  /// 欢迎页图片（夜间）
  static const String welcomeImageDark = 'welcomeImagePathDark';

  /// 欢迎页显示文本
  static const String welcomeShowText = 'welcomeShowText';

  /// 欢迎页显示文本（夜间）
  static const String welcomeShowTextDark = 'welcomeShowTextDark';

  /// 欢迎页显示图标
  static const String welcomeShowIcon = 'welcomeShowIcon';

  /// 欢迎页显示图标（夜间）
  static const String welcomeShowIconDark = 'welcomeShowIconDark';

  // ========== 主题颜色（日间）==========
  /// 主色
  static const String cPrimary = 'colorPrimary';

  /// 强调色
  static const String cAccent = 'colorAccent';

  /// 背景色
  static const String cBackground = 'colorBackground';

  /// 底部背景色
  static const String cBBackground = 'colorBottomBackground';

  /// 背景图片
  static const String bgImage = 'backgroundImage';

  /// 背景图片模糊
  static const String bgImageBlurring = 'backgroundImageBlurring';

  // ========== 主题颜色（夜间）==========
  /// 主色（夜间）
  static const String cNPrimary = 'colorPrimaryNight';

  /// 强调色（夜间）
  static const String cNAccent = 'colorAccentNight';

  /// 背景色（夜间）
  static const String cNBackground = 'colorBackgroundNight';

  /// 底部背景色（夜间）
  static const String cNBBackground = 'colorBottomBackgroundNight';

  /// 背景图片（夜间）
  static const String bgImageN = 'backgroundImageNight';

  /// 背景图片模糊（夜间）
  static const String bgImageNBlurring = 'backgroundImageNightBlurring';
}
