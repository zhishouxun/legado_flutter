/// 阅读记录实体
/// 参考项目：ReadRecord.kt
class ReadRecordEntity {
  /// 设备ID（用于区分不同设备）
  final String deviceId;
  
  /// 书名
  final String bookName;
  
  /// 阅读时长（毫秒）
  final int readTime;
  
  /// 最后阅读时间（时间戳，毫秒）
  final int lastRead;

  ReadRecordEntity({
    required this.deviceId,
    required this.bookName,
    required this.readTime,
    required this.lastRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'bookName': bookName,
      'readTime': readTime,
      'lastRead': lastRead,
    };
  }

  factory ReadRecordEntity.fromMap(Map<String, dynamic> map) {
    return ReadRecordEntity(
      deviceId: map['deviceId'] as String,
      bookName: map['bookName'] as String,
      readTime: map['readTime'] as int,
      lastRead: map['lastRead'] as int,
    );
  }

  ReadRecordEntity copyWith({
    String? deviceId,
    String? bookName,
    int? readTime,
    int? lastRead,
  }) {
    return ReadRecordEntity(
      deviceId: deviceId ?? this.deviceId,
      bookName: bookName ?? this.bookName,
      readTime: readTime ?? this.readTime,
      lastRead: lastRead ?? this.lastRead,
    );
  }
}

