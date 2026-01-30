/// 阅读记录显示模型
class ReadRecordShow {
  final String bookName;
  final int readTime; // 阅读时长（毫秒）
  final int lastRead; // 最后阅读时间（毫秒）

  ReadRecordShow({
    required this.bookName,
    required this.readTime,
    required this.lastRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookName': bookName,
      'readTime': readTime,
      'lastRead': lastRead,
    };
  }

  factory ReadRecordShow.fromMap(Map<String, dynamic> map) {
    return ReadRecordShow(
      bookName: map['bookName'] as String,
      readTime: map['readTime'] as int,
      lastRead: map['lastRead'] as int,
    );
  }
}

