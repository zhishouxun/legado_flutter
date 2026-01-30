import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/base/base_service.dart';
import '../../data/models/book.dart';
import '../../data/models/bookmark.dart';
import '../../data/models/book_group.dart';
import '../../data/models/book_source.dart';
import '../../data/models/replace_rule.dart';
import '../../data/models/dict_rule.dart';
import '../../data/models/txt_toc_rule.dart';
import '../book/book_service.dart';
import '../source/book_source_service.dart';
import '../bookmark_service.dart';
import '../book_group_service.dart';
import '../replace_rule_service.dart';
import '../dict_rule_service.dart';
import '../txt_toc_rule_service.dart';
import '../../config/app_config.dart';
import '../../utils/app_log.dart';
import 'webdav_service.dart';

/// 恢复服务
class RestoreService extends BaseService {
  static final RestoreService instance = RestoreService._init();
  RestoreService._init();

  /// 获取备份目录
  Future<Directory> _getBackupDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backup');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 从本地文件恢复
  Future<void> restoreFromLocal(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在');
      }

      // 解压备份文件
      final backupDir = await _getBackupDir();
      
      // 清理旧的备份目录
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
        await backupDir.create(recursive: true);
      }

      // 读取ZIP文件
      final zipBytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // 解压文件
      for (final file in archive) {
        if (file.isFile) {
          final filePath = '${backupDir.path}/${file.name}';
          final fileDir = Directory(filePath.substring(0, filePath.lastIndexOf('/')));
          if (!await fileDir.exists()) {
            await fileDir.create(recursive: true);
          }
          await File(filePath).writeAsBytes(file.content as List<int>);
        }
      }

      // 恢复数据
      await _restoreData(backupDir);

      // 更新最后备份时间
      await AppConfig.setInt('last_backup_time', DateTime.now().millisecondsSinceEpoch ~/ 1000);

      AppLog.instance.put('恢复备份成功');
    } catch (e) {
      AppLog.instance.put('恢复备份失败', error: e);
      rethrow;
    }
  }

  /// 从WebDAV恢复
  Future<void> restoreFromWebDav(String backupFileName) async {
    try {
      await WebDavService.instance.loadConfig();
      if (!WebDavService.instance.isConfigured) {
        throw Exception('WebDAV未配置');
      }

      // 下载备份文件
      final backupDir = await _getBackupDir();
      final tempZipPath = '${backupDir.path}/temp_restore.zip';
      
      await WebDavService.instance.downloadTo(backupFileName, tempZipPath);

      // 从本地文件恢复
      await restoreFromLocal(tempZipPath);

      // 清理临时文件
      final tempFile = File(tempZipPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      AppLog.instance.put('从WebDAV恢复失败', error: e);
      rethrow;
    }
  }

  /// 恢复数据
  Future<void> _restoreData(Directory backupDir) async {
    // 恢复书籍分组
    await _restoreBookGroups(backupDir);

    // 恢复书架
    await _restoreBooks(backupDir);

    // 恢复书源
    await _restoreBookSources(backupDir);

    // 恢复书签
    await _restoreBookmarks(backupDir);

    // 恢复替换规则
    await _restoreReplaceRules(backupDir);

    // 恢复字典规则
    await _restoreDictRules(backupDir);

    // 恢复TXT目录规则
    await _restoreTxtTocRules(backupDir);

    // 恢复配置
    await _restoreConfig(backupDir);
  }

  /// 恢复书籍分组
  Future<void> _restoreBookGroups(Directory backupDir) async {
    final file = File('${backupDir.path}/bookGroup.json');
    if (!await file.exists()) return;

    try {
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      final groups = jsonList.map((json) => BookGroup.fromJson(json as Map<String, dynamic>)).toList();

      for (final group in groups) {
        // 跳过系统内置分组
        if (group.groupId < 0) continue;
        await BookGroupService.instance.createGroup(group);
      }
    } catch (e) {
      AppLog.instance.put('恢复书籍分组失败', error: e);
    }
  }

  /// 恢复书架
  Future<void> _restoreBooks(Directory backupDir) async {
    final file = File('${backupDir.path}/bookshelf.json');
    if (!await file.exists()) return;

    try {
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      final books = jsonList.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();

      for (final book in books) {
        try {
          // 检查书籍是否已存在
          final existingBook = await BookService.instance.getBookByUrl(book.bookUrl);
          if (existingBook != null) {
            // 更新现有书籍
            await BookService.instance.saveBook(book);
          } else {
            // 添加新书籍
            await BookService.instance.createBook(book);
          }
        } catch (e) {
          // 跳过失败的书籍，继续恢复其他书籍
          AppLog.instance.put('恢复书籍失败: ${book.name}', error: e);
        }
      }
    } catch (e) {
      AppLog.instance.put('恢复书架失败', error: e);
    }
  }

  /// 恢复书源
  Future<void> _restoreBookSources(Directory backupDir) async {
    final file = File('${backupDir.path}/bookSource.json');
    if (!await file.exists()) return;

    try {
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      final sources = jsonList.map((json) => BookSource.fromJson(json as Map<String, dynamic>)).toList();

      for (final source in sources) {
        try {
          // 检查书源是否已存在
          final existing = await BookSourceService.instance.getBookSourceByUrl(source.bookSourceUrl);
          if (existing != null) {
            await BookSourceService.instance.updateBookSource(source);
          } else {
            await BookSourceService.instance.addBookSource(source);
          }
        } catch (e) {
          AppLog.instance.put('恢复书源失败: ${source.bookSourceName}', error: e);
        }
      }
    } catch (e) {
      AppLog.instance.put('恢复书源失败', error: e);
    }
  }

  /// 恢复书签
  Future<void> _restoreBookmarks(Directory backupDir) async {
    final file = File('${backupDir.path}/bookmark.json');
    if (!await file.exists()) return;

    try {
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      final bookmarks = jsonList.map((json) => Bookmark.fromMap(json as Map<String, dynamic>)).toList();

      for (final bookmark in bookmarks) {
        try {
          await BookmarkService.instance.addBookmark(bookmark);
        } catch (e) {
          // 书签可能已存在，跳过
        }
      }
    } catch (e) {
      AppLog.instance.put('恢复书签失败', error: e);
    }
  }

  /// 恢复替换规则
  Future<void> _restoreReplaceRules(Directory backupDir) async {
    final file = File('${backupDir.path}/replaceRule.json');
    if (!await file.exists()) return;

    try {
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      final rules = jsonList.map((json) => ReplaceRule.fromJson(json as Map<String, dynamic>)).toList();

      for (final rule in rules) {
        try {
          await ReplaceRuleService.instance.addOrUpdateRule(rule);
        } catch (e) {
          AppLog.instance.put('恢复替换规则失败: ${rule.name}', error: e);
        }
      }
    } catch (e) {
      AppLog.instance.put('恢复替换规则失败', error: e);
    }
  }

  /// 恢复字典规则
  Future<void> _restoreDictRules(Directory backupDir) async {
    final file = File('${backupDir.path}/dictRule.json');
    if (!await file.exists()) return;

    try {
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      final rules = jsonList.map((json) => DictRule.fromJson(json as Map<String, dynamic>)).toList();

      for (final rule in rules) {
        try {
          await DictRuleService.instance.addOrUpdateRule(rule);
        } catch (e) {
          AppLog.instance.put('恢复字典规则失败: ${rule.name}', error: e);
        }
      }
    } catch (e) {
      AppLog.instance.put('恢复字典规则失败', error: e);
    }
  }

  /// 恢复TXT目录规则
  Future<void> _restoreTxtTocRules(Directory backupDir) async {
    final file = File('${backupDir.path}/txtTocRule.json');
    if (!await file.exists()) return;

    try {
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      final rules = jsonList.map((json) => TxtTocRule.fromJson(json as Map<String, dynamic>)).toList();

      for (final rule in rules) {
        try {
          // 检查规则是否已存在
          final existing = await TxtTocRuleService.instance.getRuleById(rule.id);
          if (existing != null) {
            await TxtTocRuleService.instance.updateRule(rule);
          } else {
            await TxtTocRuleService.instance.addRule(rule);
          }
        } catch (e) {
          AppLog.instance.put('恢复TXT目录规则失败: ${rule.name}', error: e);
        }
      }
    } catch (e) {
      AppLog.instance.put('恢复TXT目录规则失败', error: e);
    }
  }

  /// 恢复配置
  Future<void> _restoreConfig(Directory backupDir) async {
    final file = File('${backupDir.path}/config.json');
    if (!await file.exists()) return;

    try {
      final jsonString = await file.readAsString();
      final config = jsonDecode(jsonString) as Map<String, dynamic>;

      if (config.containsKey('bookshelf_layout')) {
        await AppConfig.setBookshelfLayout(config['bookshelf_layout'] as int);
      }
      if (config.containsKey('shared_layout')) {
        await AppConfig.setSharedLayout(config['shared_layout'] as bool);
      }
      if (config.containsKey('theme_mode')) {
        await AppConfig.setString('theme_mode', config['theme_mode'] as String);
      }
    } catch (e) {
      AppLog.instance.put('恢复配置失败', error: e);
    }
  }

  /// 获取WebDAV备份列表
  Future<List<String>> getWebDavBackupList() async {
    try {
      await WebDavService.instance.loadConfig();
      if (!WebDavService.instance.isConfigured) {
        return [];
      }

      final files = await WebDavService.instance.listFiles();
      final backupFiles = files
          .where((file) => file.name.startsWith('backup') && file.name.endsWith('.zip'))
          .map((file) => file.name)
          .toList();

      // 按名称排序（最新的在前）
      backupFiles.sort((a, b) => b.compareTo(a));
      return backupFiles;
    } catch (e) {
      AppLog.instance.put('获取WebDAV备份列表失败', error: e);
      return [];
    }
  }
}

