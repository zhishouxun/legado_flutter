import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../data/models/book.dart';
import '../../data/models/book_source.dart';
import '../../data/models/interfaces/base_book.dart';
import '../../core/constants/app_patterns.dart';
import '../../core/constants/app_status.dart';
import '../../services/source/book_source_service.dart';
import '../../services/book/book_service.dart';
import '../../services/file_manage_service.dart';
import '../../config/app_config.dart';
import '../../utils/js_engine.dart';
import '../../utils/app_log.dart';

/// Book 扩展方法
/// 参考项目：io.legado.app.help.book.BookExtensions.kt
extension BookExtensions on Book {
  // ========== 类型判断 ==========

  /// 是否音频
  bool get isAudio => BookType.isAudio(type);

  /// 是否图片
  bool get isImage => BookType.isImage(type);

  /// 是否本地书籍
  /// 注意：已在 Book 类中实现，这里保持一致性
  // bool get isLocal => origin == BookType.localTag || origin.startsWith(BookType.webDavTag);

  /// 是否本地TXT
  bool get isLocalTxt => isLocal && originName.toLowerCase().endsWith('.txt');

  /// 是否EPUB
  bool get isEpub => isLocal && originName.toLowerCase().endsWith('.epub');

  /// 是否UMD
  bool get isUmd => isLocal && originName.toLowerCase().endsWith('.umd');

  /// 是否PDF
  bool get isPdf => isLocal && originName.toLowerCase().endsWith('.pdf');

  /// 是否MOBI
  bool get isMobi {
    if (!isLocal) return false;
    final lower = originName.toLowerCase();
    return lower.endsWith('.mobi') ||
        lower.endsWith('.azw3') ||
        lower.endsWith('.azw');
  }

  /// 是否在线文本
  bool get isOnLineTxt => !isLocal && BookType.isText(type);

  /// 是否Web文件
  bool get isWebFile => BookType.hasType(type, AppStatus.bookTypeWebFile);

  /// 是否更新错误
  bool get isUpError => BookType.isUpdateError(type);

  /// 是否压缩包
  bool get isArchive => BookType.hasType(type, AppStatus.bookTypeArchive);

  /// 是否不在书架
  bool get isNotShelf => BookType.hasType(type, AppStatus.bookTypeNotShelf);

  /// 获取压缩包名称
  String get archiveName {
    if (!isArchive) {
      throw Exception('Book is not decompressed from archive');
    }
    // local_book::archive.rar
    // webDav::https://...../archive.rar
    final parts = origin.split('::');
    if (parts.length > 1) {
      final path = parts[1];
      return path.split('/').last;
    }
    return origin;
  }

  // ========== 类型操作 ==========

  /// 设置类型
  void setType(List<int> types) {
    type = 0;
    addType(types);
  }

  /// 添加类型
  void addType(List<int> types) {
    for (final t in types) {
      type = type | t;
    }
  }

  /// 移除类型
  void removeType(List<int> types) {
    for (final t in types) {
      type = type & ~t;
    }
  }

  /// 移除所有书籍类型
  void removeAllBookType() {
    removeType([
      AppStatus.bookTypeText,
      AppStatus.bookTypeAudio,
      AppStatus.bookTypeImage,
      AppStatus.bookTypeWebFile,
      AppStatus.bookTypeLocal,
      AppStatus.bookTypeArchive,
    ]);
  }

  /// 清空类型
  void clearType() {
    type = 0;
  }

  /// 检查类型
  bool isType(int bookType) {
    return (type & bookType) != 0;
  }

  /// 更新类型（从书源类型转换为书籍类型）
  void upType() {
    if (type < 8) {
      // 根据书源类型设置书籍类型
      if (isType(AppStatus.sourceTypeImage)) {
        type = AppStatus.bookTypeImage;
      } else if (isType(AppStatus.sourceTypeAudio)) {
        type = AppStatus.bookTypeAudio;
      } else if (isType(AppStatus.sourceTypeFile)) {
        type = AppStatus.bookTypeWebFile;
      } else {
        type = AppStatus.bookTypeText;
      }

      // 如果是本地书籍，添加本地类型标志
      if (origin == BookType.localTag || origin.startsWith(BookType.webDavTag)) {
        type = type | AppStatus.bookTypeLocal;
      }
    }
  }

