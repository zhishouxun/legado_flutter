import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'migrations/database_migrations.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database?> get database async {
    // Web平台不支持sqflite
    if (kIsWeb) {
      return null;
    }

    if (_database != null) {
      // 直接返回现有数据库连接，避免重复版本检查
      return _database;
    }

    try {
      _database = await _initDB('legado.db');
      return _database;
    } catch (e) {
      return null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('Web平台不支持SQLite');
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 19, // 升级版本以支持章节内容分文件存储
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 创建书籍表
    await db.execute('''
      CREATE TABLE books (
        bookUrl TEXT PRIMARY KEY,
        tocUrl TEXT,
        origin TEXT,
        originName TEXT,
        name TEXT,
        author TEXT,
        kind TEXT,
        customTag TEXT,
        coverUrl TEXT,
        customCoverUrl TEXT,
        intro TEXT,
        customIntro TEXT,
        charset TEXT,
        type INTEGER,
        "group" INTEGER,
        latestChapterTitle TEXT,
        latestChapterTime INTEGER,
        lastCheckTime INTEGER,
        lastCheckCount INTEGER,
        totalChapterNum INTEGER,
        durChapterTitle TEXT,
        durChapterIndex INTEGER,
        durChapterPos INTEGER,
        durChapterTime INTEGER,
        wordCount TEXT,
        canUpdate INTEGER,
        "order" INTEGER,
        originOrder INTEGER,
        variable TEXT,
        readConfig TEXT,
        syncTime INTEGER
      )
    ''');

    // 创建章节表
    await db.execute('''
      CREATE TABLE chapters (
        url TEXT,
        bookUrl TEXT,
        title TEXT,
        isVolume INTEGER,
        baseUrl TEXT,
        "index" INTEGER,
        isVip INTEGER,
        isPay INTEGER,
        resourceUrl TEXT,
        tag TEXT,
        wordCount TEXT,
        start INTEGER,
        "end" INTEGER,
        startFragmentId TEXT,
        endFragmentId TEXT,
        variable TEXT,
        localPath TEXT,
        PRIMARY KEY (url, bookUrl),
        FOREIGN KEY (bookUrl) REFERENCES books(bookUrl) ON DELETE CASCADE
      )
    ''');

    // 创建书源表
    await db.execute('''
      CREATE TABLE book_sources (
        bookSourceUrl TEXT PRIMARY KEY,
        bookSourceName TEXT,
        bookSourceGroup TEXT,
        bookSourceType INTEGER,
        bookUrlPattern TEXT,
        customOrder INTEGER,
        enabled INTEGER,
        enabledExplore INTEGER,
        jsLib TEXT,
        enabledCookieJar INTEGER,
        concurrentRate TEXT,
        header TEXT,
        loginUrl TEXT,
        loginUi TEXT,
        loginCheckJs TEXT,
        coverDecodeJs TEXT,
        bookSourceComment TEXT,
        variableComment TEXT,
        lastUpdateTime INTEGER,
        respondTime INTEGER,
        weight INTEGER,
        exploreUrl TEXT,
        exploreScreen TEXT,
        ruleExplore TEXT,
        searchUrl TEXT,
        ruleSearch TEXT,
        ruleBookInfo TEXT,
        ruleToc TEXT,
        ruleContent TEXT
      )
    ''');

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
    await db
        .execute('CREATE INDEX idx_books_name_author ON books(name, author)');
    await db.execute('CREATE INDEX idx_chapters_bookUrl ON chapters(bookUrl)');
    await db.execute(
        'CREATE INDEX idx_chapters_bookUrl_index ON chapters(bookUrl, "index")');
    await db
        .execute('CREATE INDEX idx_book_groups_order ON book_groups("order")');

    // 创建TXT目录规则表
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

    // 创建索引
    await db.execute(
        'CREATE INDEX idx_txtTocRules_serialNumber ON txtTocRules(serialNumber)');

    // 创建字典规则表
    await db.execute('''
      CREATE TABLE dictRules (
        name TEXT PRIMARY KEY,
        urlRule TEXT NOT NULL,
        showRule TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        sortNumber INTEGER DEFAULT 0
      )
    ''');

    // 创建索引
    await db.execute(
        'CREATE INDEX idx_dictRules_sortNumber ON dictRules(sortNumber)');

    // 创建替换规则表
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
    await db.execute(
        'CREATE INDEX idx_replaceRules_sortNumber ON replaceRules(sortNumber)');
    await db.execute(
        'CREATE INDEX idx_replaceRules_group ON replaceRules("group")');
    await db.execute('CREATE INDEX idx_replaceRules_id ON replaceRules(id)');

    // 创建书签表
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
        'CREATE INDEX idx_bookmarks_book ON bookmarks(bookName, bookAuthor)');

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
    await db.execute(
        'CREATE INDEX idx_rssSources_sourceUrl ON rssSources(sourceUrl)');
    await db
        .execute('CREATE INDEX idx_rssSources_enabled ON rssSources(enabled)');
    await db.execute(
        'CREATE INDEX idx_rssSources_customOrder ON rssSources(customOrder)');

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
    await db
        .execute('CREATE INDEX idx_rssArticles_origin ON rssArticles(origin)');
    await db
        .execute('CREATE INDEX idx_rssArticles_group ON rssArticles("group")');
    await db.execute('CREATE INDEX idx_rssArticles_read ON rssArticles(read)');
    await db
        .execute('CREATE INDEX idx_rssArticles_order ON rssArticles("order")');

    // 创建RSS收藏表
    await db.execute('''
      CREATE TABLE rssStars (
        origin TEXT NOT NULL,
        link TEXT NOT NULL,
        sort TEXT DEFAULT '',
        title TEXT NOT NULL,
        starTime INTEGER DEFAULT 0,
        pubDate TEXT,
        description TEXT,
        content TEXT,
        image TEXT,
        "group" TEXT DEFAULT '默认分组',
        variable TEXT,
        PRIMARY KEY (origin, link)
      )
    ''');

    // 创建RSS收藏索引
    await db.execute('CREATE INDEX idx_rssStars_origin ON rssStars(origin)');
    await db.execute('CREATE INDEX idx_rssStars_group ON rssStars("group")');
    await db
        .execute('CREATE INDEX idx_rssStars_starTime ON rssStars(starTime)');

    // 创建缓存表
    await db.execute('''
      CREATE TABLE caches (
        "key" TEXT PRIMARY KEY,
        value TEXT,
        deadline INTEGER DEFAULT 0
      )
    ''');

    // 创建缓存索引
    await db.execute('CREATE UNIQUE INDEX idx_caches_key ON caches("key")');

    // 创建阅读记录表
    await db.execute('''
      CREATE TABLE readRecord (
        deviceId TEXT NOT NULL,
        bookName TEXT NOT NULL,
        readTime INTEGER DEFAULT 0,
        lastRead INTEGER DEFAULT 0,
        PRIMARY KEY (deviceId, bookName)
      )
    ''');

    // 创建阅读记录索引
    await db.execute(
        'CREATE INDEX idx_readRecord_bookName ON readRecord(bookName)');
    await db.execute(
        'CREATE INDEX idx_readRecord_lastRead ON readRecord(lastRead)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 使用独立的迁移文件系统
    await DatabaseMigrations.migrate(db, oldVersion, newVersion);
  }

  // 保留旧的迁移逻辑作为备份（已迁移到 DatabaseMigrations）
  @Deprecated('使用 DatabaseMigrations.migrate 代替')
  Future<void> _onUpgradeOld(
      Database db, int oldVersion, int newVersion) async {
    // 按版本顺序执行迁移，确保每个版本只执行一次

    // 从版本1升级到版本2：添加 book_groups 表
    if (oldVersion < 2) {
      // 检查 book_groups 表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='book_groups'");

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
        await db.execute(
            'CREATE INDEX idx_book_groups_order ON book_groups("order")');

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
        // 添加 group 字段到 books 表
        await db
            .execute('ALTER TABLE books ADD COLUMN "group" INTEGER DEFAULT -1');
      }
    }

    // 从版本4升级到版本5：添加 dictRules 表
    if (oldVersion < 5) {
      // 检查 dictRules 表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='dictRules'");

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

        await db.execute(
            'CREATE INDEX idx_dictRules_sortNumber ON dictRules(sortNumber)');
      }
    }

    // 从版本5升级到版本6：添加 replaceRules 表
    if (oldVersion < 6) {
      // 检查 replaceRules 表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='replaceRules'");

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

        await db.execute(
            'CREATE INDEX idx_replaceRules_sortNumber ON replaceRules(sortNumber)');
        await db.execute(
            'CREATE INDEX idx_replaceRules_group ON replaceRules("group")');
        await db
            .execute('CREATE INDEX idx_replaceRules_id ON replaceRules(id)');
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
          await db.execute(
              'ALTER TABLE replaceRules ADD COLUMN scopeTitle INTEGER DEFAULT 0');
        }
        if (!columnNames.contains('scopeContent')) {
          await db.execute(
              'ALTER TABLE replaceRules ADD COLUMN scopeContent INTEGER DEFAULT 1');
        }
        if (!columnNames.contains('excludeScope')) {
          await db
              .execute('ALTER TABLE replaceRules ADD COLUMN excludeScope TEXT');
        }
        if (!columnNames.contains('isRegex')) {
          await db.execute(
              'ALTER TABLE replaceRules ADD COLUMN isRegex INTEGER DEFAULT 1');
        }
        if (!columnNames.contains('timeoutMillisecond')) {
          await db.execute(
              'ALTER TABLE replaceRules ADD COLUMN timeoutMillisecond INTEGER DEFAULT 3000');
        }
      }
    }

    // 从版本6升级到版本7：添加 RSS 表
    if (oldVersion < 7) {
      // 检查 rssSources 表是否存在
      final rssSourcesTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='rssSources'");

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
        await db.execute(
            'CREATE INDEX idx_rssSources_sourceUrl ON rssSources(sourceUrl)');
        await db.execute(
            'CREATE INDEX idx_rssSources_enabled ON rssSources(enabled)');
        await db.execute(
            'CREATE INDEX idx_rssSources_customOrder ON rssSources(customOrder)');
      }

      // 检查 rssArticles 表是否存在
      final rssArticlesTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='rssArticles'");

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
        await db.execute(
            'CREATE INDEX idx_rssArticles_origin ON rssArticles(origin)');
        await db.execute(
            'CREATE INDEX idx_rssArticles_group ON rssArticles("group")');
        await db
            .execute('CREATE INDEX idx_rssArticles_read ON rssArticles(read)');
        await db.execute(
            'CREATE INDEX idx_rssArticles_order ON rssArticles("order")');
      }
    }

    // 从版本3升级到版本4：添加 txtTocRules 表
    if (oldVersion < 4) {
      // 检查 txtTocRules 表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='txtTocRules'");

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
            'CREATE INDEX idx_txtTocRules_serialNumber ON txtTocRules(serialNumber)');
      }
    }

    // 从版本2升级到版本3：添加 bookmarks 表
    if (oldVersion < 3) {
      // 检查 bookmarks 表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='bookmarks'");

      if (tables.isEmpty) {
        // 创建书签表
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
            'CREATE INDEX idx_bookmarks_book ON bookmarks(bookName, bookAuthor)');
      }
    }

    // 从版本7升级到版本8：添加 caches 表
    if (oldVersion < 8) {
      // 检查 caches 表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='caches'");

      if (tables.isEmpty) {
        // 创建缓存表
        await db.execute('''
          CREATE TABLE caches (
            "key" TEXT PRIMARY KEY,
            value TEXT,
            deadline INTEGER DEFAULT 0
          )
        ''');

        // 创建缓存索引
        await db.execute('CREATE UNIQUE INDEX idx_caches_key ON caches("key")');
      }
    }

    // 从版本8升级到版本9：添加 readRecord 表
    if (oldVersion < 9) {
      // 检查 readRecord 表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='readRecord'");

      if (tables.isEmpty) {
        // 创建阅读记录表
        await db.execute('''
          CREATE TABLE readRecord (
            deviceId TEXT NOT NULL,
            bookName TEXT NOT NULL,
            readTime INTEGER DEFAULT 0,
            lastRead INTEGER DEFAULT 0,
            PRIMARY KEY (deviceId, bookName)
          )
        ''');

        // 创建阅读记录索引
        await db.execute(
            'CREATE INDEX idx_readRecord_bookName ON readRecord(bookName)');
        await db.execute(
            'CREATE INDEX idx_readRecord_lastRead ON readRecord(lastRead)');
      }
    }

    // 从版本9升级到版本10：添加 rssStars 表
    if (oldVersion < 10) {
      // 检查 rssStars 表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='rssStars'");

      if (tables.isEmpty) {
        // 创建RSS收藏表
        await db.execute('''
          CREATE TABLE rssStars (
            origin TEXT NOT NULL,
            link TEXT NOT NULL,
            sort TEXT DEFAULT '',
            title TEXT NOT NULL,
            starTime INTEGER DEFAULT 0,
            pubDate TEXT,
            description TEXT,
            content TEXT,
            image TEXT,
            "group" TEXT DEFAULT '默认分组',
            variable TEXT,
            PRIMARY KEY (origin, link)
          )
        ''');

        // 创建RSS收藏索引
        await db
            .execute('CREATE INDEX idx_rssStars_origin ON rssStars(origin)');
        await db
            .execute('CREATE INDEX idx_rssStars_group ON rssStars("group")');
        await db.execute(
            'CREATE INDEX idx_rssStars_starTime ON rssStars(starTime)');
      }
    }

    // 从版本10升级到版本11：添加 cookies 表
    if (oldVersion < 11) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cookies'");

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE cookies (
            url TEXT PRIMARY KEY,
            cookie TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE UNIQUE INDEX idx_cookies_url ON cookies(url)');
      }
    }

    // 从版本11升级到版本12：添加 search_keywords 表
    if (oldVersion < 12) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='search_keywords'");

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE search_keywords (
            word TEXT PRIMARY KEY,
            usage INTEGER DEFAULT 1,
            lastUseTime INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE UNIQUE INDEX idx_search_keywords_word ON search_keywords(word)');
      }
    }

    // 从版本12升级到版本13：添加 searchBooks 表
    if (oldVersion < 13) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='searchBooks'");

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE searchBooks (
            bookUrl TEXT PRIMARY KEY,
            origin TEXT NOT NULL,
            originName TEXT,
            type INTEGER DEFAULT 0,
            name TEXT,
            author TEXT,
            kind TEXT,
            coverUrl TEXT,
            intro TEXT,
            wordCount TEXT,
            latestChapterTitle TEXT,
            tocUrl TEXT,
            time INTEGER DEFAULT 0,
            variable TEXT,
            originOrder INTEGER DEFAULT 0,
            chapterWordCountText TEXT,
            chapterWordCount INTEGER DEFAULT -1,
            respondTime INTEGER DEFAULT -1
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_searchBooks_origin ON searchBooks(origin)');
      }
    }

    // 从版本13升级到版本14：添加 rssReadRecords 表
    if (oldVersion < 14) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='rssReadRecords'");

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE rssReadRecords (
            record TEXT PRIMARY KEY,
            title TEXT,
            readTime INTEGER,
            read INTEGER DEFAULT 1
          )
        ''');
      }
    }

    // 从版本14升级到版本15：添加 servers 表
    if (oldVersion < 15) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='servers'");

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE servers (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            type INTEGER DEFAULT 0,
            config TEXT,
            sortNumber INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_servers_sortNumber ON servers(sortNumber)');
      }
    }

    // 从版本15升级到版本16：添加 httpTTS 表
    if (oldVersion < 16) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='httpTTS'");

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE httpTTS (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            url TEXT NOT NULL,
            contentType TEXT,
            concurrentRate TEXT DEFAULT '0',
            loginUrl TEXT,
            loginUi TEXT,
            header TEXT,
            jsLib TEXT,
            enabledCookieJar INTEGER DEFAULT 0,
            loginCheckJs TEXT,
            lastUpdateTime INTEGER DEFAULT 0
          )
        ''');
      }
    }

    // 从版本16升级到版本17：添加 ruleSubs 表
    if (oldVersion < 17) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='ruleSubs'");

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE ruleSubs (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            url TEXT NOT NULL,
            type INTEGER DEFAULT 0,
            customOrder INTEGER DEFAULT 0,
            autoUpdate INTEGER DEFAULT 0,
            "update" INTEGER DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_ruleSubs_type ON ruleSubs(type)');
        await db.execute(
            'CREATE INDEX idx_ruleSubs_customOrder ON ruleSubs(customOrder)');
      }
    }

    // 从版本17升级到版本18：添加 keyboardAssists 表
    if (oldVersion < 18) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='keyboardAssists'");

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE keyboardAssists (
            type INTEGER NOT NULL,
            "key" TEXT NOT NULL,
            value TEXT DEFAULT '',
            serialNo INTEGER DEFAULT 0,
            PRIMARY KEY (type, "key")
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_keyboardAssists_serialNo ON keyboardAssists(serialNo)');

        // 导入默认键盘辅助（参考项目：在创建表时自动导入）
        // 注意：这里不能直接调用服务，因为会导致循环依赖
        // 实际导入会在应用启动时通过 DefaultData.upVersion() 完成
      }
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    if (db != null) {
      await db.close();
    }
  }
}
