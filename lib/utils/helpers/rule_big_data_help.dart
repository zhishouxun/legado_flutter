/// 大数据规则帮助类
/// 参考项目：io.legado.app.help.RuleBigDataHelp
///
/// 用于存储规则解析过程中的大数据变量（超出数据库字段限制的数据）
/// 数据存储在文件系统中，使用MD5作为文件名
///
/// 主要功能：
/// - 书籍变量存取（putBookVariable/getBookVariable）
/// - 章节变量存取（putChapterVariable/getChapterVariable）
/// - RSS变量存取（putRssVariable/getRssVariable）
/// - 无效数据清理（clearInvalid）
library;

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../../data/database/app_database.dart';
import '../file_utils.dart';
import '../app_log.dart';

/// 大数据规则帮助类
/// 参考项目：io.legado.app.help.RuleBigDataHelp
class RuleBigDataHelp {
  RuleBigDataHelp._();

  static Directory? _ruleDataDir;
  static Directory? _bookDataDir;
  static Directory? _rssDataDir;

  /// 初始化数据目录
  static Future<void> _ensureInitialized() async {
    if (_ruleDataDir != null) return;

    final appDir = await getApplicationSupportDirectory();
    _ruleDataDir = Directory('${appDir.path}/ruleData');
    _bookDataDir = Directory('${_ruleDataDir!.path}/book');
    _rssDataDir = Directory('${_ruleDataDir!.path}/rss');

    // 确保目录存在
    await _ruleDataDir!.create(recursive: true);
    await _bookDataDir!.create(recursive: true);
    await _rssDataDir!.create(recursive: true);
  }

