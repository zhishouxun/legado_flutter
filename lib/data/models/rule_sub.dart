/// 规则订阅数据模型
/// 参考项目：io.legado.app.data.entities.RuleSub
class RuleSub {
  /// 订阅ID（主键）
  final int id;

  /// 订阅名称
  String name;

  /// 订阅URL
  String url;

  /// 订阅类型（0=书源, 1=替换规则, 2=字典规则等）
  int type;

  /// 自定义排序
  int customOrder;

  /// 自动更新
  bool autoUpdate;

  /// 更新时间
  int update;

  RuleSub({
    int? id,
    this.name = '',
    this.url = '',
    this.type = 0,
    this.customOrder = 0,
    this.autoUpdate = false,
    int? update,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch,
        update = update ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory RuleSub.fromJson(Map<String, dynamic> json) {
    return RuleSub(
      id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      customOrder: json['customOrder'] as int? ?? 0,
      autoUpdate: json['autoUpdate'] == 1 || json['autoUpdate'] == true,
      update: json['update'] as int?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'customOrder': customOrder,
      'autoUpdate': autoUpdate ? 1 : 0,
      'update': update,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RuleSub && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

