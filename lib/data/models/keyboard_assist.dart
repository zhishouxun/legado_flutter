/// 键盘辅助数据模型
/// 参考项目：io.legado.app.data.entities.KeyboardAssist
class KeyboardAssist {
  /// 类型（主键的一部分）
  final int type;

  /// 按键（主键的一部分）
  final String key;

  /// 值
  String value;

  /// 排序号
  int serialNo;

  KeyboardAssist({
    required this.type,
    required this.key,
    this.value = '',
    this.serialNo = 0,
  });

  /// 从JSON创建
  factory KeyboardAssist.fromJson(Map<String, dynamic> json) {
    return KeyboardAssist(
      type: json['type'] as int? ?? 0,
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      serialNo: json['serialNo'] as int? ?? 0,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'key': key,
      'value': value,
      'serialNo': serialNo,
    };
  }

  /// 复制
  KeyboardAssist copyWith({
    int? type,
    String? key,
    String? value,
    int? serialNo,
  }) {
    return KeyboardAssist(
      type: type ?? this.type,
      key: key ?? this.key,
      value: value ?? this.value,
      serialNo: serialNo ?? this.serialNo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeyboardAssist && other.type == type && other.key == key;
  }

  @override
  int get hashCode => type.hashCode ^ key.hashCode;
}

