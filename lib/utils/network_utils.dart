import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_log.dart';

/// 网络工具类
/// 参考项目：NetworkUtils.kt
class NetworkUtils {
  /// 判断是否联网
  /// 参考项目：NetworkUtils.isAvailable
  static Future<bool> isAvailable() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      AppLog.instance.put('NetworkUtils.isAvailable error: $e');
      return false;
    }
  }

  /// 判断URL查询参数是否已编码
  /// 参考项目：NetworkUtils.encodedQuery
  static bool encodedQuery(String str) {
    // 不需要编码的字符：0-9a-zA-Z 和 !*'();:@&=+$,/?#[]
    // 使用字符类检查
    for (int i = 0; i < str.length; i++) {
      final code = str.codeUnitAt(i);
      final c = str[i];
      
      // 检查是否在不需要编码的范围内
      if ((code >= 48 && code <= 57) || // 0-9
          (code >= 65 && code <= 90) || // A-Z
          (code >= 97 && code <= 122) || // a-z
          '!\$&()*+,-./:;=?@[\\]^_`{|}~'.contains(c)) {
        continue;
      }
      
      // 检查是否是 %XX 格式（已编码）
      if (c == '%' && i + 2 < str.length) {
        final c1 = str[i + 1];
        final c2 = str[i + 2];
        if (_isHexChar(c1) && _isHexChar(c2)) {
          i += 2; // 跳过已编码的字符
          continue;
        }
      }
      
      // 其他字符，需要编码
      return false;
    }
    
    return true;
  }

  /// 判断表单数据是否已编码
  /// 参考项目：NetworkUtils.encodedForm
  static bool encodedForm(String str) {
    // 不需要编码的字符：0-9a-zA-Z 和 *-._
    for (int i = 0; i < str.length; i++) {
      final code = str.codeUnitAt(i);
      final c = str[i];
      
      // 检查是否在不需要编码的范围内
      if ((code >= 48 && code <= 57) || // 0-9
          (code >= 65 && code <= 90) || // A-Z
          (code >= 97 && code <= 122) || // a-z
          '*-._'.contains(c)) {
        continue;
      }
      
      // 检查是否是 %XX 格式（已编码）
      if (c == '%' && i + 2 < str.length) {
        final c1 = str[i + 1];
        final c2 = str[i + 2];
        if (_isHexChar(c1) && _isHexChar(c2)) {
          i += 2; // 跳过已编码的字符
          continue;
        }
      }
      
      // 其他字符，需要编码
      return false;
    }
    
    return true;
  }

  /// 判断c是否是16进制的字符
  static bool _isHexChar(String c) {
    return (c.compareTo('0') >= 0 && c.compareTo('9') <= 0) ||
        (c.compareTo('A') >= 0 && c.compareTo('F') <= 0) ||
        (c.compareTo('a') >= 0 && c.compareTo('f') <= 0);
  }

  /// 获取绝对地址
  /// 参考项目：NetworkUtils.getAbsoluteURL
  static String getAbsoluteURL(String? baseURL, String relativePath) {
    if (baseURL == null || baseURL.isEmpty) {
      return relativePath.trim();
    }
    
    try {
      // 处理多个URL（逗号分隔）
      final url = baseURL.split(',')[0].trim();
      final baseUri = Uri.parse(url);
      return getAbsoluteURLFromUri(baseUri, relativePath);
    } catch (e) {
      AppLog.instance.put('getAbsoluteURL error: $e');
      return relativePath.trim();
    }
  }

  /// 从Uri获取绝对地址
  static String getAbsoluteURLFromUri(Uri? baseURL, String relativePath) {
    final relativePathTrim = relativePath.trim();
    if (baseURL == null) return relativePathTrim;
    
    // 如果已经是绝对URL，直接返回
    if (relativePathTrim.isAbsUrl()) return relativePathTrim;
    
    // 如果是data: URL，直接返回
    if (relativePathTrim.isDataUrl()) return relativePathTrim;
    
    // 如果是javascript:，返回空字符串
    if (relativePathTrim.toLowerCase().startsWith('javascript')) {
      return '';
    }
    
    // 检查baseURL是否有有效的主机
    if (baseURL.host.isEmpty) {
      AppLog.instance.put('getAbsoluteURLFromUri: baseURL没有有效的主机，baseURL=$baseURL, relativePath=$relativePathTrim');
      return relativePathTrim;
    }
    
    try {
      final absoluteUri = baseURL.resolve(relativePath);
      return absoluteUri.toString();
    } catch (e) {
      AppLog.instance.put('getAbsoluteURLFromUri error: $e, baseURL=$baseURL, relativePath=$relativePathTrim');
      return relativePathTrim;
    }
  }

  /// 获取基础URL
  /// 参考项目：NetworkUtils.getBaseUrl
  static String? getBaseUrl(String? url) {
    if (url == null) return null;
    
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.startsWith('http://') || lowerUrl.startsWith('https://')) {
      final index = url.indexOf('/', 9); // 跳过 http:// 或 https://
      if (index == -1) {
        return url;
      } else {
        return url.substring(0, index);
      }
    }
    
    return null;
  }

  /// 获取域名，供cookie保存和读取
  /// 参考项目：NetworkUtils.getSubDomain
  /// http://1.2.3.4 => 1.2.3.4
  /// https://www.example.com => example.com
  static String getSubDomain(String url) {
    final baseUrl = getBaseUrl(url);
    if (baseUrl == null) return url;
    
    try {
      final uri = Uri.parse(baseUrl);
      final host = uri.host;
      
      // 判断是否为IP地址
      if (isIPAddress(host)) {
        return host;
      }
      
      // 获取有效域名（主域名）
      // 简化实现：移除 www. 前缀
      if (host.startsWith('www.')) {
        return host.substring(4);
      }
      
      // 更复杂的域名处理需要使用公共后缀数据库
      // 这里简化处理，返回host
      return host;
    } catch (e) {
      AppLog.instance.put('getSubDomain error: $e');
      return baseUrl;
    }
  }

  /// 获取域名（可能为null）
  static String? getSubDomainOrNull(String url) {
    final baseUrl = getBaseUrl(url);
    if (baseUrl == null) return null;
    
    try {
      final uri = Uri.parse(baseUrl);
      final host = uri.host;
      
      if (isIPAddress(host)) {
        return host;
      }
      
      if (host.startsWith('www.')) {
        return host.substring(4);
      }
      
      return host;
    } catch (e) {
      return null;
    }
  }

  /// 获取域名
  /// 参考项目：NetworkUtils.getDomain
  static String getDomain(String url) {
    final baseUrl = getBaseUrl(url);
    if (baseUrl == null) return url;
    
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host;
    } catch (e) {
      return baseUrl;
    }
  }

  /// 获取本地IP地址
  /// 参考项目：NetworkUtils.getLocalIPAddress
  static Future<List<InternetAddress>> getLocalIPAddress() async {
    try {
      final addresses = <InternetAddress>[];
      
      // 获取所有网络接口
      for (final interface in await NetworkInterface.list()) {
        // 获取接口的所有地址
        for (final addr in interface.addresses) {
          // 只返回IPv4地址，且不是回环地址
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback) {
            addresses.add(addr);
          }
        }
      }
      
      return addresses;
    } catch (e) {
      AppLog.instance.put('getLocalIPAddress error: $e');
      return [];
    }
  }

  /// 检查是否为有效的IPv4地址
  /// 参考项目：NetworkUtils.isIPv4Address
  static bool isIPv4Address(String? input) {
    if (input == null || input.isEmpty) return false;
    
    // 基本格式检查
    if (!RegExp(r'^[1-9]\d{0,2}(\.\d{1,3}){3}$').hasMatch(input)) {
      return false;
    }
    
    // 检查每个部分是否在0-255范围内
    final parts = input.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }
    
    return true;
  }

  /// 检查是否为有效的IPv6地址
  /// 参考项目：NetworkUtils.isIPv6Address
  static bool isIPv6Address(String? input) {
    if (input == null || !input.contains(':')) return false;
    
    // 简化的IPv6地址检查
    // 实际应该使用更完善的IPv6地址验证
    try {
      final addr = InternetAddress(input);
      return addr.type == InternetAddressType.IPv6;
    } catch (e) {
      return false;
    }
  }

  /// 检查是否为有效的IP地址
  /// 参考项目：NetworkUtils.isIPAddress
  static bool isIPAddress(String? input) {
    return isIPv4Address(input) || isIPv6Address(input);
  }
}

/// 扩展方法：判断是否为绝对URL
extension StringUrlExtension on String {
  bool isAbsUrl() {
    final lower = toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  bool isDataUrl() {
    return toLowerCase().startsWith('data:');
  }
}

