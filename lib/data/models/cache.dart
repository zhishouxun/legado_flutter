/// Cache 实体
/// 参考项目：Cache.kt
class Cache {
  final String key;
  String? value;
  int deadline; // 过期时间（毫秒时间戳），0表示永不过期

  Cache({
    required this.key,
    this.value,
    this.deadline = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'deadline': deadline,
    };
  }

  factory Cache.fromMap(Map<String, dynamic> map) {
    return Cache(
      key: map['key'] as String,
      value: map['value'] as String?,
      deadline: map['deadline'] as int? ?? 0,
    );
  }
}