  // ========== URI处理 ==========

  /// 获取本地URI
  /// 参考项目：Book.getLocalUri()
  /// 注意：Flutter 中 URI 处理与 Android 不同，这里简化实现
  Uri getLocalUri() {
    if (!isLocal) {
      throw Exception('不是本地书籍');
    }

    // 检查是否是 URI 格式
    if (bookUrl.startsWith('file://') || bookUrl.startsWith('content://')) {
      return Uri.parse(bookUrl);
    }

    // 普通文件路径
    return Uri.file(bookUrl);
  }

  /// 获取压缩包URI
  Future<Uri?> getArchiveUri() async {
    if (!isArchive) return null;
    
    try {
      // 从 origin 中提取压缩包路径
      // 格式：local_book::archive.rar 或 webDav::https://...../archive.rar
      final parts = origin.split('::');
      if (parts.length > 1) {
        final archivePath = parts[1];
        
        // 如果是本地压缩包，从默认书籍目录获取
        if (parts[0] == 'local_book') {
          final booksDir = await FileManageService.instance.getBooksDirectory();
          final archiveFile = File('${booksDir.path}/$archivePath');
          if (await archiveFile.exists()) {
            return Uri.file(archiveFile.path);
          }
        } else if (parts[0] == 'webDav') {
          // WebDAV 压缩包，返回 URL
          return Uri.parse(archivePath);
        }
      }
      
      return null;
    } catch (e) {
      AppLog.instance.put('获取压缩包URI失败', error: e);
      return null;
    }
  }

  /// 获取远程URL（WebDAV）
  String? getRemoteUrl() {
    if (origin.startsWith(BookType.webDavTag)) {
      return origin.substring(BookType.webDavTag.length);
    }
    return null;
  }

  // ========== 格式化 ==========

  /// 格式化书名
  /// 参考项目：BookHelp.formatBookName
  String formatBookName() {
    return name
        .replaceAll(AppPatterns.nameRegex, '')
        .trim();
  }

  /// 格式化作者
  /// 参考项目：BookHelp.formatBookAuthor
  String formatBookAuthor() {
    return author
        .replaceAll(AppPatterns.authorRegex, '')
        .trim();
  }

  // ========== 其他方法 ==========

  /// 搜索匹配
  bool contains(String? word) {
    if (word == null || word.isEmpty) {
      return true;
    }
    return name.contains(word) ||
        author.contains(word) ||
        originName.contains(word) ||
        origin.contains(word) ||
        (kind?.contains(word) ?? false) ||
        (intro?.contains(word) ?? false);
  }

  /// 同步书籍信息
  /// 参考项目：Book.sync
  Future<void> sync(Book oldBook) async {
    try {
      // 从数据库获取当前书籍信息
      final curBook = await BookService.instance.getBookByUrl(oldBook.bookUrl);
      if (curBook == null) return;

      // 同步阅读进度
      durChapterTime = curBook.durChapterTime;
      durChapterPos = curBook.durChapterPos;
      if (durChapterIndex != curBook.durChapterIndex) {
        durChapterIndex = curBook.durChapterIndex;
        durChapterTitle = curBook.durChapterTitle;
      }
      canUpdate = curBook.canUpdate;
      readConfig = curBook.readConfig;
    } catch (e) {
      AppLog.instance.put('同步书籍信息失败: ${oldBook.name}', error: e);
    }
  }

  /// 更新书籍到数据库
  /// 参考项目：Book.update
  Future<void> update() async {
    try {
      await BookService.instance.updateBook(this);
    } catch (e) {
      AppLog.instance.put('更新书籍失败: $name', error: e);
    }
  }

  /// 获取主键字符串
  String primaryStr() {
    return origin + bookUrl;
  }

