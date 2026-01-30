/// 替换规则模型
class ReplaceRule {
  /// 规则ID（主键，自增）
  final int id;

  /// 规则名称
  final String name;

  /// 替换模式（正则表达式或普通文本）
  String pattern;

  /// 替换内容
  String replacement;

  /// 是否启用
  bool enabled;

  /// 排序序号
  int sortNumber;

  /// 规则分组（可选）
  String? group;

  /// 作用范围（书籍名称或来源，用逗号分隔）
  String? scope;

  /// 是否作用于标题
  bool scopeTitle;

  /// 是否作用于正文
  bool scopeContent;

  /// 排除范围（书籍名称或来源，用逗号分隔）
  String? excludeScope;

  /// 是否为正则表达式（true=正则，false=普通文本替换）
  bool isRegex;

  /// 超时时间（毫秒，防止正则表达式执行时间过长）
  int timeoutMillisecond;

  ReplaceRule({
    int? id,
    required this.name,
    this.pattern = '',
    this.replacement = '',
    this.enabled = true,
    this.sortNumber = 0,
    this.group,
    this.scope,
    this.scopeTitle = false,
    this.scopeContent = true,
    this.excludeScope,
    this.isRegex = true,
    this.timeoutMillisecond = 3000,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory ReplaceRule.fromJson(Map<String, dynamic> json) {
    // 兼容旧格式（使用name作为主键）和新格式（使用id作为主键）
    final id = json['id'] as int? ?? 
               (json['name'] != null ? json['name'].hashCode : DateTime.now().millisecondsSinceEpoch);
    
    return ReplaceRule(
      id: id,
      name: json['name'] as String? ?? '',
      pattern: json['pattern'] as String? ?? json['regex'] as String? ?? '',
      replacement: json['replacement'] as String? ?? '',
      enabled: json['enabled'] == 1 || json['enabled'] == true || json['isEnabled'] == true,
      sortNumber: json['sortNumber'] as int? ?? json['order'] as int? ?? json['serialNumber'] as int? ?? 0,
      group: json['group'] as String?,
      scope: json['scope'] as String? ?? json['useTo'] as String?,
      scopeTitle: json['scopeTitle'] == 1 || json['scopeTitle'] == true,
      scopeContent: json['scopeContent'] == 1 || json['scopeContent'] == true || json['scopeContent'] == null,
      excludeScope: json['excludeScope'] as String?,
      isRegex: json['isRegex'] == 1 || json['isRegex'] == true || json['isRegex'] == null,
      timeoutMillisecond: json['timeoutMillisecond'] as int? ?? 3000,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'replacement': replacement,
      'enabled': enabled ? 1 : 0,
      'sortNumber': sortNumber,
      'group': group,
      'scope': scope,
      'scopeTitle': scopeTitle ? 1 : 0,
      'scopeContent': scopeContent ? 1 : 0,
      'excludeScope': excludeScope,
      'isRegex': isRegex ? 1 : 0,
      'timeoutMillisecond': timeoutMillisecond,
    };
  }

  /// 复制
  ReplaceRule copyWith({
    int? id,
    String? name,
    String? pattern,
    String? replacement,
    bool? enabled,
    int? sortNumber,
    String? group,
    String? scope,
    bool? scopeTitle,
    bool? scopeContent,
    String? excludeScope,
    bool? isRegex,
    int? timeoutMillisecond,
  }) {
    return ReplaceRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      enabled: enabled ?? this.enabled,
      sortNumber: sortNumber ?? this.sortNumber,
      group: group ?? this.group,
      scope: scope ?? this.scope,
      scopeTitle: scopeTitle ?? this.scopeTitle,
      scopeContent: scopeContent ?? this.scopeContent,
      excludeScope: excludeScope ?? this.excludeScope,
      isRegex: isRegex ?? this.isRegex,
      timeoutMillisecond: timeoutMillisecond ?? this.timeoutMillisecond,
    );
  }

  /// 获取显示名称（包含分组）
  String getDisplayNameGroup() {
    if (group == null || group!.isEmpty) {
      return name;
    } else {
      return '$name ($group)';
    }
  }

  /// 验证规则是否有效
  bool isValid() {
    if (pattern.isEmpty) {
      return false;
    }
    
    // 如果是正则表达式，验证正则语法
    if (isRegex) {
      try {
        RegExp(pattern);
        // 检查是否以未转义的 | 结尾（可能导致超时）
        if (pattern.endsWith('|') && !pattern.endsWith('\\|')) {
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    
    return true;
  }

  /// 获取有效的超时时间
  int getValidTimeoutMillisecond() {
    if (timeoutMillisecond <= 0) {
      return 3000;
    }
    return timeoutMillisecond;
  }
}

