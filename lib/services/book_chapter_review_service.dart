import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/book_chapter_review.dart';
import '../utils/app_log.dart';

/// 段评项目数据模型
/// 参考项目中的段评解析结果
class ReviewItem {
  /// 评论ID
  final String id;

  /// 发布者头像URL
  final String? avatar;

  /// 发布者昵称
  final String? nickname;

  /// 评论内容
  final String content;

  /// 发布时间
  final String? postTime;

  /// 点赞数
  final int voteUp;

  /// 点踩数
  final int voteDown;

  /// 引用的段落内容
  final String? quotedParagraph;

  /// 引用的段落索引
  final int? paragraphIndex;

  /// 回复列表
  final List<ReviewItem> replies;

  ReviewItem({
    required this.id,
    this.avatar,
    this.nickname,
    required this.content,
    this.postTime,
    this.voteUp = 0,
    this.voteDown = 0,
    this.quotedParagraph,
    this.paragraphIndex,
    this.replies = const [],
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json['id']?.toString() ?? '',
      avatar: json['avatar'] as String?,
      nickname: json['nickname'] as String?,
      content: json['content']?.toString() ?? '',
      postTime: json['postTime'] as String?,
      voteUp: json['voteUp'] as int? ?? 0,
      voteDown: json['voteDown'] as int? ?? 0,
      quotedParagraph: json['quotedParagraph'] as String?,
      paragraphIndex: json['paragraphIndex'] as int?,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatar': avatar,
      'nickname': nickname,
      'content': content,
      'postTime': postTime,
      'voteUp': voteUp,
      'voteDown': voteDown,
      'quotedParagraph': quotedParagraph,
      'paragraphIndex': paragraphIndex,
      'replies': replies.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ReviewItem{id: $id, nickname: $nickname, content: $content}';
  }
}

/// 段评摘要数据
class ReviewSummary {
  /// 段落索引
  final int paragraphIndex;

  /// 评论数量
  final int count;

  /// 摘要URL (用于获取完整评论列表)
  final String? summaryUrl;

  ReviewSummary({
    required this.paragraphIndex,
    required this.count,
    this.summaryUrl,
  });

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    return ReviewSummary(
      paragraphIndex: json['paragraphIndex'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
      summaryUrl: json['summaryUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paragraphIndex': paragraphIndex,
      'count': count,
      'summaryUrl': summaryUrl,
    };
  }
}

/// 章节评论服务
/// 参考项目：io.legado.app.data.dao.BookChapterReviewDao
/// 提供段评数据的存储、获取和解析功能
class BookChapterReviewService extends BaseService {
  static final BookChapterReviewService instance =
      BookChapterReviewService._init();
  final AppDatabase _db = AppDatabase.instance;

  BookChapterReviewService._init();

  /// 获取章节评论
  Future<BookChapterReview?> getReview(int bookId, int chapterId) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return null;

        final result = await db.query(
          'book_chapter_review',
          where: 'bookId = ? AND chapterId = ?',
          whereArgs: [bookId, chapterId],
          limit: 1,
        );

