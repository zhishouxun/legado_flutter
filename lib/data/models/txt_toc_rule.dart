/// TXT目录规则模型
class TxtTocRule {
  /// 规则ID（主键）
  final int id;

  /// 规则名称
  String name;

  /// 正则表达式规则
  String rule;

  /// 示例
  String? example;

  /// 排序序号
  int serialNumber;

  /// 是否启用
  bool enable;

  TxtTocRule({
    required this.id,
    required this.name,
    required this.rule,
    this.example,
    this.serialNumber = 0,
    this.enable = true,
  });

  /// 从JSON创建
  factory TxtTocRule.fromJson(Map<String, dynamic> json) {
    return TxtTocRule(
      id: json['id'] as int,
      name: json['name'] as String,
      rule: json['rule'] as String,
      example: json['example'] as String?,
      serialNumber: json['serialNumber'] as int? ?? 0,
      enable: json['enable'] == 1 || json['enable'] == true,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rule': rule,
      'example': example,
      'serialNumber': serialNumber,
      'enable': enable ? 1 : 0,
    };
  }

  /// 复制
  TxtTocRule copyWith({
    int? id,
    String? name,
    String? rule,
    String? example,
    int? serialNumber,
    bool? enable,
  }) {
    return TxtTocRule(
      id: id ?? this.id,
      name: name ?? this.name,
      rule: rule ?? this.rule,
      example: example ?? this.example,
      serialNumber: serialNumber ?? this.serialNumber,
      enable: enable ?? this.enable,
    );
  }
}

