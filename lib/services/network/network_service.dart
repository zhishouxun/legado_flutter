import 'dart:convert' show utf8, latin1;
import 'dart:typed_data' show Uint8List;
import 'dart:io' show HttpClient, X509Certificate;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:charset_converter/charset_converter.dart';
import '../../core/base/base_service.dart';
import '../../utils/encoding_detect.dart';
import '../../utils/utf8_bom_utils.dart';
import '../../utils/network_utils.dart';
import '../../utils/file_utils.dart';

/// 网络请求错误类型
enum NetworkErrorType {
  connectTimeout,
  receiveTimeout,
  sendTimeout,
  response,
  cancel,
  other,
}

/// 网络请求错误
class NetworkError {
  final NetworkErrorType type;
  final String message;
  final dynamic error;

  NetworkError({
    required this.type,
    required this.message,
    this.error,
  });

  @override
  String toString() => message;
}

class NetworkService extends BaseService {
  static final NetworkService instance = NetworkService._init();
  late Dio _dio;
  late CookieJar _cookieJar;

  NetworkService._init();

  @override
  Future<void> onInit() async {
    return await execute(
      action: () async {
        final initStopwatch = Stopwatch()..start();
        
        // Web平台使用内存Cookie存储
        print('NetworkService: Check 1 - CookieJar init start');
        if (kIsWeb) {
          _cookieJar = CookieJar();
        } else {
          final appDocPath = await FileUtils.getDocumentsPath();
          print('NetworkService: Check 1a - getDocumentsPath took ${initStopwatch.elapsedMilliseconds}ms');
          initStopwatch.reset();
          
          final cookiePath = FileUtils.getPath(appDocPath, ['cookies']);
          _cookieJar = PersistCookieJar(
            storage: FileStorage(cookiePath),
          );
          print('NetworkService: Check 1b - PersistCookieJar init took ${initStopwatch.elapsedMilliseconds}ms');
          initStopwatch.reset();
        }

    print('NetworkService: Check 2 - Dio init start');
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15), // 参考项目使用15秒
        receiveTimeout: const Duration(seconds: 60), // 参考项目使用60秒
        sendTimeout: const Duration(seconds: 15), // 参考项目使用15秒
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Keep-Alive': '300',
          'Connection': 'Keep-Alive',
          'Cache-Control': 'no-cache',
        },
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) {
          // 接受所有状态码，让错误处理逻辑来决定
          return true;
        },
      ),
    );
    print('NetworkService: Check 2 - Dio init took ${initStopwatch.elapsedMilliseconds}ms');
    initStopwatch.reset();

    // 配置HTTP客户端适配器（仅非Web平台）
    print('NetworkService: Check 3 - HttpClientAdapter config start');
    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        // 配置不安全的SSL（信任所有证书，参考项目做法）
        // 注意：这存在安全风险，但为了与参考项目保持一致
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          return true; // 信任所有证书
        };
        return client;
      };
    }
    print('NetworkService: Check 3 - HttpClientAdapter config took ${initStopwatch.elapsedMilliseconds}ms');
    initStopwatch.reset();

        print('NetworkService: Check 4 - Interceptors config start');
        _dio.interceptors.add(CookieManager(_cookieJar));

        // 错误拦截器
        _dio.interceptors.add(InterceptorsWrapper(
          onError: (error, handler) {
            final networkError = _handleError(error);
            handler.reject(DioException(
              requestOptions: error.requestOptions,
              error: networkError,
              type: error.type,
            ));
          },
        ));
        print('NetworkService: Check 4 - Interceptors config took ${initStopwatch.elapsedMilliseconds}ms');
        
        print('NetworkService: Total init time: ${initStopwatch.elapsedMilliseconds}ms');
      },
      operationName: '初始化网络服务',
      logError: true,
    );
  }

  /// 处理错误
  NetworkError _handleError(DioException error) {
    NetworkErrorType type;
    String message;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        type = NetworkErrorType.connectTimeout;
        message = '连接超时';
        break;
      case DioExceptionType.receiveTimeout:
        type = NetworkErrorType.receiveTimeout;
        message = '接收超时';
        break;
      case DioExceptionType.badResponse:
        type = NetworkErrorType.response;
        message = '服务器错误: ${error.response?.statusCode}';
        break;
      case DioExceptionType.cancel:
        type = NetworkErrorType.cancel;
        message = '请求已取消';
        break;
      default:
        type = NetworkErrorType.other;
        // 提供更详细的错误信息
        if (error.message != null && error.message!.isNotEmpty) {
          message = error.message!;
        } else if (error.error != null) {
          message = '网络错误: ${error.error}';
        } else {
          message = '未知错误 (类型: ${error.type})';
        }
    }

    return NetworkError(type: type, message: message, error: error);
  }

  Dio get dio {
    ensureInitialized();
    return _dio;
  }

  /// GET 请求（带重试）
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    int retryCount = 0,
    Map<String, String>? headers,
  }) async {
    await init();
    
    // 检查网络状态（参考项目：NetworkUtils.isAvailable）
    final isAvailable = await NetworkUtils.isAvailable();
    if (!isAvailable) {
      throw NetworkError(
        type: NetworkErrorType.other,
        message: '网络未连接',
      );
    }

    final requestOptions = options ?? Options();
    if (headers != null) {
      requestOptions.headers = {
        ...?requestOptions.headers,
        ...headers,
      };
    }

    // 确保禁用缓存（参考项目使用 Cache-Control: no-cache）
    requestOptions.headers ??= {};
    requestOptions.headers!['Cache-Control'] =
        'no-cache, no-store, must-revalidate';
    requestOptions.headers!['Pragma'] = 'no-cache';
    requestOptions.headers!['Expires'] = '0';

    // 禁用 Dio 的缓存
    requestOptions.extra ??= {};
    requestOptions.extra!['noCache'] = true;
    
    // 设置响应类型为字节，以便手动处理编码
    requestOptions.responseType = ResponseType.bytes;

    int attempts = 0;
    while (true) {
      try {

        final response = await _dio.get(
          url,
          queryParameters: queryParameters,
          options: requestOptions,
          cancelToken: cancelToken,
        );

        // 确保响应文本已解码（用于验证）
        await NetworkService.getResponseText(response);

        return response;
      } on DioException catch (e) {
        attempts++;
        if (attempts > retryCount) {
          throw _handleError(e);
        }
        // 等待后重试
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }

  /// POST 请求（带重试）
  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    int retryCount = 0,
    Map<String, String>? headers,
  }) async {
    await init();
    
    // 检查网络状态（参考项目：NetworkUtils.isAvailable）
    final isAvailable = await NetworkUtils.isAvailable();
    if (!isAvailable) {
      throw NetworkError(
        type: NetworkErrorType.other,
        message: '网络未连接',
      );
    }

    final requestOptions = options ?? Options();
    if (headers != null) {
      requestOptions.headers = {
        ...?requestOptions.headers,
        ...headers,
      };
    }
    
    // 设置响应类型为字节，以便手动处理编码
    requestOptions.responseType = ResponseType.bytes;

    int attempts = 0;
    while (true) {
      try {
        return await _dio.post(
          url,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        attempts++;
        if (attempts > retryCount) {
          throw _handleError(e);
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }

  /// 下载文件
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) async {
    await init();

    final options = headers != null ? Options(headers: headers) : null;

    try {
      return await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 解析请求头字符串（格式：key1:value1\nkey2:value2）
  static Map<String, String> parseHeaders(String? headerString) {
    if (headerString == null || headerString.isEmpty) {
      return {};
    }

    final headers = <String, String>{};
    final lines = headerString.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final index = trimmed.indexOf(':');
      if (index > 0 && index < trimmed.length - 1) {
        // 清理键名：移除引号和其他无效字符
        var key = trimmed.substring(0, index).trim();
        if (key.startsWith('"') && key.endsWith('"')) {
          key = key.substring(1, key.length - 1);
        } else if (key.startsWith("'") && key.endsWith("'")) {
          key = key.substring(1, key.length - 1);
        }

        // 清理值：移除引号（如果存在）
        var value = trimmed.substring(index + 1).trim();
        if (value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        } else if (value.startsWith("'") && value.endsWith("'")) {
          value = value.substring(1, value.length - 1);
        }

        if (key.isNotEmpty && value.isNotEmpty) {
          headers[key] = value;
        }
      }
    }

    return headers;
  }

  /// 设置全局请求头
  void setHeaders(Map<String, dynamic> headers) {
    if (!isInitialized) return;
    _dio.options.headers.addAll(headers);
  }

  /// 清除全局请求头
  void clearHeaders() {
    if (!isInitialized) return;
    _dio.options.headers.clear();
  }

  /// 清除 Cookie
  Future<void> clearCookies() async {
    if (!isInitialized) return;
    await _cookieJar.deleteAll();
  }

  /// 获取 Cookie
  Future<List<Cookie>> getCookies(String uri) async {
    if (!isInitialized) return [];
    return await _cookieJar.loadForRequest(Uri.parse(uri));
  }

  /// 拼接 URL（使用 NetworkUtils.getAbsoluteURL）
  /// 参考项目：NetworkUtils.getAbsoluteURL
  static String joinUrl(String baseUrl, String path) {
    return NetworkUtils.getAbsoluteURL(baseUrl, path);
  }

  /// URL 编码
  static String encodeUrl(String url) {
    return Uri.encodeComponent(url);
  }

  /// URL 解码
  static String decodeUrl(String url) {
    return Uri.decodeComponent(url);
  }

  /// 获取响应文本（自动处理编码）
  static Future<String> getResponseText(Response response) async {
    final data = response.data;
    
    // 获取原始字节数据
    List<int> bytes;
    
    if (data is String) {
      // 如果已经是 String，可能是 Dio 已经解码了
      // 尝试将字符串转换回字节（使用UTF-8），但这可能不准确
      // 理想情况下，应该在请求时设置 responseType: ResponseType.bytes
      bytes = utf8.encode(data);
    } else if (data is List<int>) {
      bytes = data;
    } else if (data is Uint8List) {
      bytes = data.toList();
    } else {
      // 其他类型，尝试转换为字符串
      return data.toString();
    }
    
    // 参考项目：Utf8BomUtils.removeUTF8BOM(bytes())
    // 移除 UTF-8 BOM 标记
    final bytesList = Uint8List.fromList(bytes);
    final responseBytes = Utf8BomUtils.removeUTF8BOMBytes(bytesList);
    
    // 首先尝试从响应头获取编码
    final contentType = response.headers.value('content-type');
    String? charset;
    if (contentType != null) {
      final charsetMatch = RegExp(r'charset=([^;,\s]+)', caseSensitive: false)
          .firstMatch(contentType);
      if (charsetMatch != null) {
        charset = charsetMatch.group(1)?.toLowerCase();
      }
    }

    // 如果响应头没有编码，使用 EncodingDetect 从HTML内容中检测
    // 参考项目：EncodingDetect.getHtmlEncode(responseBytes)
    if (charset == null) {
      try {
        charset = EncodingDetect.getHtmlEncode(responseBytes).toLowerCase();
        if (charset.isEmpty) {
          charset = null;
        }
      } catch (e) {
        // 忽略错误，继续尝试其他方法
      }
    }

    // 如果还是没有检测到编码，使用通用编码检测
    if (charset == null) {
      try {
        charset = EncodingDetect.getEncode(responseBytes).toLowerCase();
        if (charset.isEmpty) {
          charset = null;
        }
      } catch (e) {
        // 忽略错误
      }
    }

    // 根据检测到的编码解码
    try {
      if (charset != null) {
        // 标准化编码名称（处理大小写和变体）
        final normalizedCharset = charset.toLowerCase().trim();

        // UTF-8 系列（Dart标准库支持）
        if (normalizedCharset == 'utf-8' || normalizedCharset == 'utf8') {
          return utf8.decode(responseBytes, allowMalformed: true);
        }

        // ISO-8859-1 / Latin1（Dart标准库支持）
        if (normalizedCharset == 'iso-8859-1' ||
            normalizedCharset == 'latin1') {
          return latin1.decode(responseBytes, allowInvalid: true);
        }

        // 需要第三方库支持的编码（使用charset_converter）
        // 中文编码：GBK系列、Big5（繁体中文）
        final isChineseEncoding = normalizedCharset == 'gbk' ||
            normalizedCharset == 'gb2312' ||
            normalizedCharset == 'gb18030' ||
            normalizedCharset == 'big5' ||
            normalizedCharset == 'big5-hkscs';

        // 日文编码
        final isJapaneseEncoding = normalizedCharset == 'shift-jis' ||
            normalizedCharset == 'shift_jis' ||
            normalizedCharset == 'sjis' ||
            normalizedCharset == 'euc-jp' ||
            normalizedCharset == 'iso-2022-jp';

        // 韩文编码
        final isKoreanEncoding = normalizedCharset == 'euc-kr' ||
            normalizedCharset == 'ks_c_5601-1987' ||
            normalizedCharset == 'windows-949';

        // Windows编码
        final isWindowsEncoding = normalizedCharset.startsWith('windows-') ||
            normalizedCharset.startsWith('cp') ||
            normalizedCharset == 'windows-1252' ||
            normalizedCharset == 'windows-1250' ||
            normalizedCharset == 'windows-1251' ||
            normalizedCharset == 'windows-1253' ||
            normalizedCharset == 'windows-1254' ||
            normalizedCharset == 'windows-1255' ||
            normalizedCharset == 'windows-1256' ||
            normalizedCharset == 'windows-1257' ||
            normalizedCharset == 'windows-1258';

        // ISO-8859 系列（除了ISO-8859-1）
        final isIso8859Encoding = normalizedCharset.startsWith('iso-8859-') &&
            normalizedCharset != 'iso-8859-1';

        // 如果是需要第三方库的编码
        if (isChineseEncoding ||
            isJapaneseEncoding ||
            isKoreanEncoding ||
            isWindowsEncoding ||
            isIso8859Encoding) {
          try {
            if (kIsWeb) {
              // Web平台不支持charset_converter，使用UTF-8作为fallback
              return utf8.decode(bytes, allowMalformed: true);
            } else {
              // 使用charset_converter解码
              try {
                final decoded = await CharsetConverter.decode(
                    normalizedCharset, responseBytes);
                return decoded;
              } catch (e) {
                // charset_converter失败
                // 如果所有方法都失败，抛出异常
                rethrow;
              }
            }
          } catch (e) {
            // 解码失败，尝试UTF-8
            try {
              return utf8.decode(responseBytes, allowMalformed: true);
            } catch (e2) {
              // UTF-8也失败，使用Latin1作为fallback
              return latin1.decode(responseBytes, allowInvalid: true);
            }
          }
        }

        // 其他未知编码，尝试使用charset_converter
        try {
          if (!kIsWeb) {
            final decoded = await CharsetConverter.decode(
                normalizedCharset, responseBytes);
            return decoded;
          }
        } catch (e) {
          // 忽略错误
        }
      }

      // 默认尝试UTF-8
      return utf8.decode(responseBytes, allowMalformed: true);
    } catch (e) {
      // 如果UTF-8失败，尝试Latin1
      try {
        return latin1.decode(responseBytes, allowInvalid: true);
      } catch (e2) {
        // 最后使用fromCharCodes作为fallback
        return String.fromCharCodes(responseBytes);
      }
    }
  }

}
