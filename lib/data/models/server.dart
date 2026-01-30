import 'dart:convert';

/// 服务器类型
enum ServerType {
  webdav,
}

/// 服务器数据模型
/// 参考项目：io.legado.app.data.entities.Server
class Server {
  /// 服务器ID（主键）
  final int id;

  /// 服务器名称
  String name;

  /// 服务器类型
  ServerType type;

  /// 配置（JSON字符串）
  String? config;

  /// 排序号
  int sortNumber;

  Server({
    int? id,
    this.name = '',
    this.type = ServerType.webdav,
    this.config,
    this.sortNumber = 0,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      name: json['name'] as String? ?? '',
      type: ServerType.values.firstWhere(
        (e) => e.index == (json['type'] as int? ?? 0),
        orElse: () => ServerType.webdav,
      ),
      config: json['config'] as String?,
      sortNumber: json['sortNumber'] as int? ?? 0,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'config': config,
      'sortNumber': sortNumber,
    };
  }

  /// 获取WebDAV配置
  WebDavConfig? getWebDavConfig() {
    if (type != ServerType.webdav || config == null) {
      return null;
    }
    try {
      final json = jsonDecode(config!);
      return WebDavConfig.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      return null;
    }
  }

  /// 设置WebDAV配置
  void setWebDavConfig(WebDavConfig webDavConfig) {
    if (type == ServerType.webdav) {
      config = jsonEncode(webDavConfig.toJson());
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Server && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// WebDAV配置
class WebDavConfig {
  final String url;
  final String username;
  final String password;

  WebDavConfig({
    required this.url,
    required this.username,
    required this.password,
  });

  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      url: json['url'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'username': username,
      'password': password,
    };
  }
}

