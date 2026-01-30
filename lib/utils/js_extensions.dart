/// JavaScript扩展对象
/// 参考项目：io.legado.app.help.JsExtensions
///
/// 提供JavaScript执行环境中的全局对象和方法
///
/// 主要差异说明：
/// 1. JavaScript 引擎差异：
///    - 参考项目：Rhino v1.8.0（Java），可以直接调用 Java 类和方法
///    - 当前项目：flutter_js（QuickJS），需要通过桥接函数实现
///
/// 2. 函数调用方式差异：
///    - 参考项目：同步调用 Java 方法（如 java.ajax() 是同步的）
///    - 当前项目：异步桥接（如 java.ajax() 返回 Promise，需要使用 await）
///
/// 3. 已实现的函数：
///    - 网络请求：ajax, connect
///    - Cookie 操作：getCookie
///    - 编码解码：base64Encode, base64Decode, encodeURI
///    - 简繁转换：t2s, s2t（异步实现）
///    - 加密解密：createSymmetricCrypto, createAsymmetricCrypto, createSign
///    - 文件操作：readTxtFile, cacheFile, importScript
///    - 工具方法：md5Encode, hexEncode, timeFormat 等
///
/// 4. 部分函数限制：
///    - getString, getStringList, setContent, getElement, getElements：
///      这些函数需要访问 RuleParser 的解析上下文，在当前 JavaScript 上下文中
///      可能无法完全工作，需要在实际使用时传入正确的上下文
///
/// 5. 已实现的 WebView 相关函数（有限制）：
///    - webView: 后台 WebView 请求（简化实现）
///    - webViewGetSource: 获取资源 URL
///    - webViewGetOverrideUrl: 获取跳转 URL
///    - startBrowser: 打开浏览器（需要前端配合）
///    - getWebViewUA: 获取 WebView User-Agent
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../data/models/book_source.dart';
import '../data/models/book.dart';
import '../services/cookie_service.dart';
import '../services/network/network_service.dart';
import '../services/reader/cache_service.dart';
import '../utils/chinese_utils.dart';
import '../utils/cache_manager.dart';
import '../utils/file_utils.dart';
import 'app_log.dart';
import 'js_encode_utils.dart';
import 'query_ttf.dart';
import '../services/web/backstage_webview.dart';

/// JavaScript扩展对象工厂
class JSExtensions {
  final BookSource? source;
  final Book? book;
  final String? baseUrl;
  final String? chapterTitle;

  JSExtensions({
    this.source,
    this.book,
    this.baseUrl,
    this.chapterTitle,
  });

  /// 创建全局对象绑定
  /// 参考项目：AnalyzeRule.evalJS 中的 bindings
  Map<String, dynamic> createBindings() {
    return {
      'java': _createJavaObject(),
      'cookie': _createCookieObject(),
      'cache': _createCacheObject(),
      'source': _createSourceObject(),
      'book': _createBookObject(),
      'baseUrl': baseUrl ?? '',
      'chapter': chapterTitle ?? '',
      'title': chapterTitle ?? '',
    };
  }

