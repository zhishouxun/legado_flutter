import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../core/base/base_service.dart';
import '../../config/app_config.dart';
import '../../data/models/book.dart';
import '../../data/models/book_source.dart';
import '../book/book_service.dart';
import '../source/book_source_service.dart';
import '../bookmark_service.dart';
import '../book_group_service.dart';
import '../dict_rule_service.dart';
import '../replace_rule_service.dart';
import '../txt_toc_rule_service.dart';
import '../../utils/app_log.dart';
import 'webdav_service.dart';

/// 备份服务
class BackupService extends BaseService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  /// 获取备份目录
  Future<Directory> _getBackupDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backup');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 获取临时备份文件路径
  Future<String> _getTempBackupPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/tmp_backup.zip';
  }

  /// 生成备份文件名
  String _generateBackupFileName() {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateStr = dateFormat.format(now);
    final deviceName = AppConfig.getString('webdav_device_name', defaultValue: 'device');
    return 'backup$dateStr-$deviceName.zip';
  }

  /// 创建备份
  Future<String> createBackup() async {
    try {
      final backupDir = await _getBackupDir();
      final tempPath = await _getTempBackupPath();

      // 清理旧的备份文件
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // 清理备份目录
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
        await backupDir.create(recursive: true);
      }

      // 备份数据
      await _backupData(backupDir);

      // 压缩为ZIP文件
      final archive = Archive();
      final files = backupDir.listSync(recursive: true);
      
      for (final file in files) {
        if (file is File) {
          final relativePath = file.path.replaceFirst('${backupDir.path}/', '');
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        }
      }

      // 保存ZIP文件
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        throw Exception('压缩失败');
      }

      await File(tempPath).writeAsBytes(zipBytes);

      // 更新最后备份时间
      await AppConfig.setInt('last_backup_time', DateTime.now().millisecondsSinceEpoch ~/ 1000);

      return tempPath;
    } catch (e) {
      AppLog.instance.put('创建备份失败', error: e);
      rethrow;
    }
  }

  /// 备份数据到目录
  Future<void> _backupData(Directory backupDir) async {
      // 备份书架
      final books = await BookService.instance.getBookshelfBooks();
      await _writeJsonFile(backupDir, 'bookshelf.json', books.map((Book b) => b.toJson()).toList());

    // 备份书源
    final bookSources = await BookSourceService.instance.getAllBookSources();
    await _writeJsonFile(backupDir, 'bookSource.json', bookSources.map((BookSource s) => s.toJson()).toList());

    // 备份书签
    final bookmarks = await BookmarkService.instance.getAllBookmarks();
    await _writeJsonFile(backupDir, 'bookmark.json', bookmarks.map((b) => b.toMap()).toList());

    // 备份书籍分组
    final bookGroups = await BookGroupService.instance.getAllGroups(showOnly: false);
    await _writeJsonFile(backupDir, 'bookGroup.json', bookGroups.map((g) => g.toJson()).toList());

    // 备份替换规则
    final replaceRules = await ReplaceRuleService.instance.getAllRules();
    await _writeJsonFile(backupDir, 'replaceRule.json', replaceRules.map((r) => r.toJson()).toList());

    // 备份字典规则
    final dictRules = await DictRuleService.instance.getAllRules();
    await _writeJsonFile(backupDir, 'dictRule.json', dictRules.map((r) => r.toJson()).toList());

    // 备份TXT目录规则
    final txtTocRules = await TxtTocRuleService.instance.getAllRules();
    await _writeJsonFile(backupDir, 'txtTocRule.json', txtTocRules.map((r) => r.toJson()).toList());

    // 备份配置
    await _backupConfig(backupDir);
  }

  /// 备份配置
  Future<void> _backupConfig(Directory backupDir) async {
    // 这里可以备份其他配置，如阅读配置、主题配置等
    // 暂时只备份基本配置
    final config = <String, dynamic>{
      'bookshelf_layout': AppConfig.getBookshelfLayout(),
      'shared_layout': AppConfig.getSharedLayout(),
      'theme_mode': AppConfig.getString('theme_mode', defaultValue: 'system'),
    };
    await _writeJsonFile(backupDir, 'config.json', config);
  }

  /// 写入JSON文件
  Future<void> _writeJsonFile(Directory dir, String filename, dynamic data) async {
    final file = File('${dir.path}/$filename');
    final jsonString = jsonEncode(data);
    await file.writeAsString(jsonString);
  }

  /// 备份到本地文件
  Future<String> backupToLocal(String? savePath) async {
    final zipPath = await createBackup();
    
    if (savePath != null) {
      final sourceFile = File(zipPath);
      final targetFile = File(savePath);
      await sourceFile.copy(targetFile.path);
      return savePath;
    }
    
    return zipPath;
  }

  /// 备份到WebDAV
  Future<void> backupToWebDav() async {
    try {
      await WebDavService.instance.loadConfig();
      if (!WebDavService.instance.isConfigured) {
        throw Exception('WebDAV未配置');
      }

      // 检查连接
      final isOk = await WebDavService.instance.check();
      if (!isOk) {
        throw Exception('WebDAV连接失败');
      }

      // 创建备份
      final zipPath = await createBackup();
      final fileName = _generateBackupFileName();

      // 上传到WebDAV
      await WebDavService.instance.upload(zipPath, remotePath: fileName);

      AppLog.instance.put('备份到WebDAV成功: $fileName');
    } catch (e) {
      AppLog.instance.put('备份到WebDAV失败', error: e);
      rethrow;
    }
  }

  /// 获取最后备份时间
  int getLastBackupTime() {
    return AppConfig.getInt('last_backup_time', defaultValue: 0);
  }

  /// 检查是否需要自动备份
  bool shouldAutoBackup() {
    final lastBackup = getLastBackupTime();
    if (lastBackup == 0) return true;
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final oneDayInSeconds = 24 * 60 * 60;
    return (now - lastBackup) > oneDayInSeconds;
  }
}