  /// MD5编码
  static String _md5Encode(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  // ========== 书籍变量操作 ==========

  /// 存储书籍变量
  /// 参考项目：RuleBigDataHelp.putBookVariable
  ///
  /// [bookUrl] 书籍URL
  /// [key] 变量键
  /// [value] 变量值（null表示删除）
  static Future<void> putBookVariable(
    String bookUrl,
    String key,
    String? value,
  ) async {
    await _ensureInitialized();

    final md5BookUrl = _md5Encode(bookUrl);
    final md5Key = _md5Encode(key);
    final bookDir = Directory('${_bookDataDir!.path}/$md5BookUrl');
    final valueFile = File('${bookDir.path}/$md5Key.txt');
    final bookUrlFile = File('${bookDir.path}/bookUrl.txt');

    if (value == null) {
      // 删除变量
      if (await valueFile.exists()) {
        await valueFile.delete();
      }
      // 如果目录为空，删除目录
      if (await bookDir.exists()) {
        final files = await bookDir.list().toList();
        if (files.length <= 1) {
          // 只剩 bookUrl.txt
          await bookDir.delete(recursive: true);
        }
      }
    } else {
      // 存储变量
      await bookDir.create(recursive: true);
      await valueFile.writeAsString(value);

      // 存储原始 bookUrl 用于清理时验证
      if (!await bookUrlFile.exists()) {
        await bookUrlFile.writeAsString(bookUrl);
      }
    }
  }

  /// 获取书籍变量
  /// 参考项目：RuleBigDataHelp.getBookVariable
  ///
  /// [bookUrl] 书籍URL
  /// [key] 变量键
  ///
  /// 返回变量值，不存在返回null
  static Future<String?> getBookVariable(String bookUrl, String? key) async {
    if (key == null) return null;
    await _ensureInitialized();

    final md5BookUrl = _md5Encode(bookUrl);
    final md5Key = _md5Encode(key);
    final valueFile = File('${_bookDataDir!.path}/$md5BookUrl/$md5Key.txt');

    if (await valueFile.exists()) {
      return await valueFile.readAsString();
    }
    return null;
  }

  /// 检查书籍变量是否存在
  /// 参考项目：RuleBigDataHelp.hasBookVariable
  static Future<bool> hasBookVariable(String bookUrl, String key) async {
    await _ensureInitialized();

    final md5BookUrl = _md5Encode(bookUrl);
    final md5Key = _md5Encode(key);
    final valueFile = File('${_bookDataDir!.path}/$md5BookUrl/$md5Key.txt');

    return await valueFile.exists();
  }

  // ========== 章节变量操作 ==========

  /// 存储章节变量
  /// 参考项目：RuleBigDataHelp.putChapterVariable
  ///
  /// [bookUrl] 书籍URL
  /// [chapterUrl] 章节URL
  /// [key] 变量键
  /// [value] 变量值（null表示删除）
  static Future<void> putChapterVariable(
    String bookUrl,
    String chapterUrl,
    String key,
    String? value,
  ) async {
    await _ensureInitialized();

    final md5BookUrl = _md5Encode(bookUrl);
    final md5ChapterUrl = _md5Encode(chapterUrl);
    final md5Key = _md5Encode(key);
    final chapterDir =
        Directory('${_bookDataDir!.path}/$md5BookUrl/$md5ChapterUrl');
    final valueFile = File('${chapterDir.path}/$md5Key.txt');

    if (value == null) {
      // 删除变量
      if (await valueFile.exists()) {
        await valueFile.delete();
      }
    } else {
      // 存储变量
      await chapterDir.create(recursive: true);
      await valueFile.writeAsString(value);

      // 存储原始 bookUrl 用于清理时验证
      final bookUrlFile = File('${_bookDataDir!.path}/$md5BookUrl/bookUrl.txt');
      if (!await bookUrlFile.exists()) {
        await Directory('${_bookDataDir!.path}/$md5BookUrl')
            .create(recursive: true);
        await bookUrlFile.writeAsString(bookUrl);
      }
    }
  }

  /// 获取章节变量
  /// 参考项目：RuleBigDataHelp.getChapterVariable
  ///
  /// [bookUrl] 书籍URL
  /// [chapterUrl] 章节URL
  /// [key] 变量键
  ///
  /// 返回变量值，不存在返回null
  static Future<String?> getChapterVariable(
    String bookUrl,
    String chapterUrl,
    String key,
  ) async {
    await _ensureInitialized();

    final md5BookUrl = _md5Encode(bookUrl);
    final md5ChapterUrl = _md5Encode(chapterUrl);
    final md5Key = _md5Encode(key);
    final valueFile =
        File('${_bookDataDir!.path}/$md5BookUrl/$md5ChapterUrl/$md5Key.txt');

    if (await valueFile.exists()) {
      return await valueFile.readAsString();
    }
    return null;
  }

  // ========== RSS变量操作 ==========

  /// 存储RSS变量
  /// 参考项目：RuleBigDataHelp.putRssVariable
  ///
  /// [origin] RSS源URL
  /// [link] 文章链接
  /// [key] 变量键
  /// [value] 变量值（null表示删除）
  static Future<void> putRssVariable(
    String origin,
    String link,
    String key,
    String? value,
  ) async {
    await _ensureInitialized();

    final md5Origin = _md5Encode(origin);
    final md5Link = _md5Encode(link);
    final md5Key = _md5Encode(key);
    final linkDir = Directory('${_rssDataDir!.path}/$md5Origin/$md5Link');
    final valueFile = File('${linkDir.path}/$md5Key.txt');

    if (value == null) {
      // 删除变量
      if (await valueFile.exists()) {
        await valueFile.delete();
      }
    } else {
      // 存储变量
      await linkDir.create(recursive: true);
      await valueFile.writeAsString(value);

      // 存储原始 origin 用于清理时验证
      final originFile = File('${_rssDataDir!.path}/$md5Origin/origin.txt');
      if (!await originFile.exists()) {
        await Directory('${_rssDataDir!.path}/$md5Origin')
            .create(recursive: true);
        await originFile.writeAsString(origin);
      }

      // 存储原始 link
      final linkFile =
          File('${_rssDataDir!.path}/$md5Origin/$md5Link/origin.txt');
      if (!await linkFile.exists()) {
        await linkFile.writeAsString(link);
      }
    }
  }

  /// 获取RSS变量
  /// 参考项目：RuleBigDataHelp.getRssVariable
  ///
  /// [origin] RSS源URL
  /// [link] 文章链接
  /// [key] 变量键
  ///
  /// 返回变量值，不存在返回null
  static Future<String?> getRssVariable(
    String origin,
    String link,
    String key,
  ) async {
    await _ensureInitialized();

    final md5Origin = _md5Encode(origin);
    final md5Link = _md5Encode(link);
    final md5Key = _md5Encode(key);
    final valueFile =
        File('${_rssDataDir!.path}/$md5Origin/$md5Link/$md5Key.txt');

    if (await valueFile.exists()) {
      return await valueFile.readAsString();
    }
    return null;
  }

  // ========== 数据清理 ==========

  /// 清除无效数据
  /// 参考项目：RuleBigDataHelp.clearInvalid
  ///
  /// 清除已删除书籍和RSS源的相关数据
  static Future<void> clearInvalid() async {
    await _ensureInitialized();
    final db = await AppDatabase.instance.database;
    if (db == null) return;

    // 清理无效的书籍数据
    if (await _bookDataDir!.exists()) {
      await for (final entity in _bookDataDir!.list()) {
        if (entity is Directory) {
          final bookUrlFile = File('${entity.path}/bookUrl.txt');
          if (!await bookUrlFile.exists()) {
            // 没有 bookUrl.txt，删除整个目录
            await entity.delete(recursive: true);
          } else {
            final bookUrl = await bookUrlFile.readAsString();
            // 检查书籍是否存在
            try {
              final result = await db.query(
                'books',
                where: 'bookUrl = ?',
                whereArgs: [bookUrl],
                limit: 1,
              );
              if (result.isEmpty) {
                // 书籍不存在，删除数据
                await entity.delete(recursive: true);
              }
            } catch (e) {
              AppLog.instance.put('clearInvalid book error: $e');
            }
          }
        } else if (entity is File) {
          // 根目录下的文件直接删除
          await entity.delete();
        }
      }
    }

    // 清理无效的RSS数据
    if (await _rssDataDir!.exists()) {
      await for (final entity in _rssDataDir!.list()) {
        if (entity is Directory) {
          final originFile = File('${entity.path}/origin.txt');
          if (!await originFile.exists()) {
            // 没有 origin.txt，删除整个目录
            await entity.delete(recursive: true);
          } else {
            final origin = await originFile.readAsString();
            // 检查RSS源是否存在
            try {
              final result = await db.query(
                'rssSources',
                where: 'sourceUrl = ?',
                whereArgs: [origin],
                limit: 1,
              );
              if (result.isEmpty) {
                // RSS源不存在，删除数据
                await entity.delete(recursive: true);
              }
            } catch (e) {
              AppLog.instance.put('clearInvalid rss error: $e');
            }
          }
        } else if (entity is File) {
          // 根目录下的文件直接删除
          await entity.delete();
        }
      }
    }
  }

  /// 清除所有数据
  static Future<void> clearAll() async {
    await _ensureInitialized();

    if (await _bookDataDir!.exists()) {
      await _bookDataDir!.delete(recursive: true);
      await _bookDataDir!.create(recursive: true);
    }

    if (await _rssDataDir!.exists()) {
      await _rssDataDir!.delete(recursive: true);
      await _rssDataDir!.create(recursive: true);
    }
  }

  /// 获取数据目录大小（字节）
  static Future<int> getDataSize() async {
    await _ensureInitialized();
    return await FileUtils.getDirectorySize(_ruleDataDir!.path);
  }
}
