import 'package:json_annotation/json_annotation.dart';

/// 书籍分组模型
@JsonSerializable()
class BookGroup {
  /// 分组ID（主键）
  @JsonKey(name: 'groupId')
  final int groupId;

  /// 分组名称
  @JsonKey(name: 'groupName')
  String groupName;

  /// 封面图片URL
  @JsonKey(name: 'cover')
  String? cover;

  /// 排序顺序
  @JsonKey(name: 'order')
  int order;

  /// 是否启用刷新
  @JsonKey(name: 'enableRefresh')
  bool enableRefresh;

  /// 是否显示
  @JsonKey(name: 'show')
  bool show;

  /// 书籍排序方式（-1表示使用全局设置）
  @JsonKey(name: 'bookSort')
  int bookSort;

  /// 特殊分组ID常量
  static const int idRoot = -100;
  static const int idAll = -1;
  static const int idLocal = -2;
  static const int idAudio = -3;
  static const int idNetNone = -4;
  static const int idLocalNone = -5;
  static const int idError = -11;

  BookGroup({
    required this.groupId,
    required this.groupName,
    this.cover,
    this.order = 0,
    this.enableRefresh = true,
    this.show = true,
    this.bookSort = -1,
  });

  /// 获取实际使用的书籍排序方式
  int getRealBookSort(int globalBookSort) {
    if (bookSort < 0) {
      return globalBookSort;
    }
    return bookSort;
  }

  /// 从JSON创建
  factory BookGroup.fromJson(Map<String, dynamic> json) => BookGroup(
        groupId: json['groupId'] as int,
        groupName: json['groupName'] as String,
        cover: json['cover'] as String?,
        order: json['order'] as int? ?? 0,
        enableRefresh: json['enableRefresh'] == 1 || json['enableRefresh'] == true,
        show: json['show'] == 1 || json['show'] == true,
        bookSort: json['bookSort'] as int? ?? -1,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupName': groupName,
        'cover': cover,
        'order': order,
        'enableRefresh': enableRefresh ? 1 : 0,
        'show': show ? 1 : 0,
        'bookSort': bookSort,
      };

  /// 复制并修改
  BookGroup copyWith({
    int? groupId,
    String? groupName,
    String? cover,
    int? order,
    bool? enableRefresh,
    bool? show,
    int? bookSort,
  }) {
    return BookGroup(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      cover: cover ?? this.cover,
      order: order ?? this.order,
      enableRefresh: enableRefresh ?? this.enableRefresh,
      show: show ?? this.show,
      bookSort: bookSort ?? this.bookSort,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookGroup &&
        other.groupId == groupId &&
        other.groupName == groupName &&
        other.cover == cover &&
        other.order == order &&
        other.enableRefresh == enableRefresh &&
        other.show == show &&
        other.bookSort == bookSort;
  }

  @override
  int get hashCode {
    return groupId.hashCode ^
        groupName.hashCode ^
        (cover?.hashCode ?? 0) ^
        order.hashCode ^
        enableRefresh.hashCode ^
        show.hashCode ^
        bookSort.hashCode;
  }
}