  /// 创建 java 对象（提供各种工具方法）
  /// 参考项目：JsExtensions.kt
  ///
  /// 注意：函数会被 JSEngine 自动识别并绑定为可调用的 JavaScript 函数
  ///
  /// 差异说明：
  /// - 参考项目使用 Rhino（Java），可以直接调用 Java 类和方法
  /// - 当前项目使用 flutter_js（QuickJS），需要通过桥接函数实现
  /// - 部分同步函数在参考项目中是同步的，但当前项目实现为异步（返回 Promise）
  Map<String, dynamic> _createJavaObject() {
    return {
      // 网络请求（异步函数）
      'ajax': _ajax,
      'connect': _connect,

      // Cookie操作（异步函数）
      'getCookie': _getCookie,

      // 编码解码（同步函数）
      'base64Encode': _base64Encode,
      'base64Decode': _base64Decode,
      'encodeURI': _encodeURI,

      // 简繁转换（异步函数，返回 Promise）
      // 注意：参考项目中是同步的，但当前项目实现为异步
      't2s': _t2s,
      's2t': _s2t,

      // 日志（同步函数）
      'log': _log,
      'logType': _logType, // 新增：输出变量类型

      // 工具方法（同步函数）
      'md5Encode16': _md5Encode16,
      'md5Encode32': _md5Encode32,
      'md5Encode': _md5Encode32, // 别名

      // 加密解密（同步函数）
      'createSymmetricCrypto': _createSymmetricCrypto,
      'createAsymmetricCrypto': _createAsymmetricCrypto,
      'createSign': _createSign,
      'digestHex': _digestHex,
      'digestBase64Str': _digestBase64Str,
      'HMacHex': _hMacHex,
      'HMacBase64': _hMacBase64,

      // 文件操作（异步函数）
      'readTxtFile': _readTxtFile,
      'cacheFile': _cacheFile,
      'importScript': _importScript, // 新增：导入脚本

      // 规则解析（新增，参考项目：AnalyzeRule.getString）
      // 注意：这些函数在当前上下文中可能无法使用，因为需要访问 RuleParser
      // 暂时提供占位实现，实际使用时需要传入正确的上下文
      'getString': _getString, // 新增：解析规则获取字符串
      'getStringList': _getStringList, // 新增：解析规则获取字符串列表
      'setContent': _setContent, // 新增：设置解析内容
      'getElement': _getElement, // 新增：获取单个元素
      'getElements': _getElements, // 新增：获取元素列表

      // 变量存取（新增，参考项目：AnalyzeRule.get/put）
      'get': _getVariable, // 新增：获取变量
      'put': _putVariable, // 新增：设置变量

      // URL 解析（新增，参考项目：JsURL）
      'toURL': _toURL, // 新增：URL 解析

      // 时间格式化（新增）
      'timeFormat': _timeFormat, // 新增：时间格式化
      'timeFormatUTC': _timeFormatUTC, // 新增：UTC 时间格式化

      // 随机ID（新增）
      'randomUUID': _randomUUID, // 新增：生成随机UUID
      'androidId': _androidId, // 新增：获取Android ID（当前项目返回设备ID）

      // Hex 编码解码（新增）
      'hexEncodeToString': _hexEncodeToString, // 新增：Hex 编码
      'hexDecodeToString': _hexDecodeToString, // 新增：Hex 解码
      'hexDecodeToByteArray': _hexDecodeToByteArray, // 新增：Hex 解码为字节数组

      // 字符串和字节数组转换（新增）
      'strToBytes': _strToBytes, // 新增：字符串转字节数组
      'bytesToStr': _bytesToStr, // 新增：字节数组转字符串

      // HTML 格式化（新增）
      'htmlFormat': _htmlFormat, // 新增：HTML 格式化

      // WebView 相关（新增）
      'webView': _webView, // 新增：后台 WebView 请求
      'webViewGetSource': _webViewGetSource, // 新增：获取资源 URL
      'webViewGetOverrideUrl': _webViewGetOverrideUrl, // 新增：获取跳转 URL
      'startBrowser': _startBrowser, // 新增：打开浏览器
      'startBrowserAwait': _startBrowserAwait, // 新增：打开浏览器并等待结果
      'getVerificationCode': _getVerificationCode, // 新增：获取验证码
      'getWebViewUA': _getWebViewUA, // 新增：获取 WebView UA

      // 并发请求（新增）
      'ajaxAll': _ajaxAll, // 新增：并发访问网络

      // 文件操作（新增）
      'getFile': _getFile, // 新增：获取文件路径
      'readFile': _readFile, // 新增：读取文件字节
      'deleteFile': _deleteFile, // 新增：删除文件
      'downloadFile': _downloadFile, // 新增：下载文件

      // 网络请求增强（新增）
      'httpGet': _httpGet, // 新增：HTTP GET 请求
      'head': _httpHead, // 新增：HTTP HEAD 请求
      'post': _httpPost, // 新增：HTTP POST 请求

      // 字体解析（新增，用于防盗版字体替换）
      'queryTTF': _queryTTF, // 新增：解析 TTF 字体
      'queryBase64TTF': _queryTTF, // 别名（已废弃）
      'replaceFont': _replaceFont, // 新增：字体替换
    };
  }

  /// 创建 cookie 对象
  /// 参考项目：CookieStore
  Map<String, dynamic> _createCookieObject() {
    final tag = source?.bookSourceUrl ?? '';
    return {
      // 异步函数，支持 Promise
      'get': (dynamic key) => _getCookie(tag, key?.toString()),
      'getCookie': (dynamic key) => _getCookie(tag, key?.toString()),
    };
  }

  /// 创建 cache 对象
  /// 参考项目：CacheManager
  Map<String, dynamic> _createCacheObject() {
    return {
      // 异步函数，支持 Promise
      'get': (dynamic key) => _cacheGet(key?.toString() ?? ''),
      'put': (dynamic key, dynamic value, [dynamic saveTime]) => _cachePut(
          key?.toString() ?? '',
          value?.toString() ?? '',
          saveTime is int
              ? saveTime
              : (saveTime != null
                  ? int.tryParse(saveTime.toString()) ?? 0
                  : 0)),
    };
  }

  /// 创建 source 对象（书源信息）
  Map<String, dynamic> _createSourceObject() {
    if (source == null) return {};
    return {
      'bookSourceUrl': source!.bookSourceUrl,
      'bookSourceName': source!.bookSourceName,
      'bookSourceGroup': source!.bookSourceGroup,
      'header': source!.header,
      'loginUrl': source!.loginUrl,
      'enabledCookieJar': source!.enabledCookieJar,
    };
  }

  /// 创建 book 对象（书籍信息）
  Map<String, dynamic> _createBookObject() {
    if (book == null) return {};
    return {
      'bookUrl': book!.bookUrl,
      'name': book!.name,
      'author': book!.author,
      'origin': book!.origin,
      'originName': book!.originName,
      'tocUrl': book!.tocUrl,
      'coverUrl': book!.coverUrl,
      'intro': book!.intro,
    };
  }

  // ========== Java对象方法实现 ==========

  /// ajax - 访问网络，返回String
  /// 参考项目：JsExtensions.ajax
  Future<String> _ajax(dynamic url) async {
    try {
      final urlStr = url is List ? url.first.toString() : url.toString();
      final response = await NetworkService.instance.get(urlStr);
      final html = await NetworkService.getResponseText(response);
      return html;
    } catch (e) {
      AppLog.instance.put('ajax($url) error: $e');
      return e.toString();
    }
  }