  /// 更新到新书籍
  /// 参考项目：Book.updateTo
  Book updateTo(Book newBook) {
    newBook.durChapterIndex = durChapterIndex;
    newBook.durChapterTitle = durChapterTitle;
    newBook.durChapterPos = durChapterPos;
    newBook.durChapterTime = durChapterTime;
    newBook.group = group;
    newBook.order = order;
    newBook.customCoverUrl = customCoverUrl;
    newBook.customIntro = customIntro;
    newBook.customTag = customTag;
    newBook.canUpdate = canUpdate;
    newBook.readConfig = readConfig;

    // 合并变量
    final variableMap = this.variableMap;
    final newVariableMap = newBook.variableMap;
    variableMap.removeWhere((key, value) => newVariableMap.containsKey(key));
    newVariableMap.addAll(variableMap);
    newBook.variable = jsonEncode(newVariableMap);

    return newBook;
  }

  /// 检查是否有变量
  /// 参考项目：Book.hasVariable
  bool hasVariable(String key) {
    return variableMap.containsKey(key);
    // TODO: 支持 RuleBigDataHelp.hasBookVariable
  }

  /// 获取变量映射
  Map<String, dynamic> get variableMap {
    if (variable == null || variable!.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(variable!) as Map<String, dynamic>?;
      return decoded ?? {};
    } catch (e) {
      return {};
    }
  }

  /// 获取文件夹名（不含缓存）
  /// 参考项目：Book.getFolderNameNoCache
  String getFolderNameNoCache() {
    final cleanName = name.replaceAll(AppPatterns.fileNameRegex, '');
    final namePart = cleanName.length > 9 ? cleanName.substring(0, 9) : cleanName;
    final bytes = utf8.encode(bookUrl);
    final digest = md5.convert(bytes);
    final hash = digest.toString().substring(0, 16);
    return '$namePart$hash';
  }

  /// 获取文件夹名
  String getFolderName() {
    return getFolderNameNoCache();
  }

  /// 获取书源
  /// 参考项目：Book.getBookSource
  Future<BookSource?> getBookSource() async {
    return await BookSourceService.instance.getBookSourceByUrl(origin);
  }

  /// 是否本地修改
  /// 参考项目：Book.isLocalModified
  Future<bool> isLocalModified() async {
    if (!isLocal) return false;
    try {
      final file = File(bookUrl);
      if (await file.exists()) {
        final lastModified = await file.lastModified();
        return lastModified.millisecondsSinceEpoch > latestChapterTime;
      }
    } catch (e) {
      AppLog.instance.put('检查本地文件修改时间失败', error: e);
    }
    return false;
  }

  /// 释放HTML数据
  /// 参考项目：Book.releaseHtmlData
  /// 注意：当前 Book 模型没有 infoHtml 和 tocHtml 字段
  /// 这些数据通常用于临时存储，在 Flutter 中可以通过变量字段存储
  /// 如果需要这些字段，可以添加到 Book 模型中
  void releaseHtmlData() {
    // 参考项目：释放 infoHtml 和 tocHtml 字段
    // 当前 Book 模型没有这些字段，如果需要可以：
    // 1. 添加到 Book 模型（如：String? infoHtml; String? tocHtml;）
    // 2. 或使用 variable 字段存储（JSON格式）
    // 当前实现：空操作（如果需要可以扩展）
    // 如果添加了 infoHtml 和 tocHtml 字段，应该在这里设置为 null：
    // infoHtml = null;
    // tocHtml = null;
  }

  /// 是否同名同作者
  /// 参考项目：Book.isSameNameAuthor
  bool isSameNameAuthor(dynamic other) {
    if (other is BaseBook) {
      return name == other.name && author == other.author;
    }
    return false;
  }

