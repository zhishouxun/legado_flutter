import 'dart:convert';
import '../data/models/book_source.dart';
import '../data/models/rss_source.dart';
import '../data/models/replace_rule.dart';
import '../data/models/dict_rule.dart';
import 'source/book_source_service.dart';
import 'rss_service.dart';
import 'replace_rule_service.dart';
import 'dict_rule_service.dart';
import 'network/network_service.dart';
import '../utils/app_log.dart';

/// 二维码扫描结果处理器
class QrcodeResultHandler {
  static final QrcodeResultHandler instance = QrcodeResultHandler._init();

  QrcodeResultHandler._init();

  /// 处理扫描结果
  /// 返回 true 表示已处理，false 表示需要用户选择
  Future<bool> handleResult(String result) async {
    try {
      // 尝试解析为JSON（可能是书源、规则等）
      if (result.trim().startsWith('{') || result.trim().startsWith('[')) {
        return await _handleJsonResult(result);
      }

      // 尝试解析为URL
      if (result.startsWith('http://') || result.startsWith('https://')) {
        return await _handleUrlResult(result);
      }

      // 尝试解析为base64编码的JSON
      if (_isBase64(result)) {
        try {
          final decoded = utf8.decode(base64Decode(result));
          return await _handleJsonResult(decoded);
        } catch (e) {
          // base64解码失败，继续其他处理
        }
      }

      // 无法自动处理
      return false;
    } catch (e) {
      AppLog.instance.put('处理二维码结果失败: $e', error: e);
      return false;
    }
  }

  /// 处理JSON结果
  Future<bool> _handleJsonResult(String jsonStr) async {
    try {
      final json = jsonDecode(jsonStr);
      
      if (json is Map) {
        // 单个书源
        if (json.containsKey('bookSourceUrl')) {
          final source = BookSource.fromJson(Map<String, dynamic>.from(json));
          await BookSourceService.instance.addBookSource(source);
          return true;
        }
        
        // 单个替换规则
        if (json.containsKey('pattern') && json.containsKey('replacement')) {
          try {
            final rule = ReplaceRule.fromJson(Map<String, dynamic>.from(json));
            await ReplaceRuleService.instance.addOrUpdateRule(rule);
            AppLog.instance.put('替换规则导入成功: ${rule.name}');
            return true;
          } catch (e) {
            AppLog.instance.put('导入替换规则失败: $e', error: e);
            return false;
          }
        }
        
        // 单个字典规则
        if (json.containsKey('urlRule') || json.containsKey('showRule')) {
          try {
            final rule = DictRule.fromJson(Map<String, dynamic>.from(json));
            await DictRuleService.instance.addOrUpdateRule(rule);
            AppLog.instance.put('字典规则导入成功: ${rule.name}');
            return true;
          } catch (e) {
            AppLog.instance.put('导入字典规则失败: $e', error: e);
            return false;
          }
        }
        
        // 单个RSS源
        if (json.containsKey('sourceUrl')) {
          try {
            final source = RssSource.fromJson(Map<String, dynamic>.from(json));
            await RssService.instance.addOrUpdateRssSource(source);
            AppLog.instance.put('RSS源导入成功: ${source.sourceName}');
            return true;
          } catch (e) {
            AppLog.instance.put('导入RSS源失败: $e', error: e);
            return false;
          }
        }
      } else if (json is List) {
        // 批量导入
        if (json.isNotEmpty) {
          final firstItem = json.first;
          if (firstItem is Map) {
            // 书源列表
            if (firstItem.containsKey('bookSourceUrl')) {
              final sources = json.map((item) {
                if (item is Map<String, dynamic>) {
                  return BookSource.fromJson(item);
                } else if (item is Map) {
                  return BookSource.fromJson(Map<String, dynamic>.from(item));
                }
                throw Exception('Invalid book source format');
              }).toList();
              final result = await BookSourceService.instance.importBookSources(sources);
              final imported = result['imported'] ?? 0;
              final blocked = result['blocked'] ?? 0;
              AppLog.instance.put('批量导入书源成功: $imported 个，已过滤 $blocked 个18+网站');
              return true;
            }
            
            // 替换规则列表
            if (firstItem.containsKey('pattern')) {
              try {
                final rules = json.map((item) {
                  if (item is Map<String, dynamic>) {
                    return ReplaceRule.fromJson(item);
                  } else if (item is Map) {
                    return ReplaceRule.fromJson(Map<String, dynamic>.from(item));
                  }
                  throw Exception('Invalid replace rule format');
                }).toList();
                
                for (final rule in rules) {
                  await ReplaceRuleService.instance.addOrUpdateRule(rule);
                }
                AppLog.instance.put('替换规则批量导入成功: ${rules.length} 个');
                return true;
              } catch (e) {
                AppLog.instance.put('批量导入替换规则失败: $e', error: e);
                return false;
              }
            }
            
            // 字典规则列表
            if (firstItem.containsKey('urlRule') || firstItem.containsKey('showRule')) {
              try {
                final rules = json.map((item) {
                  if (item is Map<String, dynamic>) {
                    return DictRule.fromJson(item);
                  } else if (item is Map) {
                    return DictRule.fromJson(Map<String, dynamic>.from(item));
                  }
                  throw Exception('Invalid dict rule format');
                }).toList();
                
                for (final rule in rules) {
                  await DictRuleService.instance.addOrUpdateRule(rule);
                }
                AppLog.instance.put('字典规则批量导入成功: ${rules.length} 个');
                return true;
              } catch (e) {
                AppLog.instance.put('批量导入字典规则失败: $e', error: e);
                return false;
              }
            }
            
            // RSS源列表
            if (firstItem.containsKey('sourceUrl')) {
              try {
                final sources = json.map((item) {
                  if (item is Map<String, dynamic>) {
                    return RssSource.fromJson(item);
                  } else if (item is Map) {
                    return RssSource.fromJson(Map<String, dynamic>.from(item));
                  }
                  throw Exception('Invalid RSS source format');
                }).toList();
                
                for (final source in sources) {
                  await RssService.instance.addOrUpdateRssSource(source);
                }
                AppLog.instance.put('RSS源批量导入成功: ${sources.length} 个');
                return true;
              } catch (e) {
                AppLog.instance.put('批量导入RSS源失败: $e', error: e);
                return false;
              }
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      AppLog.instance.put('解析JSON失败: $e', error: e);
      return false;
    }
  }

  /// 处理URL结果
  Future<bool> _handleUrlResult(String url) async {
    try {
      // 从URL下载内容
      final response = await NetworkService.instance.get(url, retryCount: 1);
      final content = await NetworkService.getResponseText(response);
      
      if (content.isEmpty) {
        return false;
      }

      // 尝试解析为JSON
      return await _handleJsonResult(content);
    } catch (e) {
      AppLog.instance.put('处理URL失败: $e', error: e);
      return false;
    }
  }

  /// 判断是否为base64编码
  bool _isBase64(String str) {
    try {
      base64Decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }
}