  /// connect - 访问网络，返回Response对象（简化版）
  /// 参考项目：JsExtensions.connect
  Future<Map<String, dynamic>> _connect(String urlStr, [String? header]) async {
    try {
      Map<String, String>? headers;
      if (header != null && header.isNotEmpty) {
        try {
          final decoded = jsonDecode(header) as Map<String, dynamic>?;
          if (decoded != null) {
            headers = decoded.map((k, v) => MapEntry(k, v.toString()));
          }
        } catch (e) {
          headers = NetworkService.parseHeaders(header);
        }
      }

      final response =
          await NetworkService.instance.get(urlStr, headers: headers);
      final html = await NetworkService.getResponseText(response);

      return {
        'url': urlStr,
        'body': html,
        'statusCode': response.statusCode ?? 200,
        'headers': response.headers.map,
      };
    } catch (e) {
      AppLog.instance.put('connect($urlStr) error: $e');
      return {
        'url': urlStr,
        'body': e.toString(),
        'statusCode': 0,
        'headers': {},
      };
    }
  }

  /// getCookie - 获取Cookie
  /// 参考项目：JsExtensions.getCookie
  Future<String> _getCookie(String tag, [String? key]) async {
    try {
      if (key != null && key.isNotEmpty) {
        // 获取指定key的cookie
        final cookies = await CookieService.instance.getCookiesForSource(tag);
        return cookies[key] ?? '';
      } else {
        // 获取所有cookie
        final cookies = await CookieService.instance.getCookiesForSource(tag);
        return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      }
    } catch (e) {
      AppLog.instance.put('getCookie($tag, $key) error: $e');
      return '';
    }
  }

  /// base64Encode - Base64编码
  String _base64Encode(String str) {
    try {
      final bytes = utf8.encode(str);
      return base64Encode(bytes);
    } catch (e) {
      AppLog.instance.put('base64Encode error: $e');
      return '';
    }
  }

  /// base64Decode - Base64解码
  String _base64Decode(String str) {
    try {
      final bytes = base64Decode(str);
      return utf8.decode(bytes);
    } catch (e) {
      AppLog.instance.put('base64Decode error: $e');
      return '';
    }
  }

  /// encodeURI - URI编码
  String _encodeURI(String str) {
    try {
      return Uri.encodeComponent(str);
    } catch (e) {
      AppLog.instance.put('encodeURI error: $e');
      return str;
    }
  }

  /// t2s - 繁体转简体（异步函数）
  Future<String> _t2s(String text) async {
    return await ChineseUtils.t2s(text);
  }

  /// s2t - 简体转繁体（异步函数）
  Future<String> _s2t(String text) async {
    return await ChineseUtils.s2t(text);
  }

  /// log - 输出调试日志
  dynamic _log(dynamic msg) {
    final sourceTag = source?.bookSourceName ?? '源';
    AppLog.instance.put('[$sourceTag] 调试输出: $msg');
    return msg;
  }

  /// md5Encode16 - MD5编码（16位）
  String _md5Encode16(String str) {
    try {
      final bytes = utf8.encode(str);
      final digest = md5.convert(bytes);
      return digest.toString().substring(8, 24);
    } catch (e) {
      AppLog.instance.put('md5Encode16 error: $e');
      return '';
    }
  }

  /// md5Encode32 - MD5编码（32位）
  String _md5Encode32(String str) {
    try {
      final bytes = utf8.encode(str);
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      AppLog.instance.put('md5Encode32 error: $e');
      return '';
    }
  }

  /// readTxtFile - 读取文本文件
  /// 参考项目：JsExtensions.readTxtFile
  Future<String> _readTxtFile(String path) async {
    try {
      final cacheDir = await CacheService.instance.getCacheDir();
      final filePath = FileUtils.getPath(cacheDir.path, [path]);
      return await FileUtils.readText(filePath);
    } catch (e) {
      AppLog.instance.put('readTxtFile($path) error: $e');
      return '';
    }
  }

  /// createSymmetricCrypto - 创建对称加密对象
  /// 参考项目：JsExtensions.createSymmetricCrypto
  dynamic _createSymmetricCrypto(String transformation,
      [dynamic key, dynamic iv]) {
    try {
      Uint8List? keyBytes;
      Uint8List? ivBytes;

      if (key != null) {
        if (key is String) {
          keyBytes = Uint8List.fromList(utf8.encode(key));
        } else if (key is List<int>) {
          keyBytes = Uint8List.fromList(key);
        }
      }

      if (iv != null) {
        if (iv is String) {
          ivBytes = Uint8List.fromList(utf8.encode(iv));
        } else if (iv is List<int>) {
          ivBytes = Uint8List.fromList(iv);
        }
      }

      return JsEncodeUtils.createSymmetricCrypto(transformation,
          key: keyBytes, iv: ivBytes);
    } catch (e) {
      AppLog.instance.put('createSymmetricCrypto error: $e');
      return null;
    }
  }

  /// createAsymmetricCrypto - 创建非对称加密对象
  /// 参考项目：JsExtensions.createAsymmetricCrypto
  dynamic _createAsymmetricCrypto(String algorithm) {
    try {
      return JsEncodeUtils.createAsymmetricCrypto(algorithm);
    } catch (e) {
      AppLog.instance.put('createAsymmetricCrypto error: $e');
      return null;
    }
  }

  /// createSign - 创建签名对象
  /// 参考项目：JsExtensions.createSign
  dynamic _createSign(String algorithm) {
    try {
      return JsEncodeUtils.createSign(algorithm);
    } catch (e) {
      AppLog.instance.put('createSign error: $e');
      return null;
    }
  }

  /// digestHex - 生成摘要（十六进制）
  /// 参考项目：JsExtensions.digestHex
  String _digestHex(String data, String algorithm) {
    return JsEncodeUtils.digestHex(data, algorithm);
  }

  /// digestBase64Str - 生成摘要（Base64）
  /// 参考项目：JsExtensions.digestBase64Str
  String _digestBase64Str(String data, String algorithm) {
    return JsEncodeUtils.digestBase64Str(data, algorithm);
  }