  /// 获取导出文件名
  /// 参考项目：Book.getExportFileName
  Future<String> getExportFileName(String suffix) async {
    final jsStr = AppConfig.getBookExportFileName();
    if (jsStr.isEmpty) {
      return '$name 作者：${getRealAuthor()}.$suffix';
    }

    try {
      final bindings = <String, dynamic>{
        'epubIndex': '', // 兼容老版本
        'name': name,
        'author': getRealAuthor(),
      };
      final result = await JSEngine.evalJS(jsStr, bindings: bindings);
      return '$result.$suffix';
    } catch (e) {
      AppLog.instance.put('导出书名规则错误,使用默认规则', error: e);
      return '$name 作者：${getRealAuthor()}.$suffix';
    }
  }

  /// 获取分割文件后的文件名
  /// 参考项目：Book.getExportFileName(带epubIndex)
  Future<String> getExportFileNameWithIndex(String suffix, int epubIndex) async {
    final jsStr = AppConfig.getEpisodeExportFileName();
    final defaultName = '$name 作者：${getRealAuthor()} [$epubIndex].$suffix';

    if (jsStr.isEmpty) {
      return defaultName;
    }

    try {
      final bindings = <String, dynamic>{
        'name': name,
        'author': getRealAuthor(),
        'epubIndex': epubIndex,
      };
      final result = await JSEngine.evalJS(jsStr, bindings: bindings);
      // 规范化文件名（移除不允许的字符）
      final normalized = result.replaceAll(AppPatterns.fileNameRegex2, '_');
      return '$normalized.$suffix';
    } catch (e) {
      AppLog.instance.put('导出书名规则错误,使用默认规则', error: e);
      return defaultName;
    }
  }

  /// 获取真实作者（处理空作者）
  String getRealAuthor() {
    return author.isEmpty ? '未知' : author;
  }

  /// 模拟章节总数
  /// 参考项目：Book.simulatedTotalChapterNum
  int simulatedTotalChapterNum() {
    if (!readSimulating()) {
      return totalChapterNum;
    }

    try {
      // 计算模拟阅读的章节数
      // 参考项目：根据当前日期和书籍的模拟阅读配置计算
      final currentDate = DateTime.now();
      final startDate = readConfig?.simulateStartDate;
      if (startDate == null) {
        return totalChapterNum;
      }

      // 计算从开始日期到现在的天数
      final daysSinceStart = currentDate.difference(startDate).inDays;
      if (daysSinceStart < 0) {
        return 0; // 还未开始
      }

      // 每天解锁的章节数（默认1章）
      final chaptersPerDay = readConfig?.simulateChaptersPerDay ?? 1;
      final unlockedChapters = daysSinceStart * chaptersPerDay;

      // 返回已解锁的章节数和总章节数的较小值
      return unlockedChapters < totalChapterNum ? unlockedChapters : totalChapterNum;
    } catch (e) {
      AppLog.instance.put('计算模拟章节总数失败', error: e);
      return totalChapterNum;
    }
  }

  /// 是否模拟阅读
  /// 参考项目：Book.readSimulating
  bool readSimulating() {
    // 从 readConfig 中获取模拟阅读配置
    return readConfig?.simulateReading ?? false;
  }

  /// 是否使用替换规则
  /// 参考项目：Book.getUseReplaceRule
  bool getUseReplaceRule() {
    return readConfig?.useReplaceRule ?? true;
  }

  /// 是否重新分段
  /// 参考项目：Book.getReSegment
  bool getReSegment() {
    return readConfig?.reSegment ?? false;
  }

  /// 获取反转目录标志
  /// 参考项目：Book.getReverseToc
  /// reverseToc 存储在 variable 字段中
  bool getReverseToc() {
    final reverseTocStr = variableMap['reverseToc'];
    if (reverseTocStr == null || reverseTocStr.isEmpty) {
      return false;
    }
    return reverseTocStr.toLowerCase() == 'true' || reverseTocStr == '1';
  }
}

/// 尝试解析导出文件名规则
/// 参考项目：tryParesExportFileName
Future<bool> tryParseExportFileName(String jsStr) async {
  try {
    final bindings = <String, dynamic>{
      'name': 'name',
      'author': 'author',
      'epubIndex': 'epubIndex',
    };
    await JSEngine.evalJS(jsStr, bindings: bindings);
    return true;
  } catch (e) {
    return false;
  }
}

