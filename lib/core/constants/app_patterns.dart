/// 应用正则表达式模式
/// 参考项目：io.legado.app.constant.AppPattern
class AppPatterns {
  AppPatterns._();

  // ========== JavaScript 和表达式模式 ==========
  /// JS 模式匹配：<js>...</js> 或 @js:...
  static final jsPattern = RegExp(
    r'<js>([\w\W]*?)</js>|@js:([\w\W]*)',
    caseSensitive: false,
  );

  /// 表达式模式匹配：{{...}}
  static final expPattern = RegExp(r'\{\{([\w\W]*?)\}\}');

  // ========== 图片相关 ==========
  /// 匹配格式化后的图片格式：<img src="...">
  /// 注意：简化版本，匹配单引号或双引号
  static final imgPattern = RegExp(
    '<img[^>]*src=[\'"]([^\'"]*(?:[\'"][^>]+})?)[\'"][^>]*>',
    caseSensitive: false,
  );

  /// dataURL 图片类型：data:...;base64,...
  static final dataUriRegex = RegExp(r'^data:.*?;base64,(.*)');

  // ========== 书籍相关 ==========
  /// 作者名称正则：匹配"作者"或"著"
  static final authorRegex = RegExp(r'^\s*作\s*者[:：\s]+|\s+著');

  /// 名称正则：匹配"作者"相关信息
  static final nameRegex = RegExp(r'\s+作\s*者.*|\s+\S+\s+著');

  /// 章节标题数字模式：第X章
  static final titleNumPattern = RegExp(r'(第)(.+?)(章)');

  // ========== 文件名相关 ==========
  /// 文件名正则：匹配不允许的文件名字符（包含点）
  static final fileNameRegex = RegExp(r'[\\/:*?"<>|.]');

  /// 文件名正则2：匹配不允许的文件名字符（不包含点）
  static final fileNameRegex2 = RegExp(r'[\\/:*?"<>|]');

  // ========== 分组和分隔符 ==========
  /// 分组分隔符：逗号、分号（中英文）
  static final splitGroupRegex = RegExp(r'[,;，；]');

  /// 分号正则
  static final semicolonRegex = RegExp(r';');

  /// 等号正则
  static final equalsRegex = RegExp(r'=');

  /// 空格正则
  static final spaceRegex = RegExp(r'\s+');

  /// 换行正则
  static final lineBreakRegex = RegExp(r'[\r\n]');

  /// 换行符正则（仅 \n）
  static final lfRegex = RegExp(r'\n');

  // ========== 空白字符 ==========
  /// 空白字符正则
  static final whitespaceRegex = RegExp(r'\s+');

  // ========== URL相关 ==========
  /// URL 正则
  static final urlRegex = RegExp(r'https?://[^\s]+');

  /// 绝对 URL 正则
  static final absoluteUrlRegex = RegExp(r'^https?://');

  // ========== 章节相关 ==========
  /// 章节标题正则：第X章/节/回/集/卷
  static final chapterTitleRegex = RegExp(r'^第?\s*[0-9一二三四五六七八九十百千万]+[章节回集卷]');

  /// 章节索引正则
  static final chapterIndexRegex = RegExp(r'^(\d+)');

  // ========== 文本处理 ==========
  /// HTML 标签正则
  static final htmlTagRegex = RegExp(r'<[^>]+>');

  /// Script 标签正则
  static final scriptTagRegex =
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false);

  /// Style 标签正则
  static final styleTagRegex =
      RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false);

  // ========== 数字相关 ==========
  /// 数字正则
  static final numberRegex = RegExp(r'\d+');

  /// 中文数字正则
  static final chineseNumberRegex = RegExp(r'[一二三四五六七八九十百千万]+');

  // ========== 文件类型 ==========
  /// 本地书籍支持类型：txt, epub, umd, pdf, mobi, azw3, azw
  static final bookFileRegex = RegExp(
    r'.*\.(txt|epub|umd|pdf|mobi|azw3|azw)$',
    caseSensitive: false,
  );

  /// 压缩文件支持类型：zip, rar, 7z
  static final archiveFileRegex = RegExp(
    r'.*\.(zip|rar|7z)$',
    caseSensitive: false,
  );

  // ========== 标点和符号 ==========
  /// 所有标点符号正则
  static final punctuationRegex = RegExp(r'(\p{P})+', unicode: true);

  /// 正则表达式特殊字符：需要转义的字符
  static final regexCharRegex = RegExp(r'[{}()\[\].+*?^$\\|]');

  // ========== 调试相关 ==========
  /// 书源调试信息中的各种符号
  static final debugMessageSymbolRegex = RegExp(r'[⇒◇┌└≡]');

  // ========== 内容类型 ==========
  /// XML 内容类型正则
  static final xmlContentTypeRegex = RegExp(r'(application|text)/\w*\+?xml.*');

  // ========== 朗读相关 ==========
  /// 不发音段落判断：只包含空白、控制字符、标点、分隔符、符号
  static final notReadAloudRegex = RegExp(
    r'^(\s|\p{C}|\p{P}|\p{Z}|\p{S})+$',
    unicode: true,
  );
}