  /// HMacHex - 生成HMAC（十六进制）
  /// 参考项目：JsExtensions.HMacHex
  String _hMacHex(String data, String algorithm, String key) {
    return JsEncodeUtils.hMacHex(data, algorithm, key);
  }

  /// HMacBase64 - 生成HMAC（Base64）
  /// 参考项目：JsExtensions.HMacBase64
  String _hMacBase64(String data, String algorithm, String key) {
    return JsEncodeUtils.hMacBase64(data, algorithm, key);
  }

  /// cacheFile - 缓存文件
  /// 参考项目：JsExtensions.cacheFile
  Future<String> _cacheFile(String urlStr, [int saveTime = 0]) async {
    try {
      final key = _md5Encode16(urlStr);
      final cachePath = await _cacheGet(key);

      if (cachePath != null && cachePath.isNotEmpty) {
        final content = await FileUtils.readText(cachePath);
        if (content.isNotEmpty) {
          return content;
        }
      }

      // 下载文件
      final response = await NetworkService.instance.get(urlStr);
      final content = await NetworkService.getResponseText(response);

      // 保存到缓存
      final cacheDir = await CacheService.instance.getCacheDir();
      final fileName = '$key.txt';
      final filePath = FileUtils.getPath(cacheDir.path, [fileName]);
      await FileUtils.writeText(filePath, content);

      // 保存缓存路径
      await _cachePut(key, filePath, saveTime);

      return content;
    } catch (e) {
      AppLog.instance.put('cacheFile($urlStr) error: $e');
      return '';
    }
  }

  // ========== Cache对象方法实现 ==========

  /// cache.get - 获取缓存
  /// 参考项目：CacheManager.get
  Future<String?> _cacheGet(String key) async {
    try {
      // 先尝试从内存获取
      final memoryValue = CacheManager.instance.getFromMemory(key);
      if (memoryValue != null) {
        return memoryValue.toString();
      }

      // 从数据库获取
      final value = await CacheManager.instance.get(key);
      if (value != null) {
        // 同时保存到内存（LRU缓存）
        CacheManager.instance.putMemory(key, value);
        return value.toString();
      }

      return null;
    } catch (e) {
      AppLog.instance.put('cache.get($key) error: $e');
      return null;
    }
  }

  /// cache.put - 保存缓存
  /// 参考项目：CacheManager.put
  Future<void> _cachePut(String key, String value, [int saveTime = 0]) async {
    try {
      // 保存到内存（LRU缓存）
      CacheManager.instance.putMemory(key, value);

      // 保存到数据库（带过期时间）
      // saveTime 单位为秒，0表示永不过期
      await CacheManager.instance.put(key, value, saveTime: saveTime);
    } catch (e) {
      AppLog.instance.put('cache.put($key) error: $e');
    }
  }

  // ========== 新增函数实现（增强兼容性）==========

  /// logType - 输出变量类型（调试用）
  /// 参考项目：JsExtensions.logType
  dynamic _logType(dynamic var_) {
    final sourceTag = source?.bookSourceName ?? '源';
    AppLog.instance.put('[$sourceTag] 变量类型: ${var_.runtimeType}');
    return var_;
  }

  /// getString - 解析规则获取字符串
  /// 参考项目：AnalyzeRule.getString
  /// 注意：此函数在当前上下文中可能无法使用，因为需要访问 RuleParser
  /// 实际使用时需要传入正确的上下文（HTML内容和规则）
  Future<String?> _getString(String? ruleStr,
      [dynamic mContent, bool isUrl = false]) async {
    try {
      // 注意：此实现需要访问 RuleParser，但在 JavaScript 上下文中可能无法直接访问
      // 这里提供一个占位实现，实际使用时需要通过其他方式传递上下文
      AppLog.instance.put('java.getString: 警告 - 此函数在当前上下文中可能无法正常工作');
      AppLog.instance.put('java.getString: ruleStr=$ruleStr, isUrl=$isUrl');

      // 如果提供了内容，尝试简单处理
      if (mContent != null && ruleStr != null && ruleStr.isNotEmpty) {
        final contentStr = mContent.toString();
        // 简单的文本提取（仅作为占位实现）
        if (ruleStr.startsWith('@text')) {
          return contentStr;
        }
      }

      return null;
    } catch (e) {
      AppLog.instance.put('java.getString error: $e');
      return null;
    }
  }

