/// 书签模型
class Bookmark {
  final int time; // 时间戳（毫秒）
  final String bookName;
  final String bookAuthor;
  final int chapterIndex;
  final int chapterPos;
  final String chapterName;
  final String bookText; // 书签文本
  final String content; // 完整内容

  Bookmark({
    required this.time,
    required this.bookName,
    required this.bookAuthor,
    required this.chapterIndex,
    required this.chapterPos,
    required this.chapterName,
    required this.bookText,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'bookName': bookName,
      'bookAuthor': bookAuthor,
      'chapterIndex': chapterIndex,
      'chapterPos': chapterPos,
      'chapterName': chapterName,
      'bookText': bookText,
      'content': content,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      time: map['time'] as int,
      bookName: map['bookName'] as String,
      bookAuthor: map['bookAuthor'] as String,
      chapterIndex: map['chapterIndex'] as int,
      chapterPos: map['chapterPos'] as int,
      chapterName: map['chapterName'] as String,
      bookText: map['bookText'] as String,
      content: map['content'] as String,
    );
  }
}

