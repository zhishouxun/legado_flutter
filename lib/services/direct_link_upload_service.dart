import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../core/base/base_service.dart';
import '../utils/default_data.dart';
import '../utils/app_log.dart';
import '../services/network/network_service.dart';
import '../utils/parsers/rule_parser.dart';

/// 直链上传规则
class DirectLinkUploadRule {
  final String uploadUrl;
  final String downloadUrlRule;
  final String summary;
  final bool compress;

  DirectLinkUploadRule({
    required this.uploadUrl,
    required this.downloadUrlRule,
    required this.summary,
    required this.compress,
  });

  factory DirectLinkUploadRule.fromJson(Map<String, dynamic> json) {
    return DirectLinkUploadRule(
      uploadUrl: json['uploadUrl'] as String? ?? '',
      downloadUrlRule: json['downloadUrlRule'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      compress: json['compress'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uploadUrl': uploadUrl,
      'downloadUrlRule': downloadUrlRule,
      'summary': summary,
      'compress': compress,
    };
  }
}

/// 直链上传服务
class DirectLinkUploadService extends BaseService {
  static final DirectLinkUploadService instance = DirectLinkUploadService._init();
  DirectLinkUploadService._init();

  /// 获取所有上传规则
  Future<List<DirectLinkUploadRule>> getUploadRules() async {
    try {
      final rulesData = await DefaultData.instance.directLinkUploadRules;
      return rulesData
          .map((item) => DirectLinkUploadRule.fromJson(item))
          .toList();
    } catch (e) {
      AppLog.instance.put('获取直链上传规则失败', error: e);
      return [];
    }
  }

  /// 上传文件并获取下载链接
  /// [filePath] 文件路径
  /// [rule] 上传规则
  /// 返回下载链接
  Future<String?> uploadFile(String filePath, DirectLinkUploadRule rule) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }

      // 解析上传URL（可能包含请求配置）
      final uploadConfig = _parseUploadUrl(rule.uploadUrl);
      final url = uploadConfig['url'] as String;
      final body = uploadConfig['body'] as Map<String, dynamic>? ?? {};
      final type = uploadConfig['type'] as String? ?? 'multipart/form-data';

      // 读取文件
      final fileBytes = await file.readAsBytes();
      
      // 如果需要压缩，这里可以添加压缩逻辑
      // if (rule.compress) { ... }

      // 构建请求
      Map<String, String> headers = {};
      dynamic requestBody;

      if (type == 'multipart/form-data') {
        // 处理 multipart/form-data
        final formData = FormData();
        
        // 根据 body 配置添加字段
        for (final entry in body.entries) {
          final key = entry.key;
          final value = entry.value;
          
          if (value == 'fileRequest') {
            // 文件字段
            final fileName = file.path.split('/').last;
            formData.files.add(MapEntry(
              key,
              MultipartFile.fromBytes(
                fileBytes,
                filename: fileName,
              ),
            ));
          } else {
            // 普通字段
            formData.fields.add(MapEntry(key, value.toString()));
          }
        }
        
        requestBody = formData;
      } else {
        requestBody = fileBytes;
      }

      // 发送上传请求
      final response = await NetworkService.instance.post(
        url,
        data: requestBody,
        headers: headers,
      );

      final responseText = await NetworkService.getResponseText(response);

      // 使用规则解析下载链接
      if (rule.downloadUrlRule.isNotEmpty) {
        final downloadUrl = await RuleParser.parseRuleAsync(
          responseText,
          rule.downloadUrlRule,
          baseUrl: url,
        );
        return downloadUrl;
      }

      return responseText;
    } catch (e) {
      AppLog.instance.put('上传文件失败', error: e);
      return null;
    }
  }

  /// 解析上传URL配置
  /// 格式: "url,{json配置}"
  Map<String, dynamic> _parseUploadUrl(String uploadUrl) {
    try {
      final parts = uploadUrl.split(',');
      if (parts.length < 2) {
        return {'url': uploadUrl};
      }

      final url = parts[0];
      final configJson = parts.sublist(1).join(',');
      final config = jsonDecode(configJson) as Map<String, dynamic>;

      return {
        'url': url,
        ...config,
      };
    } catch (e) {
      AppLog.instance.put('解析上传URL配置失败', error: e);
      return {'url': uploadUrl};
    }
  }
}