  /// getStringList - 解析规则获取字符串列表
  /// 参考项目：AnalyzeRule.getStringList
  Future<List<String>> _getStringList(String? ruleStr,
      [dynamic mContent, bool isUrl = false]) async {
    try {
      final result = await _getString(ruleStr, mContent, isUrl);
      if (result != null) {
        return result.split('\n').where((s) => s.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      AppLog.instance.put('java.getStringList error: $e');
      return [];
    }
  }

  /// setContent - 设置解析内容
  /// 参考项目：AnalyzeRule.setContent
  /// 注意：此函数在当前实现中可能无法完全工作，因为需要维护解析上下文
  void _setContent(dynamic content, [String? baseUrl]) {
    // 注意：此函数需要维护解析上下文，当前实现中可能无法完全支持
    AppLog.instance.put('java.setContent: 警告 - 此函数在当前上下文中可能无法正常工作');
    AppLog.instance.put(
        'java.setContent: content类型=${content.runtimeType}, baseUrl=$baseUrl');
  }

  /// getElement - 获取单个元素
  /// 参考项目：AnalyzeRule.getElement
  Future<dynamic> _getElement(String ruleStr) async {
    try {
      // 注意：此函数需要访问当前解析上下文，当前实现中可能无法完全支持
      AppLog.instance.put('java.getElement: 警告 - 此函数在当前上下文中可能无法正常工作');
      AppLog.instance.put('java.getElement: ruleStr=$ruleStr');
      return null;
    } catch (e) {
      AppLog.instance.put('java.getElement error: $e');
      return null;
    }
  }

  /// getElements - 获取元素列表
  /// 参考项目：AnalyzeRule.getElements
  Future<List<dynamic>> _getElements(String ruleStr) async {
    try {
      final element = await _getElement(ruleStr);
      return element != null ? [element] : [];
    } catch (e) {
      AppLog.instance.put('java.getElements error: $e');
      return [];
    }
  }

  /// getVariable - 获取变量
  /// 参考项目：AnalyzeRule.get
  String? _getVariable(String key) {
    // 注意：此函数需要访问 RuleParser 的变量存储
    // 当前实现中，变量存储在 RuleParser 中，需要通过其他方式访问
    AppLog.instance.put('java.get: 警告 - 此函数在当前上下文中可能无法正常工作');
    AppLog.instance.put('java.get: key=$key');
    return null;
  }

  /// putVariable - 设置变量
  /// 参考项目：AnalyzeRule.put
  void _putVariable(String key, String value) {
    // 注意：此函数需要访问 RuleParser 的变量存储
    AppLog.instance.put('java.put: 警告 - 此函数在当前上下文中可能无法正常工作');
    AppLog.instance.put('java.put: key=$key, value=$value');
  }

  /// toURL - URL 解析
  /// 参考项目：JsURL
  Map<String, dynamic> _toURL(String url, [String? baseUrl]) {
    try {
      final uri =
          baseUrl != null ? Uri.parse(baseUrl).resolve(url) : Uri.parse(url);

      return {
        'href': uri.toString(),
        'protocol': uri.scheme,
        'host': uri.host,
        'port': uri.hasPort ? uri.port : null,
        'pathname': uri.path,
        'search': uri.query,
        'hash': uri.fragment,
        'origin':
            '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}',
      };
    } catch (e) {
      AppLog.instance.put('java.toURL error: $e');
      return {};
    }
  }

  /// timeFormat - 时间格式化
  /// 参考项目：JsExtensions.timeFormat
  String _timeFormat(int time) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(time);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      AppLog.instance.put('java.timeFormat error: $e');
      return '';
    }
  }

