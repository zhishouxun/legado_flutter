import 'dart:convert';
import 'package:flutter/services.dart';
import 'network_utils.dart';
import 'app_log.dart';

/// 18+ 网站过滤工具类
/// 参考项目：SourceHelp.kt 的 is18Plus() 方法
class EighteenPlusFilter {
  static final EighteenPlusFilter instance = EighteenPlusFilter._init();
  
  Set<String>? _list18Plus;
  bool _isLoading = false;

  EighteenPlusFilter._init();

  /// 加载 18+ 网站列表
  Future<void> _loadList() async {
    if (_list18Plus != null || _isLoading) return;
    
    _isLoading = true;
    try {
      final String content = await rootBundle.loadString('assets/18PlusList.txt');
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      _list18Plus = <String>{};
      for (final line in lines) {
        try {
          // Base64 解码
          final decoded = utf8.decode(base64Decode(line.trim()));
          if (decoded.isNotEmpty) {
            _list18Plus!.add(decoded);
          }
        } catch (e) {
          // 跳过解码失败的条目
          AppLog.instance.put('18PlusList 解码失败: $line, error: $e');
        }
      }
      
      AppLog.instance.put('18PlusList 加载完成: ${_list18Plus!.length} 条');
    } catch (e) {
      AppLog.instance.put('加载 18PlusList 失败: $e', error: e);
      _list18Plus = <String>{};
    } finally {
      _isLoading = false;
    }
  }

  /// 检查 URL 是否为 18+ 网站
  /// 参考项目：SourceHelp.is18Plus()
  Future<bool> is18Plus(String? url) async {
    await _loadList();
    
    if (_list18Plus == null || _list18Plus!.isEmpty) {
      return false;
    }
    
    if (url == null || url.isEmpty) {
      return false;
    }
    
    try {
      final baseUrl = NetworkUtils.getBaseUrl(url);
      if (baseUrl == null) {
        return false;
      }
      
      // 提取域名（参考项目的逻辑）
      final uri = Uri.parse(baseUrl);
      final host = uri.host;
      
      // 如果是 IP 地址，直接检查
      if (NetworkUtils.isIPAddress(host)) {
        return _list18Plus!.contains(host);
      }
      
      // 提取主域名（例如：www.example.com -> example.com）
      final parts = host.split('.');
      if (parts.length >= 2) {
        // 获取最后两部分作为主域名
        final domain = '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
        if (_list18Plus!.contains(domain)) {
          return true;
        }
      }
      
      // 也检查完整主机名
      return _list18Plus!.contains(host);
    } catch (e) {
      AppLog.instance.put('检查 18+ 网站失败: $url, error: $e');
      return false;
    }
  }

  /// 检查并过滤 18+ 网站（批量）
  /// 返回：{过滤后的列表, 被过滤的列表}
  Future<Map<String, List<T>>> filter18Plus<T>({
    required List<T> items,
    required String Function(T) getUrl,
    required String Function(T) getName,
  }) async {
    await _loadList();
    
    final filtered = <T>[];
    final blocked = <T>[];
    
    for (final item in items) {
      final url = getUrl(item);
      final isBlocked = await is18Plus(url);
      
      if (isBlocked) {
        blocked.add(item);
        AppLog.instance.put('${getName(item)} 是18+网址,禁止导入.');
      } else {
        filtered.add(item);
      }
    }
    
    return {
      'filtered': filtered,
      'blocked': blocked,
    };
  }
}

