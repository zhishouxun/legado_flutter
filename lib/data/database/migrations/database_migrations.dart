import 'package:sqflite/sqflite.dart';

/// 数据库迁移管理
/// 参考项目：io.legado.app.data.DatabaseMigrations
/// 
/// 将所有数据库迁移逻辑集中管理，提高代码可维护性
class DatabaseMigrations {
  DatabaseMigrations._();

  /// 获取所有迁移函数
  /// 返回一个 Map，key 是目标版本，value 是迁移函数
  static Map<int, Future<void> Function(Database)> get migrations => {
        2: _migration1To2,
        3: _migration2To3,
        4: _migration3To4,
        5: _migration4To5,
        6: _migration5To6,
        7: _migration6To7,
        8: _migration7To8,
        9: _migration8To9,
        10: _migration9To10,
        11: _migration10To11,
        12: _migration11To12,
        13: _migration12To13,
        14: _migration13To14,
        15: _migration14To15,
        16: _migration15To16,
        17: _migration16To17,
        18: _migration17To18,
      };

  /// 执行迁移
  /// [db] 数据库实例
  /// [oldVersion] 旧版本
  /// [newVersion] 新版本
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // 按版本顺序执行迁移，确保每个版本只执行一次
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      final migration = migrations[version];
      if (migration != null) {
        await migration(db);
      }
    }
  }

  // ========== 迁移函数 ==========

  /// 从版本1升级到版本2：添加 book_groups 表
  static Future<void> _migration1To2(Database db) async {
    // 检查 book_groups 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='book_groups'",
    );

    if (tables.isEmpty) {
      // 创建书籍分组表
      await db.execute('''
        CREATE TABLE book_groups (
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
      await db.execute('CREATE INDEX idx_book_groups_order ON book_groups("order")');

      // 初始化默认分组
      await db.insert('book_groups', {
        'groupId': -1,
        'groupName': '全部书籍',
        'order': 0,
        'enableRefresh': 1,
        'show': 1,
        'bookSort': -1,
      });
      await db.insert('book_groups', {
        'groupId': -2,
        'groupName': '本地书籍',
        'order': 1,
        'enableRefresh': 1,
        'show': 1,
        'bookSort': -1,
      });
      await db.insert('book_groups', {
        'groupId': -4,
        'groupName': '未分组',
        'order': 2,
        'enableRefresh': 1,
        'show': 1,
        'bookSort': -1,
      });
    }

    // 检查 books 表是否有 group 字段
    final booksColumns = await db.rawQuery("PRAGMA table_info(books)");
    final hasGroupColumn = booksColumns.any((col) => col['name'] == 'group');

    if (!hasGroupColumn) {
      await db.execute('ALTER TABLE books ADD COLUMN "group" INTEGER DEFAULT -1');
    }
  }

  /// 从版本2升级到版本3：添加 bookmarks 表
  static Future<void> _migration2To3(Database db) async {
    // 检查 bookmarks 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='bookmarks'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE bookmarks (
          time INTEGER PRIMARY KEY,
          bookName TEXT NOT NULL,
          bookAuthor TEXT NOT NULL,
          chapterIndex INTEGER NOT NULL DEFAULT 0,
          chapterPos INTEGER NOT NULL DEFAULT 0,
          chapterName TEXT NOT NULL,
          bookText TEXT NOT NULL,
          content TEXT NOT NULL
        )
      ''');

      // 创建书签索引
      await db.execute(
        'CREATE INDEX idx_bookmarks_book ON bookmarks(bookName, bookAuthor)',
      );
    }
  }

  /// 从版本3升级到版本4：添加 txtTocRules 表
  static Future<void> _migration3To4(Database db) async {
    // 检查 txtTocRules 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='txtTocRules'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE txtTocRules (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          rule TEXT NOT NULL,
          example TEXT,
          serialNumber INTEGER DEFAULT 0,
          enable INTEGER DEFAULT 1
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_txtTocRules_serialNumber ON txtTocRules(serialNumber)',
      );
    }
  }

  /// 从版本4升级到版本5：添加 dictRules 表
  static Future<void> _migration4To5(Database db) async {
    // 检查 dictRules 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='dictRules'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE dictRules (
          name TEXT PRIMARY KEY,
          urlRule TEXT NOT NULL,
          showRule TEXT NOT NULL,
          enabled INTEGER DEFAULT 1,
          sortNumber INTEGER DEFAULT 0
        )
      ''');

      await db.execute('CREATE INDEX idx_dictRules_sortNumber ON dictRules(sortNumber)');
    }
  }

  /// 从版本5升级到版本6：添加 replaceRules 表
  static Future<void> _migration5To6(Database db) async {
    // 检查 replaceRules 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='replaceRules'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE replaceRules (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          pattern TEXT NOT NULL,
          replacement TEXT NOT NULL,
          enabled INTEGER DEFAULT 1,
          sortNumber INTEGER DEFAULT 0,
          "group" TEXT,
          scope TEXT,
          scopeTitle INTEGER DEFAULT 0,
          scopeContent INTEGER DEFAULT 1,
          excludeScope TEXT,
          isRegex INTEGER DEFAULT 1,
          timeoutMillisecond INTEGER DEFAULT 3000
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_replaceRules_sortNumber ON replaceRules(sortNumber)');
      await db.execute('CREATE INDEX idx_replaceRules_group ON replaceRules("group")');
      await db.execute('CREATE INDEX idx_replaceRules_id ON replaceRules(id)');
    } else {
      // 检查并添加新字段（用于从旧版本升级）
      final columns = await db.rawQuery("PRAGMA table_info(replaceRules)");
      final columnNames = columns.map((col) => col['name'] as String).toSet();

      if (!columnNames.contains('id')) {
        // 如果表使用name作为主键，需要迁移数据
        await db.execute('ALTER TABLE replaceRules ADD COLUMN id INTEGER');
        // 为现有记录生成ID
        await db.execute('''
          UPDATE replaceRules 
          SET id = (SELECT ROWID FROM replaceRules AS r2 WHERE r2.name = replaceRules.name)
          WHERE id IS NULL
        ''');
      }
      if (!columnNames.contains('scope')) {
        await db.execute('ALTER TABLE replaceRules ADD COLUMN scope TEXT');
      }
      if (!columnNames.contains('scopeTitle')) {
        await db.execute('ALTER TABLE replaceRules ADD COLUMN scopeTitle INTEGER DEFAULT 0');
      }
      if (!columnNames.contains('scopeContent')) {
        await db.execute('ALTER TABLE replaceRules ADD COLUMN scopeContent INTEGER DEFAULT 1');
      }
      if (!columnNames.contains('excludeScope')) {
        await db.execute('ALTER TABLE replaceRules ADD COLUMN excludeScope TEXT');
      }
      if (!columnNames.contains('isRegex')) {
        await db.execute('ALTER TABLE replaceRules ADD COLUMN isRegex INTEGER DEFAULT 1');
      }
      if (!columnNames.contains('timeoutMillisecond')) {
        await db.execute(
          'ALTER TABLE replaceRules ADD COLUMN timeoutMillisecond INTEGER DEFAULT 3000',
        );
      }
    }
  }

  /// 从版本6升级到版本7：添加 RSS 表
  static Future<void> _migration6To7(Database db) async {
    // 检查 rssSources 表是否存在
    final rssSourcesTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='rssSources'",
    );

    if (rssSourcesTables.isEmpty) {
      // 创建RSS源表
      await db.execute('''
        CREATE TABLE rssSources (
          sourceUrl TEXT PRIMARY KEY,
          sourceName TEXT NOT NULL,
          sourceIcon TEXT,
          sourceGroup TEXT,
          sourceComment TEXT,
          enabled INTEGER DEFAULT 1,
          variableComment TEXT,
          jsLib TEXT,
          enabledCookieJar INTEGER DEFAULT 1,
          concurrentRate TEXT,
          header TEXT,
          loginUrl TEXT,
          loginUi TEXT,
          loginCheckJs TEXT,
          coverDecodeJs TEXT,
          sortUrl TEXT,
          singleUrl INTEGER DEFAULT 0,
          articleStyle INTEGER DEFAULT 0,
          ruleArticles TEXT,
          ruleNextPage TEXT,
          ruleTitle TEXT,
          rulePubDate TEXT,
          ruleDescription TEXT,
          ruleImage TEXT,
          ruleLink TEXT,
          ruleContent TEXT,
          contentWhitelist TEXT,
          contentBlacklist TEXT,
          shouldOverrideUrlLoading TEXT,
          style TEXT,
          enableJs INTEGER DEFAULT 1,
          loadWithBaseUrl INTEGER DEFAULT 1,
          injectJs TEXT,
          lastUpdateTime INTEGER DEFAULT 0,
          customOrder INTEGER DEFAULT 0
        )
      ''');

      // 创建RSS源索引
      await db.execute('CREATE INDEX idx_rssSources_sourceUrl ON rssSources(sourceUrl)');
      await db.execute('CREATE INDEX idx_rssSources_enabled ON rssSources(enabled)');
      await db.execute('CREATE INDEX idx_rssSources_customOrder ON rssSources(customOrder)');
    }

    // 检查 rssArticles 表是否存在
    final rssArticlesTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='rssArticles'",
    );

    if (rssArticlesTables.isEmpty) {
      // 创建RSS文章表
      await db.execute('''
        CREATE TABLE rssArticles (
          origin TEXT NOT NULL,
          link TEXT NOT NULL,
          sort TEXT DEFAULT '',
          title TEXT NOT NULL,
          "order" INTEGER DEFAULT 0,
          pubDate TEXT,
          description TEXT,
          content TEXT,
          image TEXT,
          "group" TEXT DEFAULT '默认分组',
          read INTEGER DEFAULT 0,
          variable TEXT,
          PRIMARY KEY (origin, link)
        )
      ''');

      // 创建RSS文章索引
      await db.execute('CREATE INDEX idx_rssArticles_origin ON rssArticles(origin)');
      await db.execute('CREATE INDEX idx_rssArticles_group ON rssArticles("group")');
      await db.execute('CREATE INDEX idx_rssArticles_read ON rssArticles(read)');
      await db.execute('CREATE INDEX idx_rssArticles_order ON rssArticles("order")');
    }
  }

  /// 从版本7升级到版本8：添加 readRecord 表
  static Future<void> _migration7To8(Database db) async {
    // 检查 readRecord 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='readRecord'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE readRecord (
          bookName TEXT NOT NULL,
          author TEXT NOT NULL,
          deviceId TEXT NOT NULL,
          readTime INTEGER DEFAULT 0,
          lastRead INTEGER DEFAULT 0,
          PRIMARY KEY (bookName, author, deviceId)
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_readRecord_deviceId ON readRecord(deviceId)');
      await db.execute('CREATE INDEX idx_readRecord_bookName ON readRecord(bookName, author)');
    }
  }

  /// 从版本8升级到版本9：添加 cookies 表
  static Future<void> _migration8To9(Database db) async {
    // 检查 cookies 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='cookies'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE cookies (
          domain TEXT NOT NULL,
          name TEXT NOT NULL,
          value TEXT,
          path TEXT,
          expires INTEGER,
          secure INTEGER DEFAULT 0,
          httpOnly INTEGER DEFAULT 0,
          PRIMARY KEY (domain, name)
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_cookies_domain ON cookies(domain)');
    }
  }

  /// 从版本9升级到版本10：添加 searchBooks 和 searchKeywords 表
  static Future<void> _migration9To10(Database db) async {
    // 检查 searchBooks 表是否存在
    final searchBooksTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='searchBooks'",
    );

    if (searchBooksTables.isEmpty) {
      await db.execute('''
        CREATE TABLE searchBooks (
          name TEXT NOT NULL,
          author TEXT NOT NULL,
          bookUrl TEXT NOT NULL,
          origin TEXT NOT NULL,
          originName TEXT NOT NULL,
          kind TEXT,
          wordCount TEXT,
          lastChapter TEXT,
          intro TEXT,
          coverUrl TEXT,
          variable TEXT,
          time INTEGER DEFAULT 0,
          PRIMARY KEY (bookUrl, origin)
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_searchBooks_time ON searchBooks(time)');
      await db.execute('CREATE INDEX idx_searchBooks_origin ON searchBooks(origin)');
    }

    // 检查 searchKeywords 表是否存在
    final searchKeywordsTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='searchKeywords'",
    );

    if (searchKeywordsTables.isEmpty) {
      await db.execute('''
        CREATE TABLE searchKeywords (
          keyword TEXT PRIMARY KEY,
          time INTEGER DEFAULT 0
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_searchKeywords_time ON searchKeywords(time)');
    }
  }

  /// 从版本10升级到版本11：添加 httpTTS 表
  static Future<void> _migration10To11(Database db) async {
    // 检查 httpTTS 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='httpTTS'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE httpTTS (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          enabled INTEGER DEFAULT 1,
          sortNumber INTEGER DEFAULT 0
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_httpTTS_sortNumber ON httpTTS(sortNumber)');
    }
  }

  /// 从版本11升级到版本12：添加 ruleSub 表
  static Future<void> _migration11To12(Database db) async {
    // 检查 ruleSub 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='ruleSub'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE ruleSub (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          type INTEGER DEFAULT 0,
          enabled INTEGER DEFAULT 1,
          customOrder INTEGER DEFAULT 0
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_ruleSub_customOrder ON ruleSub(customOrder)');
    }
  }

  /// 从版本12升级到版本13：添加 keyboardAssists 表
  static Future<void> _migration12To13(Database db) async {
    // 检查 keyboardAssists 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='keyboardAssists'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE keyboardAssists (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          keyCode INTEGER NOT NULL,
          keyName TEXT,
          enabled INTEGER DEFAULT 1,
          customOrder INTEGER DEFAULT 0
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_keyboardAssists_customOrder ON keyboardAssists(customOrder)');
    }
  }

  /// 从版本13升级到版本14：添加 servers 表
  static Future<void> _migration13To14(Database db) async {
    // 检查 servers 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='servers'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE servers (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          enabled INTEGER DEFAULT 1,
          sortNumber INTEGER DEFAULT 0
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_servers_sortNumber ON servers(sortNumber)');
    }
  }

  /// 从版本14升级到版本15：添加 rssStars 表
  static Future<void> _migration14To15(Database db) async {
    // 检查 rssStars 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='rssStars'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE rssStars (
          origin TEXT NOT NULL,
          link TEXT NOT NULL,
          title TEXT NOT NULL,
          pubDate TEXT,
          description TEXT,
          content TEXT,
          image TEXT,
          time INTEGER DEFAULT 0,
          PRIMARY KEY (origin, link)
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_rssStars_time ON rssStars(time)');
    }
  }

  /// 从版本15升级到版本16：添加 rssReadRecord 表
  static Future<void> _migration15To16(Database db) async {
    // 检查 rssReadRecord 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='rssReadRecord'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE rssReadRecord (
          origin TEXT NOT NULL,
          link TEXT NOT NULL,
          readTime INTEGER DEFAULT 0,
          PRIMARY KEY (origin, link)
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_rssReadRecord_origin ON rssReadRecord(origin)');
    }
  }

  /// 从版本16升级到版本17：添加 caches 表
  static Future<void> _migration16To17(Database db) async {
    // 检查 caches 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='caches'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE caches (
          key TEXT PRIMARY KEY,
          value TEXT,
          expireTime INTEGER DEFAULT 0
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_caches_expireTime ON caches(expireTime)');
    }
  }

  /// 从版本17升级到版本18：添加 book_chapter_review 表
  static Future<void> _migration17To18(Database db) async {
    // 检查 book_chapter_review 表是否存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='book_chapter_review'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE book_chapter_review (
          bookId INTEGER NOT NULL,
          chapterId INTEGER NOT NULL,
          summaryUrl TEXT NOT NULL,
          PRIMARY KEY (bookId, chapterId)
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX idx_book_chapter_review_bookId ON book_chapter_review(bookId)');
    }
  }
}