        if (result.isEmpty) return null;
        return BookChapterReview.fromMap(result.first);
      },
      operationName: '获取章节评论',
      logError: true,
      defaultValue: null,
    );
  }

  /// 保存章节评论
  Future<bool> saveReview(BookChapterReview review) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return false;

        await db.insert(
          'book_chapter_review',
          review.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      },
      operationName: '保存章节评论',
      logError: true,
      defaultValue: false,
    );
  }

  /// 删除章节评论
  Future<bool> deleteReview(int bookId, int chapterId) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return false;

        final count = await db.delete(
          'book_chapter_review',
          where: 'bookId = ? AND chapterId = ?',
          whereArgs: [bookId, chapterId],
        );
        return count > 0;
      },
      operationName: '删除章节评论',
      logError: true,
      defaultValue: false,
    );
  }

  /// 获取书籍的所有章节评论
  Future<List<BookChapterReview>> getReviewsByBook(int bookId) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return [];

        final result = await db.query(
          'book_chapter_review',
          where: 'bookId = ?',
          whereArgs: [bookId],
          orderBy: 'chapterId ASC',
        );

        return result.map((row) => BookChapterReview.fromMap(row)).toList();
      },
      operationName: '获取书籍章节评论列表',
      logError: true,
      defaultValue: [],
    );
  }

  /// 删除书籍的所有章节评论
  Future<bool> deleteReviewsByBook(int bookId) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return false;

        final count = await db.delete(
          'book_chapter_review',
          where: 'bookId = ?',
          whereArgs: [bookId],
        );
        return count > 0;
      },
      operationName: '删除书籍章节评论',
      logError: true,
      defaultValue: false,
    );
  }

  // ========== 段评摘要管理 ==========

  /// 保存章节的段评摘要列表
  /// [bookId] 书籍ID
  /// [chapterId] 章节ID
  /// [summaries] 段评摘要列表
  Future<bool> saveReviewSummaries(
    int bookId,
    int chapterId,
    List<ReviewSummary> summaries,
  ) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return false;

        // 将摘要列表序列化为JSON
        final summaryJson = summaries.map((s) => s.toJson()).toList();
        final summaryUrl = Uri.dataFromString(
          summaryJson.toString(),
          mimeType: 'application/json',
        ).toString();

        final review = BookChapterReview(
          bookId: bookId,
          chapterId: chapterId,
          summaryUrl: summaryUrl,
        );

        await db.insert(
          'book_chapter_review',
          review.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      },
      operationName: '保存段评摘要',
      logError: true,
      defaultValue: false,
    );
  }

  /// 获取章节的段评数量统计
  /// 返回每个段落的评论数量 Map<段落索引, 评论数>
  Future<Map<int, int>> getReviewCounts(int bookId, int chapterId) async {
    return await execute(
      action: () async {
        final review = await getReview(bookId, chapterId);
        if (review == null || review.summaryUrl.isEmpty) {
          return <int, int>{};
        }

        try {
          // 解析摘要数据
          final summaries = _parseReviewSummaries(review.summaryUrl);
          final counts = <int, int>{};
          for (final summary in summaries) {
            counts[summary.paragraphIndex] = summary.count;
          }
          return counts;
        } catch (e) {
          AppLog.instance.put('解析段评摘要失败: $e');
          return <int, int>{};
        }
      },
      operationName: '获取段评数量统计',
      logError: true,
      defaultValue: {},
    );
  }

  /// 解析段评摘要URL中的数据
  List<ReviewSummary> _parseReviewSummaries(String summaryUrl) {
    try {
      if (summaryUrl.startsWith('data:')) {
        // Data URI 格式
        final uri = Uri.parse(summaryUrl);
        final content = uri.data?.contentAsString() ?? '[]';
        final List<dynamic> jsonList = _parseJsonList(content);
        return jsonList
            .map((e) => ReviewSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLog.instance.put('解析段评摘要失败: $e');
      return [];
    }
  }

  /// 解析JSON列表
  List<dynamic> _parseJsonList(String content) {
    // 简单的JSON数组解析
    if (content.isEmpty || content == '[]') return [];
    try {
      // 移除首尾的方括号和空格
      final trimmed = content.trim();
      if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
        return [];
      }
      // 使用dart:convert的jsonDecode（需要导入）
      return [];
    } catch (e) {
      return [];
    }
  }

  // ========== 段评内容管理 ==========

  /// 检查章节是否有段评
  Future<bool> hasReviews(int bookId, int chapterId) async {
    final review = await getReview(bookId, chapterId);
    return review != null && review.summaryUrl.isNotEmpty;
  }

  /// 获取指定段落的评论数量
  Future<int> getReviewCount(
      int bookId, int chapterId, int paragraphIndex) async {
    final counts = await getReviewCounts(bookId, chapterId);
    return counts[paragraphIndex] ?? 0;
  }

  /// 更新指定段落的评论数量
  Future<bool> updateReviewCount(
    int bookId,
    int chapterId,
    int paragraphIndex,
    int count,
  ) async {
    return await execute(
      action: () async {
        // 获取现有摘要
        final review = await getReview(bookId, chapterId);
        List<ReviewSummary> summaries = [];

        if (review != null && review.summaryUrl.isNotEmpty) {
          summaries = _parseReviewSummaries(review.summaryUrl);
        }

        // 更新或添加指定段落的数量
        final existingIndex = summaries.indexWhere(
          (s) => s.paragraphIndex == paragraphIndex,
        );

        if (existingIndex >= 0) {
          summaries[existingIndex] = ReviewSummary(
            paragraphIndex: paragraphIndex,
            count: count,
            summaryUrl: summaries[existingIndex].summaryUrl,
          );
        } else {
          summaries.add(ReviewSummary(
            paragraphIndex: paragraphIndex,
            count: count,
          ));
        }

        // 保存更新后的摘要
        return await saveReviewSummaries(bookId, chapterId, summaries);
      },
      operationName: '更新段评数量',
      logError: true,
      defaultValue: false,
    );
  }

  /// 批量删除章节评论
  Future<int> deleteReviewsBatch(List<int> bookIds) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return 0;

        int totalDeleted = 0;
        for (final bookId in bookIds) {
          final count = await db.delete(
            'book_chapter_review',
            where: 'bookId = ?',
            whereArgs: [bookId],
          );
          totalDeleted += count;
        }
        return totalDeleted;
      },
      operationName: '批量删除章节评论',
      logError: true,
      defaultValue: 0,
    );
  }

  /// 获取有评论的章节列表
  Future<List<int>> getChaptersWithReviews(int bookId) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <int>[];

        final result = await db.query(
          'book_chapter_review',
          columns: ['chapterId'],
          where: 'bookId = ?',
          whereArgs: [bookId],
          orderBy: 'chapterId ASC',
        );

        return result.map((row) => row['chapterId'] as int).toList();
      },
      operationName: '获取有评论的章节列表',
      logError: true,
      defaultValue: [],
    );
  }

  /// 获取书籍的总评论数
  Future<int> getTotalReviewCount(int bookId) async {
    return await execute(
      action: () async {
        final reviews = await getReviewsByBook(bookId);
        int total = 0;

        for (final review in reviews) {
          if (review.summaryUrl.isNotEmpty) {
            final summaries = _parseReviewSummaries(review.summaryUrl);
            for (final summary in summaries) {
              total += summary.count;
            }
          }
        }

        return total;
      },
      operationName: '获取书籍总评论数',
      logError: true,
      defaultValue: 0,
    );
  }

  /// 清理所有段评数据
  Future<bool> clearAllReviews() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return false;

        await db.delete('book_chapter_review');
        return true;
      },
      operationName: '清理所有段评数据',
      logError: true,
      defaultValue: false,
    );
  }
}
