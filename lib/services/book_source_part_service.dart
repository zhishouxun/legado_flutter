import '../core/base/base_service.dart';
import '../data/database/app_database.dart';

/// 书源部分字段数据模型
/// 参考项目：io.legado.app.data.entities.BookSourcePart（数据库视图）
class BookSourcePart {
  final String bookSourceUrl;
  final String bookSourceName;
  final String? bookSourceGroup;
  final int customOrder;
  final bool enabled;
  final bool enabledExplore;
  final bool hasLoginUrl;
  final int lastUpdateTime;
  final int respondTime;
  final int weight;
  final bool hasExploreUrl;

  BookSourcePart({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    required this.customOrder,
    required this.enabled,
    required this.enabledExplore,
    required this.hasLoginUrl,
    required this.lastUpdateTime,
    required this.respondTime,
    required this.weight,
    required this.hasExploreUrl,
  });

  factory BookSourcePart.fromMap(Map<String, dynamic> map) {
    return BookSourcePart(
      bookSourceUrl: map['bookSourceUrl'] as String? ?? '',
      bookSourceName: map['bookSourceName'] as String? ?? '',
      bookSourceGroup: map['bookSourceGroup'] as String?,
      customOrder: map['customOrder'] as int? ?? 0,
      enabled: (map['enabled'] as int? ?? 0) != 0,
      enabledExplore: (map['enabledExplore'] as int? ?? 0) != 0,
      hasLoginUrl: (map['hasLoginUrl'] as int? ?? 0) != 0,
      lastUpdateTime: map['lastUpdateTime'] as int? ?? 0,
      respondTime: map['respondTime'] as int? ?? 0,
      weight: map['weight'] as int? ?? 0,
      hasExploreUrl: (map['hasExploreUrl'] as int? ?? 0) != 0,
    );
  }
}

/// 书源部分字段查询服务
/// 参考项目：io.legado.app.data.entities.BookSourcePart（数据库视图）
/// 
/// 由于 sqflite 不支持数据库视图，使用查询方法实现相同功能
class BookSourcePartService extends BaseService {
  static final BookSourcePartService instance = BookSourcePartService._init();
  final AppDatabase _db = AppDatabase.instance;

  BookSourcePartService._init();

  /// 获取所有书源部分字段
  /// 相当于查询数据库视图 book_sources_part
  Future<List<BookSourcePart>> getAll() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return [];

        // 模拟数据库视图查询
        final result = await db.rawQuery('''
          SELECT 
            bookSourceUrl, 
            bookSourceName, 
            bookSourceGroup, 
            customOrder, 
            enabled, 
            enabledExplore, 
            (loginUrl IS NOT NULL AND TRIM(loginUrl) <> '') as hasLoginUrl, 
            lastUpdateTime, 
            respondTime, 
            weight, 
            (exploreUrl IS NOT NULL AND TRIM(exploreUrl) <> '') as hasExploreUrl 
          FROM book_sources
        ''');

        return result.map((row) => BookSourcePart.fromMap(row)).toList();
      },
      operationName: '获取书源部分字段列表',
      logError: true,
      defaultValue: [],
    );
  }

  /// 根据URL获取书源部分字段
  Future<BookSourcePart?> getByUrl(String url) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return null;

        final result = await db.rawQuery('''
          SELECT 
            bookSourceUrl, 
            bookSourceName, 
            bookSourceGroup, 
            customOrder, 
            enabled, 
            enabledExplore, 
            (loginUrl IS NOT NULL AND TRIM(loginUrl) <> '') as hasLoginUrl, 
            lastUpdateTime, 
            respondTime, 
            weight, 
            (exploreUrl IS NOT NULL AND TRIM(exploreUrl) <> '') as hasExploreUrl 
          FROM book_sources
          WHERE bookSourceUrl = ?
        ''', [url]);

        if (result.isEmpty) return null;
        return BookSourcePart.fromMap(result.first);
      },
      operationName: '根据URL获取书源部分字段',
      logError: true,
      defaultValue: null,
    );
  }

  /// 获取启用的书源部分字段
  Future<List<BookSourcePart>> getEnabled() async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return [];

        final result = await db.rawQuery('''
          SELECT 
            bookSourceUrl, 
            bookSourceName, 
            bookSourceGroup, 
            customOrder, 
            enabled, 
            enabledExplore, 
            (loginUrl IS NOT NULL AND TRIM(loginUrl) <> '') as hasLoginUrl, 
            lastUpdateTime, 
            respondTime, 
            weight, 
            (exploreUrl IS NOT NULL AND TRIM(exploreUrl) <> '') as hasExploreUrl 
          FROM book_sources
          WHERE enabled = 1
          ORDER BY customOrder ASC
        ''');

        return result.map((row) => BookSourcePart.fromMap(row)).toList();
      },
      operationName: '获取启用的书源部分字段',
      logError: true,
      defaultValue: [],
    );
  }
}