  /// timeFormatUTC - UTC 时间格式化
  /// 参考项目：JsExtensions.timeFormatUTC
  String? _timeFormatUTC(int time, String format, [int? sh]) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(time, isUtc: true);
      // 简化实现，支持基本格式
      String result = format;
      result = result.replaceAll('yyyy', date.year.toString());
      result = result.replaceAll('MM', date.month.toString().padLeft(2, '0'));
      result = result.replaceAll('dd', date.day.toString().padLeft(2, '0'));
      result = result.replaceAll('HH', date.hour.toString().padLeft(2, '0'));
      result = result.replaceAll('mm', date.minute.toString().padLeft(2, '0'));
      result = result.replaceAll('ss', date.second.toString().padLeft(2, '0'));
      return result;
    } catch (e) {
      AppLog.instance.put('java.timeFormatUTC error: $e');
      return null;
    }
  }

  /// randomUUID - 生成随机UUID
  /// 参考项目：JsExtensions.randomUUID
  String _randomUUID() {
    const uuid = Uuid();
    return uuid.v4();
  }

  /// androidId - 获取Android ID（当前项目返回设备ID）
  /// 参考项目：JsExtensions.androidId
  String _androidId() {
    // 注意：当前项目无法直接获取 Android ID，返回一个固定标识
    // 实际使用时可能需要通过平台通道获取
    return 'flutter-device-id';
  }

  /// hexEncodeToString - Hex 编码
  /// 参考项目：JsExtensions.hexEncodeToString
  String _hexEncodeToString(String str) {
    try {
      final bytes = utf8.encode(str);
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    } catch (e) {
      AppLog.instance.put('java.hexEncodeToString error: $e');
      return '';
    }
  }

  /// hexDecodeToString - Hex 解码为字符串
  /// 参考项目：JsExtensions.hexDecodeToString
  String _hexDecodeToString(String hex) {
    try {
      final bytes = _hexDecodeToByteArray(hex);
      return utf8.decode(bytes);
    } catch (e) {
      AppLog.instance.put('java.hexDecodeToString error: $e');
      return '';
    }
  }

  /// hexDecodeToByteArray - Hex 解码为字节数组
  /// 参考项目：JsExtensions.hexDecodeToByteArray
  List<int> _hexDecodeToByteArray(String hex) {
    try {
      final bytes = <int>[];
      for (int i = 0; i < hex.length; i += 2) {
        final byteStr = hex.substring(i, i + 2);
        bytes.add(int.parse(byteStr, radix: 16));
      }
      return bytes;
    } catch (e) {
      AppLog.instance.put('java.hexDecodeToByteArray error: $e');
      return [];
    }
  }

  /// strToBytes - 字符串转字节数组
  /// 参考项目：JsExtensions.strToBytes
  List<int> _strToBytes(String str, [String charset = 'UTF-8']) {
    try {
      // 简化实现，只支持 UTF-8
      if (charset.toUpperCase() == 'UTF-8') {
        return utf8.encode(str);
      }
      // 其他字符集需要额外处理
      return utf8.encode(str);
    } catch (e) {
      AppLog.instance.put('java.strToBytes error: $e');
      return [];
    }
  }

  /// bytesToStr - 字节数组转字符串
  /// 参考项目：JsExtensions.bytesToStr
  String _bytesToStr(List<int> bytes, [String charset = 'UTF-8']) {
    try {
      // 简化实现，只支持 UTF-8
      if (charset.toUpperCase() == 'UTF-8') {
        return utf8.decode(bytes);
      }
      // 其他字符集需要额外处理
      return utf8.decode(bytes);
    } catch (e) {
      AppLog.instance.put('java.bytesToStr error: $e');
      return '';
    }
  }

  /// htmlFormat - HTML 格式化
  /// 参考项目：JsExtensions.htmlFormat
  String _htmlFormat(String str) {
    try {
      // 简单的 HTML 格式化（去除多余空白）
      return str
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'>\s+<'), '><')
          .trim();
    } catch (e) {
      AppLog.instance.put('java.htmlFormat error: $e');
      return str;
    }
  }

  /// importScript - 导入脚本
  /// 参考项目：JsExtensions.importScript
  Future<String> _importScript(String urlOrPath) async {
    try {
      // 如果是 URL，使用 cacheFile 下载并缓存
      if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
        return await _cacheFile(urlOrPath);
      }

      // 如果是相对路径或绝对路径，读取文件
      final cacheDir = await CacheService.instance.getCacheDir();
      final filePath = FileUtils.getPath(cacheDir.path, [urlOrPath]);
      return await FileUtils.readText(filePath);
    } catch (e) {
      AppLog.instance.put('java.importScript error: $e');
      return '';
    }
  }

  // ========== WebView 相关函数实现 ==========

  /// webView - 使用 WebView 访问网络
  /// 参考项目：JsExtensions.webView
  ///
  /// [html] 直接用 webView 载入的 HTML，如果为空则直接访问 url
  /// [url] HTML 内如果有相对路径的资源，需要传入 url
  /// [js] 用来取返回值的 JS 语句
  Future<String?> _webView(String? html, String? url, String? js) async {
    try {
      // 获取请求头
      Map<String, String>? headerMap;
      if (source?.header != null && source!.header!.isNotEmpty) {
        headerMap = NetworkService.parseHeaders(source!.header!);
      }

      final webView = BackstageWebView(
        url: url,
        html: html,
        javaScript: js,
        headerMap: headerMap,
        tag: source?.bookSourceUrl,
      );

      final response = await webView.getStrResponse();
      return response.body;
    } catch (e) {
      AppLog.instance.put('java.webView error: $e');
      return e.toString();
    }
  }

  /// webViewGetSource - 使用 WebView 获取资源 URL
  /// 参考项目：JsExtensions.webViewGetSource
  Future<String?> _webViewGetSource(
    String? html,
    String? url,
    String? js,
    String sourceRegex,
  ) async {
    try {
      // 获取请求头
      Map<String, String>? headerMap;
      if (source?.header != null && source!.header!.isNotEmpty) {
        headerMap = NetworkService.parseHeaders(source!.header!);
      }

      final webView = BackstageWebView(
        url: url,
        html: html,
        javaScript: js,
        headerMap: headerMap,
        tag: source?.bookSourceUrl,
        sourceRegex: sourceRegex,
      );

      final response = await webView.getStrResponse();
      return response.body;
    } catch (e) {
      AppLog.instance.put('java.webViewGetSource error: $e');
      return e.toString();
    }
  }

  /// webViewGetOverrideUrl - 使用 WebView 获取跳转 URL
  /// 参考项目：JsExtensions.webViewGetOverrideUrl
  Future<String?> _webViewGetOverrideUrl(
    String? html,
    String? url,
    String? js,
    String overrideUrlRegex,
  ) async {
    try {
      // 获取请求头
      Map<String, String>? headerMap;
      if (source?.header != null && source!.header!.isNotEmpty) {
        headerMap = NetworkService.parseHeaders(source!.header!);
      }

      final webView = BackstageWebView(
        url: url,
        html: html,
        javaScript: js,
        headerMap: headerMap,
        tag: source?.bookSourceUrl,
        overrideUrlRegex: overrideUrlRegex,
      );

      final response = await webView.getStrResponse();
      return response.body;
    } catch (e) {
      AppLog.instance.put('java.webViewGetOverrideUrl error: $e');
      return e.toString();
    }
  }

  /// startBrowser - 使用内置浏览器打开链接
  /// 参考项目：JsExtensions.startBrowser
  ///
  /// 注意：此函数需要前端配合，显示 WebView 页面
  /// 当前仅记录日志，实际实现需要通过平台通道或 Navigator
  Future<void> _startBrowser(String url, String title) async {
    try {
      AppLog.instance.put(
          'java.startBrowser: url=$url, title=$title, source=${source?.bookSourceName}');
      // TODO: 需要通过平台通道或事件机制打开浏览器页面
    } catch (e) {
      AppLog.instance.put('java.startBrowser error: $e');
    }
  }

  /// startBrowserAwait - 使用内置浏览器打开链接，并等待结果
  /// 参考项目：JsExtensions.startBrowserAwait
  ///
  /// 注意：当前仅记录日志，实际实现需要通过平台通道或 Navigator
  Future<Map<String, dynamic>> _startBrowserAwait(
    String url,
    String title, [
    bool refetchAfterSuccess = true,
  ]) async {
    try {
      AppLog.instance.put(
          'java.startBrowserAwait: url=$url, title=$title, refetch=$refetchAfterSuccess');
      // TODO: 需要通过平台通道或事件机制打开浏览器页面并等待结果

      return {
        'url': url,
        'body': '',
        'statusCode': 0,
        'headers': <String, String>{},
      };
    } catch (e) {
      AppLog.instance.put('java.startBrowserAwait error: $e');
      return {
        'url': url,
        'body': e.toString(),
        'statusCode': 0,
        'headers': <String, String>{},
      };
    }
  }

  /// getVerificationCode - 打开图片验证码对话框
  /// 参考项目：JsExtensions.getVerificationCode
  ///
  /// 注意：当前仅记录日志，实际实现需要通过平台通道或 Navigator
  Future<String> _getVerificationCode(String imageUrl) async {
    try {
      AppLog.instance.put('java.getVerificationCode: imageUrl=$imageUrl');
      // TODO: 需要通过平台通道或事件机制打开验证码对话框
      return '';
    } catch (e) {
      AppLog.instance.put('java.getVerificationCode error: $e');
      return '';
    }
  }

  /// getWebViewUA - 获取 WebView User-Agent
  /// 参考项目：JsExtensions.getWebViewUA
  String _getWebViewUA() {
    return BackstageWebView.getWebViewUA();
  }

  // ========== 并发请求实现 ==========

  /// ajaxAll - 并发访问网络
  /// 参考项目：JsExtensions.ajaxAll
  Future<List<Map<String, dynamic>>> _ajaxAll(List<String> urlList) async {
    try {
      final futures = urlList.map((url) async {
        try {
          final response = await NetworkService.instance.get(url);
          final body = await NetworkService.getResponseText(response);
          return {
            'url': url,
            'body': body,
            'statusCode': response.statusCode ?? 200,
            'headers': response.headers.map,
          };
        } catch (e) {
          return {
            'url': url,
            'body': e.toString(),
            'statusCode': 0,
            'headers': <String, dynamic>{},
          };
        }
      }).toList();

      return await Future.wait(futures);
    } catch (e) {
      AppLog.instance.put('java.ajaxAll error: $e');
      return [];
    }
  }

  // ========== 文件操作实现 ==========

  /// getFile - 获取文件路径
  /// 参考项目：JsExtensions.getFile
  Future<String> _getFile(String path) async {
    try {
      final cacheDir = await CacheService.instance.getCacheDir();
      final filePath = FileUtils.getPath(cacheDir.path, [path]);
      return filePath;
    } catch (e) {
      AppLog.instance.put('java.getFile error: $e');
      return '';
    }
  }

  /// readFile - 读取文件字节
  /// 参考项目：JsExtensions.readFile
  Future<List<int>?> _readFile(String path) async {
    try {
      final filePath = await _getFile(path);
      return await FileUtils.readBytes(filePath);
    } catch (e) {
      AppLog.instance.put('java.readFile error: $e');
      return null;
    }
  }

  /// deleteFile - 删除文件
  /// 参考项目：JsExtensions.deleteFile
  Future<bool> _deleteFile(String path) async {
    try {
      final filePath = await _getFile(path);
      return await FileUtils.delete(filePath);
    } catch (e) {
      AppLog.instance.put('java.deleteFile error: $e');
      return false;
    }
  }

  /// downloadFile - 下载文件
  /// 参考项目：JsExtensions.downloadFile
  ///
  /// 返回下载后的相对路径
  Future<String> _downloadFile(String url) async {
    try {
      final key = _md5Encode16(url);
      final cacheDir = await CacheService.instance.getCacheDir();

      // 获取文件后缀
      final uri = Uri.tryParse(url);
      String suffix = 'dat';
      if (uri != null) {
        final path = uri.path;
        final dotIndex = path.lastIndexOf('.');
        if (dotIndex > 0) {
          suffix = path.substring(dotIndex + 1);
        }
      }

      final fileName = '$key.$suffix';
      final filePath = FileUtils.getPath(cacheDir.path, [fileName]);

      // 下载文件
      final response = await NetworkService.instance.get(url);
      final bytes = response.data as List<int>?;

      if (bytes != null) {
        await FileUtils.writeBytes(filePath, Uint8List.fromList(bytes));
      }

      // 返回相对路径
      return fileName;
    } catch (e) {
      AppLog.instance.put('java.downloadFile error: $e');
      return '';
    }
  }

  // ========== 网络请求增强 ==========

  /// HTTP GET 请求
  /// 参考项目：JsExtensions.get
  Future<Map<String, dynamic>> _httpGet(
    String urlStr,
    Map<String, String>? headers,
  ) async {
    try {
      final response = await NetworkService.instance.get(
        urlStr,
        headers: headers,
      );
      final body = await NetworkService.getResponseText(response);

      return {
        'url': urlStr,
        'body': body,
        'statusCode': response.statusCode ?? 200,
        'headers': response.headers.map,
        'redirectUrl': response.redirects.isNotEmpty
            ? response.redirects.last.location.toString()
            : null,
      };
    } catch (e) {
      AppLog.instance.put('java.get error: $e');
      return {
        'url': urlStr,
        'body': e.toString(),
        'statusCode': 0,
        'headers': <String, dynamic>{},
      };
    }
  }

  /// HTTP HEAD 请求
  /// 参考项目：JsExtensions.head
  ///
  /// 注意：使用 GET 请求模拟，因为 NetworkService 没有单独的 head 方法
  Future<Map<String, dynamic>> _httpHead(
    String urlStr,
    Map<String, String>? headers,
  ) async {
    try {
      // 使用 GET 请求，只返回 headers 信息
      final response = await NetworkService.instance.get(
        urlStr,
        headers: headers,
      );

      return {
        'url': urlStr,
        'statusCode': response.statusCode ?? 200,
        'headers': response.headers.map,
        'redirectUrl': response.redirects.isNotEmpty
            ? response.redirects.last.location.toString()
            : null,
      };
    } catch (e) {
      AppLog.instance.put('java.head error: $e');
      return {
        'url': urlStr,
        'statusCode': 0,
        'headers': <String, dynamic>{},
      };
    }
  }

  /// HTTP POST 请求
  /// 参考项目：JsExtensions.post
  Future<Map<String, dynamic>> _httpPost(
    String urlStr,
    String body,
    Map<String, String>? headers,
  ) async {
    try {
      final response = await NetworkService.instance.post(
        urlStr,
        data: body,
        headers: headers,
      );
      final responseBody = await NetworkService.getResponseText(response);

      return {
        'url': urlStr,
        'body': responseBody,
        'statusCode': response.statusCode ?? 200,
        'headers': response.headers.map,
        'redirectUrl': response.redirects.isNotEmpty
            ? response.redirects.last.location.toString()
            : null,
      };
    } catch (e) {
      AppLog.instance.put('java.post error: $e');
      return {
        'url': urlStr,
        'body': e.toString(),
        'statusCode': 0,
        'headers': <String, dynamic>{},
      };
    }
  }

  // ========== 字体解析（防盗版）==========

  /// QueryTTF 缓存
  final Map<String, QueryTTF> _ttfCache = {};

  /// queryTTF - 返回字体解析类
  /// 参考项目：JsExtensions.queryTTF
  ///
  /// [data] 支持 url, 本地文件, base64, ByteArray，自动判断，自动缓存
  /// [useCache] 可选开关缓存，默认开启
  Future<QueryTTF?> _queryTTF(dynamic data, [bool useCache = true]) async {
    try {
      String? key;
      QueryTTF? qTTF;

      if (data == null) return null;

      if (data is String) {
        if (data.isEmpty) return null;

        // 计算缓存 key
        if (useCache) {
          key = _md5Encode32(data);
          qTTF = _ttfCache[key];
          if (qTTF != null) return qTTF;
        }

        // 根据内容类型获取字体数据
        Uint8List? font;
        if (data.startsWith('http://') || data.startsWith('https://')) {
          // URL - 下载字体
          final response = await NetworkService.instance.get(
            data,
            options: Options(responseType: ResponseType.bytes),
          );
          if (response.data != null && response.data is List<int>) {
            font = Uint8List.fromList(response.data as List<int>);
          }
        } else {
          // Base64 - 解码
          try {
            font = base64Decode(data);
          } catch (e) {
            // 可能是本地文件路径
            final filePath = await _getFile(data);
            final bytes = await FileUtils.readBytes(filePath);
            if (bytes != null) {
              font = Uint8List.fromList(bytes);
            }
          }
        }

        if (font == null || font.isEmpty) return null;
        qTTF = QueryTTF(font);
      } else if (data is List<int>) {
        // ByteArray
        if (useCache) {
          key = _md5Encode32(String.fromCharCodes(data.take(100)));
          qTTF = _ttfCache[key];
          if (qTTF != null) return qTTF;
        }
        qTTF = QueryTTF(Uint8List.fromList(data));
      } else if (data is Uint8List) {
        // Uint8List
        if (useCache) {
          key = _md5Encode32(String.fromCharCodes(data.take(100)));
          qTTF = _ttfCache[key];
          if (qTTF != null) return qTTF;
        }
        qTTF = QueryTTF(data);
      } else {
        return null;
      }

      // 缓存
      if (key != null && qTTF != null) {
        _ttfCache[key] = qTTF;
      }

      return qTTF;
    } catch (e) {
      AppLog.instance.put('[queryTTF] 获取字体处理类出错: $e');
      return null;
    }
  }

  /// replaceFont - 字体替换
  /// 参考项目：JsExtensions.replaceFont
  ///
  /// [text] 包含错误字体的内容
  /// [errorQueryTTF] 错误的字体
  /// [correctQueryTTF] 正确的字体
  /// [filter] 删除 errorQueryTTF 中不存在的字符
  String _replaceFont(
    String text,
    QueryTTF? errorQueryTTF,
    QueryTTF? correctQueryTTF, [
    bool filter = false,
  ]) {
    if (errorQueryTTF == null || correctQueryTTF == null) return text;

    // 将文本转换为 Unicode 码点数组
    final contentArray = text.runes.toList();
    final resultArray = <String>[];

    for (int i = 0; i < contentArray.length; i++) {
      final oldCode = contentArray[i];

      // 忽略正常的空白字符
      if (errorQueryTTF.isBlankUnicode(oldCode)) {
        resultArray.add(String.fromCharCode(oldCode));
        continue;
      }

      // 获取轮廓数据
      var glyf = errorQueryTTF.getGlyfByUnicode(oldCode);
      // 轮廓数据指向保留索引 0
      if (errorQueryTTF.getGlyfIdByUnicode(oldCode) == 0) glyf = null;

      // 删除轮廓数据不存在的字符
      if (filter && glyf == null) {
        continue;
      }

      // 使用轮廓数据反查 Unicode
      final code = correctQueryTTF.getUnicodeByGlyf(glyf);
      if (code != 0) {
        resultArray.add(String.fromCharCode(code));
      } else {
        resultArray.add(String.fromCharCode(oldCode));
      }
    }

    return resultArray.join('');
  }
}
