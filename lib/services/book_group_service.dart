import 'package:sqflite/sqflite.dart';
import '../core/base/base_service.dart';
import '../data/database/app_database.dart';
import '../data/models/book_group.dart';

/// 书籍分组服务
class BookGroupService extends BaseService {
  static final BookGroupService instance = BookGroupService._init();
  final AppDatabase _db = AppDatabase.instance;

  BookGroupService._init();

  /// 获取所有显示的分组
  Future<List<BookGroup>> getAllGroups({bool showOnly = true}) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return <BookGroup>[];
        
        final result = await db.query(
          'book_groups',
          where: showOnly ? 'show = 1' : null,
          orderBy: '"order" ASC, groupId ASC',
        );
        
        return result.map((json) => _groupFromDbMap(json)).toList();
      },
      operationName: '获取所有分组',
      logError: true,
      defaultValue: <BookGroup>[],
    );
  }

  /// 根据ID获取分组
  Future<BookGroup?> getGroupById(int groupId) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) return null;
        
        final result = await db.query(
          'book_groups',
          where: 'groupId = ?',
          whereArgs: [groupId],
          limit: 1,
        );
        
        if (result.isEmpty) return null;
        return _groupFromDbMap(result.first);
      },
      operationName: '根据ID获取分组',
      logError: true,
      defaultValue: null,
    );
  }

  /// 创建分组
  Future<void> createGroup(BookGroup group) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
        
        await db.insert(
          'book_groups',
          _groupToDbMap(group),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
      operationName: '创建分组',
      logError: true,
    );
  }

  /// 更新分组
  Future<void> updateGroup(BookGroup group) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
        
        await db.update(
          'book_groups',
          _groupToDbMap(group),
          where: 'groupId = ?',
          whereArgs: [group.groupId],
        );
      },
      operationName: '更新分组',
      logError: true,
    );
  }

  /// 删除分组
  Future<void> deleteGroup(int groupId) async {
    return await execute(
      action: () async {
        final db = await _db.database;
        if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
        
        await db.delete(
          'book_groups',
          where: 'groupId = ?',
          whereArgs: [groupId],
        );
      },
      operationName: '删除分组',
      logError: true,
    );
  }

  /// 获取下一个可用的分组ID
  Future<int> getNextGroupId() async {
    final db = await _db.database;
    if (db == null) return 1;
    
    final result = await db.rawQuery(
      'SELECT MAX(groupId) as maxId FROM book_groups WHERE groupId > 0',
    );
    
    final maxId = result.first['maxId'] as int?;
    return (maxId ?? 0) + 1;
  }

  /// 初始化默认分组
  Future<void> initDefaultGroups() async {
    final db = await _db.database;
    if (db == null) return;
    
    try {
      // 先检查表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='book_groups'"
      );
      
      if (tables.isEmpty) {
        // 表不存在，创建表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS book_groups (
            groupId INTEGER PRIMARY KEY,
            groupName TEXT NOT NULL,
            cover TEXT,
            "order" INTEGER DEFAULT 0,
            enableRefresh INTEGER DEFAULT 1,
            show INTEGER DEFAULT 1,
            bookSort INTEGER DEFAULT -1
          )
        ''');
        
        // 创建索引
        await db.execute('CREATE INDEX IF NOT EXISTS idx_book_groups_order ON book_groups("order")');
      }
      
      // 检查是否已有分组
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM book_groups'),
      ) ?? 0;
      
      if (count > 0) return; // 已有分组，不初始化
      
      // 创建默认分组
      final defaultGroups = [
        BookGroup(
          groupId: BookGroup.idAll,
          groupName: '全部书籍',
          order: 0,
          enableRefresh: true,
          show: true,
          bookSort: -1,
        ),
        BookGroup(
          groupId: BookGroup.idLocal,
          groupName: '本地书籍',
          order: 1,
          enableRefresh: true,
          show: true,
          bookSort: -1,
        ),
        BookGroup(
          groupId: BookGroup.idNetNone,
          groupName: '未分组',
          order: 2,
          enableRefresh: true,
          show: true,
          bookSort: -1,
        ),
      ];
      
      for (final group in defaultGroups) {
        await createGroup(group);
      }
    } catch (e) {
      // 如果出错，尝试重新创建表
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS book_groups (
            groupId INTEGER PRIMARY KEY,
            groupName TEXT NOT NULL,
            cover TEXT,
            "order" INTEGER DEFAULT 0,
            enableRefresh INTEGER DEFAULT 1,
            show INTEGER DEFAULT 1,
            bookSort INTEGER DEFAULT -1
          )
        ''');
        
        await db.execute('CREATE INDEX IF NOT EXISTS idx_book_groups_order ON book_groups("order")');
        
        // 再次尝试初始化默认分组
        final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM book_groups'),
        ) ?? 0;
        
        if (count == 0) {
          final defaultGroups = [
            BookGroup(
              groupId: BookGroup.idAll,
              groupName: '全部书籍',
              order: 0,
              enableRefresh: true,
              show: true,
              bookSort: -1,
            ),
            BookGroup(
              groupId: BookGroup.idLocal,
              groupName: '本地书籍',
              order: 1,
              enableRefresh: true,
              show: true,
              bookSort: -1,
            ),
            BookGroup(
              groupId: BookGroup.idNetNone,
              groupName: '未分组',
              order: 2,
              enableRefresh: true,
              show: true,
              bookSort: -1,
            ),
          ];
          
          for (final group in defaultGroups) {
            await createGroup(group);
          }
        }
      } catch (e2) {
        // 忽略错误，让数据库升级逻辑处理
      }
    }
  }

  /// BookGroup转数据库Map
  Map<String, dynamic> _groupToDbMap(BookGroup group) {
    return {
      'groupId': group.groupId,
      'groupName': group.groupName,
      'cover': group.cover,
      'order': group.order,
      'enableRefresh': group.enableRefresh ? 1 : 0,
      'show': group.show ? 1 : 0,
      'bookSort': group.bookSort,
    };
  }

  /// 数据库Map转BookGroup
  BookGroup _groupFromDbMap(Map<String, dynamic> map) {
    return BookGroup(
      groupId: map['groupId'] as int,
      groupName: map['groupName'] as String,
      cover: map['cover'] as String?,
      order: map['order'] as int? ?? 0,
      enableRefresh: map['enableRefresh'] == 1,
      show: map['show'] == 1,
      bookSort: map['bookSort'] as int? ?? -1,
    );
  }
}

