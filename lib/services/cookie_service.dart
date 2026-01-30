import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/cookie.dart';
import '../utils/app_log.dart';

/// Cookie管理服务
/// 参考项目：io.legado.app.data.dao.CookieDao
class CookieService extends BaseService {
  static final CookieService instance = CookieService._init();
  final AppDatabase _db = AppDatabase.instance;

  CookieService._init();

  /// 获取Cookie
  Future<Cookie?> getCookie(String url) async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      final result = await db.query(
        'cookies',
        where: 'url = ?',
        whereArgs: [url],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return Cookie.fromJson(_convertDbToJson(result.first));
    } catch (e) {
      AppLog.instance.put('获取Cookie失败: $url', error: e);
      return null;
    }
  }

  /// 获取OkHttp格式的Cookie（url包含|的）
  Future<List<Cookie>> getOkHttpCookies() async {
    final db = await _db.database;
    if (db == null) return [];

    try {
      final result = await db.rawQuery(
        "SELECT * FROM cookies WHERE url LIKE '%|%'",
      );
      return result.map((row) => Cookie.fromJson(_convertDbToJson(row))).toList();
    } catch (e) {
      AppLog.instance.put('获取OkHttp Cookie失败', error: e);
      return [];
    }
  }

  /// 保存或更新Cookie
  Future<bool> saveCookie(Cookie cookie) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.insert(
        'cookies',
        cookie.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      AppLog.instance.put('保存Cookie失败: ${cookie.url}', error: e);
      return false;
    }
  }

  /// 保存或更新Cookie（通过URL和Cookie字符串）
  Future<bool> saveCookieByUrl(String url, String cookieStr) async {
    return await saveCookie(Cookie(url: url, cookie: cookieStr));
  }

  /// 删除Cookie
  Future<bool> deleteCookie(String url) async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.delete(
        'cookies',
        where: 'url = ?',
        whereArgs: [url],
      );
      return true;
    } catch (e) {
      AppLog.instance.put('删除Cookie失败: $url', error: e);
      return false;
    }
  }

  /// 删除OkHttp格式的Cookie
  Future<bool> deleteOkHttpCookies() async {
    final db = await _db.database;
    if (db == null) return false;

    try {
      await db.rawDelete("DELETE FROM cookies WHERE url LIKE '%|%'");
      return true;
    } catch (e) {
      AppLog.instance.put('删除OkHttp Cookie失败', error: e);
      return false;
    }
  }

  /// 保存书源的Cookie（兼容旧接口）
  Future<void> saveCookiesForSource(String sourceUrl, Map<String, String> cookies) async {
    try {
      // 将Map转换为Cookie字符串
      final cookieStr = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      
      // 保存到数据库
      await saveCookieByUrl(sourceUrl, cookieStr);
    } catch (e) {
      AppLog.instance.put('保存书源Cookie失败: $sourceUrl', error: e);
    }
  }

  /// 获取书源的Cookie（兼容旧接口）
  Future<Map<String, String>> getCookiesForSource(String sourceUrl) async {
    try {
      final cookie = await getCookie(sourceUrl);
      if (cookie == null || cookie.cookie.isEmpty) {
        return {};
      }

      // 解析Cookie字符串为Map
      final cookies = <String, String>{};
      final cookieList = cookie.cookie.split(';');
      for (final cookieItem in cookieList) {
        final parts = cookieItem.trim().split('=');
        if (parts.length == 2) {
          cookies[parts[0].trim()] = parts[1].trim();
        }
      }
      return cookies;
    } catch (e) {
      AppLog.instance.put('获取书源Cookie失败: $sourceUrl', error: e);
      return {};
    }
  }

  /// 清除书源的Cookie（兼容旧接口）
  Future<void> clearCookiesForSource(String sourceUrl) async {
    await deleteCookie(sourceUrl);
  }

  /// 清除所有Cookie（兼容旧接口）
  Future<void> clearAllCookies() async {
    final db = await _db.database;
    if (db == null) return;

    try {
      await db.delete('cookies');
    } catch (e) {
      AppLog.instance.put('清除所有Cookie失败', error: e);
    }
  }

  Map<String, dynamic> _convertDbToJson(Map<String, dynamic> dbRow) {
    return Map<String, dynamic>.from(dbRow);
  }
}
