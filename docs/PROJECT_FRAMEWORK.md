# Legado Flutter 项目框架文档

## 目录
- [项目概述](#项目概述)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [核心模块](#核心模块)
- [主要功能](#主要功能)
- [数据流](#数据流)
- [架构设计](#架构设计)
- [开发规范](#开发规范)

---

## 项目概述

### 项目简介
Legado Flutter 是开源阅读（Legado）的 Flutter 跨平台实现版本，一个免费开源的小说阅读器应用。

**主要特性**：
- 📚 **多源阅读**：支持自定义书源规则，可从多个网站获取小说内容
- 📖 **本地文件**：支持 TXT、EPUB 等本地文件格式
- 🔍 **强大搜索**：支持多书源搜索，快速找到想看的书籍
- 📱 **跨平台**：支持 Android、iOS、macOS 等多个平台
- 🎨 **个性化**：丰富的阅读设置、主题切换、字体调节
- 📡 **RSS订阅**：支持 RSS 新闻订阅功能
- 🔊 **朗读功能**：内置 TTS 朗读，支持 HTTP TTS
- ☁️ **云端同步**：支持 WebDAV 备份和同步
- 🌐 **Web服务**：内置 Web 服务，支持浏览器访问和文件上传

### 项目目标
1. **跨平台支持**：基于 Flutter 实现一套代码多平台运行
2. **功能完整性**：尽可能完整实现参考项目的核心功能
3. **用户体验**：提供流畅的阅读体验和丰富的自定义选项
4. **可扩展性**：支持自定义书源规则、替换规则等
5. **开源生态**：与参考项目保持规则兼容，便于书源共享

### 参考项目
- **参考项目**：Legado (开源阅读) - Android 版本
- **项目地址**：https://github.com/gedoor/legado
- **项目本地路径**：/Users/zhangmingxun/Downloads/legado-master
- **项目语言**：Kotlin/Java
- **兼容性**：本项目与参考项目的书源规则格式兼容，可以直接导入使用

**与参考项目的差异**：
- 使用 Dart/Flutter 实现，而非 Kotlin/Java
- HTML 解析使用 `html` + `xpath_selector` 包，而非 JSoup + JXPath
- JavaScript 引擎使用 `flutter_js` (QuickJS)，而非 Rhino
- 跨平台支持，而参考项目仅支持 Android

---

## 技术栈

### 框架
- **Flutter**: 3.0.0+ (跨平台 UI 框架)
- **Dart**: 3.0.0+ (编程语言)

### 状态管理
- **Riverpod**: ^3.0.3 (主要状态管理方案)
- **Provider**: ^6.1.1 (兼容性支持)

### 数据库
- **sqflite**: ^2.3.0 (SQLite 数据库)
- **path**: ^1.8.3 (路径处理)
- **shared_preferences**: ^2.2.2 (键值对存储)
- **get_storage**: ^2.1.1 (本地存储)

### 网络请求
- **dio**: ^5.4.0 (HTTP 客户端，支持拦截器、Cookie管理等)
- **http**: ^1.1.2 (基础 HTTP 请求)
- **cookie_jar**: ^4.0.8 (Cookie 管理)
- **dio_cookie_manager**: ^3.0.1 (Dio Cookie 管理器)
- **webview_flutter**: ^4.4.2 (WebView 支持)

### 解析库
- **html**: ^0.15.4 (HTML 解析和 CSS 选择器)
- **xpath_selector**: ^3.0.2 (XPath 查询)
- **xpath_selector_html_parser**: ^3.0.1 (XPath HTML 解析器)
- **xml**: ^6.5.0 (XML 解析)
- **json_path**: ^0.9.0 (JSONPath 查询)
- **json_annotation**: ^4.8.1 (JSON 序列化注解)

### JavaScript 引擎
- **flutter_js**: ^0.8.5 (QuickJS 引擎，用于执行书源规则中的 JavaScript)

### 文件处理
- **file_picker**: ^10.3.8 (文件选择)
- **path_provider**: ^2.1.1 (路径获取)
- **open_filex**: ^4.3.3 (打开文件)
- **archive**: ^3.4.9 (压缩文件处理)

### 电子书支持
- **epubx**: ^4.0.0 (EPUB 格式支持)

### 音频播放
- **just_audio**: ^0.10.5 (音频播放)
- **audio_service**: ^0.18.11 (音频服务)
- **flutter_tts**: ^4.1.0 (TTS 朗读)

### UI 组件
- **cached_network_image**: ^3.3.1 (网络图片缓存)
- **flutter_svg**: ^2.0.9 (SVG 支持)
- **flutter_staggered_grid_view**: ^0.7.0 (瀑布流布局)
- **pull_to_refresh**: ^2.0.0 (下拉刷新)
- **flutter_html**: ^3.0.0-beta.2 (HTML 渲染)
- **flutter_markdown**: ^0.7.7+1 (Markdown 渲染)
- **flutter_colorpicker**: ^1.0.3 (颜色选择器)

### 其他工具
- **crypto**: ^3.0.3 (加密解密)
- **encrypt**: ^5.0.3 (加密工具)
- **pointycastle**: ^3.7.3 (非对称加密)
- **uuid**: ^4.2.1 (UUID 生成)
- **intl**: ^0.20.2 (国际化)
- **qr_flutter**: ^4.1.0 (二维码生成)
- **mobile_scanner**: ^7.1.4 (二维码扫描)
- **flutter_opencc_ffi_native**: ^0.0.3 (简繁转换)
- **charset_converter**: ^2.1.1 (字符编码转换)
- **screen_brightness**: ^0.2.2+1 (屏幕亮度控制)
- **wakelock_plus**: ^1.2.1 (屏幕常亮)
- **permission_handler**: ^12.0.1 (权限处理)

### Web 服务
- **shelf**: ^1.4.1 (Web 服务器框架)
- **shelf_router**: ^1.1.4 (路由管理)
- **shelf_web_socket**: ^3.0.0 (WebSocket 支持)

### 开发工具
- **build_runner**: ^2.4.7 (代码生成)
- **json_serializable**: ^6.7.1 (JSON 序列化生成)
- **freezed**: ^3.2.3 (不可变类生成)
- **flutter_lints**: ^6.0.0 (代码检查)

---

## 项目结构

### 目录树
```
legado_flutter/
├── lib/                    # 源代码目录
│   ├── main.dart          # 应用入口
│   ├── app.dart           # 应用主类
│   ├── config/            # 配置文件
│   ├── core/              # 核心模块
│   ├── data/              # 数据层
│   ├── providers/         # 状态管理
│   ├── services/          # 服务层
│   ├── ui/                # UI层
│   └── utils/             # 工具类
├── assets/                # 资源文件
├── android/               # Android平台代码
├── ios/                   # iOS平台代码
├── macos/                 # macOS平台代码
├── web/                   # Web平台代码
└── docs/                  # 文档目录
```

### 模块说明

#### lib/ - 源代码目录
- **main.dart**: 应用入口点，负责全局初始化（数据库、服务、错误处理等）
- **app.dart**: 应用主类（LegadoApp），管理应用生命周期、路由、主题等

#### config/ - 配置模块
- **app_config.dart**: 应用全局配置管理
- **theme_config.dart**: 主题配置管理

#### core/ - 核心模块
- **base/**: 基类定义（如 BaseService）
- **constants/**: 常量定义（应用常量、正则表达式、状态常量、偏好设置键）
- **exceptions/**: 异常类定义
- **extensions/**: 扩展方法

#### data/ - 数据层
- **database/**: 数据库定义和迁移
- **models/**: 数据模型（Book、BookSource、BookChapter 等）

#### providers/ - 状态管理
- 使用 Riverpod 进行状态管理
- **book_provider.dart**: 书籍相关状态
- **book_source_provider.dart**: 书源相关状态
- **main_page_index_provider.dart**: 主页面索引状态
- 其他状态提供者

#### services/ - 服务层
- **book/**: 书籍相关服务（本地书、网络书、EPUB、MOBI、UMD）
- **source/**: 书源相关服务（书源管理、书源调试、登录）
- **network/**: 网络服务（HTTP 请求、Cookie 管理）
- **reader/**: 阅读器服务（缓存、内容处理）
- **media/**: 媒体服务（TTS、音频播放、漫画）
- **receiver/**: 接收器服务（分享、文件接收、媒体按钮）
- **storage/**: 存储服务（备份、恢复、WebDAV）
- **web/**: Web 服务（HTTP 服务器、WebSocket）
- 其他服务

#### ui/ - UI 层
- **pages/**: 页面组件
  - **bookshelf/**: 书架相关页面
  - **reader/**: 阅读器页面
  - **book_source/**: 书源管理页面
  - **search/**: 搜索页面
  - **explore/**: 发现页面
  - **rss/**: RSS 订阅页面
  - **settings/**: 设置页面
  - 其他页面
- **widgets/**: 通用组件
- **dialogs/**: 对话框组件

#### utils/ - 工具类
- **parsers/**: 解析器（HTML、规则、正则）
- **js_engine.dart**: JavaScript 引擎封装
- **js_extensions.dart**: JavaScript 扩展（桥接函数）
- **app_log.dart**: 日志管理
- 其他工具类

#### assets/ - 资源文件
- **images/**: 图片资源
- **fonts/**: 字体文件
- **defaultData/**: 默认数据（书源、规则等）
- **bg/**: 背景图片
- **epub/**: EPUB 模板
- **web/**: Web 服务静态资源

#### 平台特定目录
- **android/**: Android 平台代码和配置
- **ios/**: iOS 平台代码和配置
- **macos/**: macOS 平台代码和配置
- **web/**: Web 平台代码和配置

---

## 核心模块

### 1. 应用入口 (main.dart)

**职责**：
- 应用启动时的全局初始化
- 服务初始化（数据库、网络、崩溃日志、音频播放等）
- 错误处理设置
- 平台特定初始化（Android 快捷方式、通知等）

**主要初始化流程**：
1. WidgetsFlutterBinding 初始化
2. 配置初始化（AppConfig、AppTheme）
3. 默认数据升级检查
4. 各服务初始化（网络服务、崩溃日志、音频播放等）
5. 全局错误处理器设置
6. 启动应用

**关键服务初始化**：
- `NetworkService`: 网络请求服务
- `CrashLogService`: 崩溃日志服务
- `AudioPlayService`: 音频播放服务
- `BookGroupService`: 书籍分组服务
- `SourceConfigService`: 书源配置服务
- `LocalConfigService`: 本地配置服务

### 2. 应用主类 (app.dart)

**职责**：
- 应用主题配置（明暗主题切换）
- 路由管理
- 国际化支持
- 应用生命周期管理
- 启动后初始化（隐私协议、版本更新、备份同步等）

**主要功能**：
- 主题切换（明暗模式、自定义主题）
- 待处理导航检查（pending_navigation）
- 隐私协议检查
- 版本更新检查
- 本地密码设置
- 崩溃日志通知
- 备份同步检查
- 自动更新书籍目录

### 3. 配置模块 (config/)

**app_config.dart**：
- 应用全局配置管理
- 偏好设置读写
- 配置项定义（自动刷新、自动备份等）

**theme_config.dart**：
- 主题配置管理
- 明暗主题切换
- 自定义主题支持
- 阅读主题配置

### 4. 核心模块 (core/)

**base/**：
- `BaseService`: 服务基类，提供统一的生命周期管理（init、dispose、execute）

**constants/**：
- `app_constants.dart`: 应用常量（超时时间、缓存大小等）
- `app_patterns.dart`: 正则表达式模式
- `app_status.dart`: 状态常量
- `prefer_key.dart`: 偏好设置键常量

**exceptions/**：
- `app_exceptions.dart`: 应用异常类（NetworkException、ParseException、ServiceException 等）
- `actively_cancel_exception.dart`: 主动取消异常

### 5. 数据层 (data/)

**database/**：
- `app_database.dart`: 数据库定义和初始化
- `migrations/`: 数据库迁移脚本

**models/**：
- 数据模型定义（33 个模型文件）
- 主要模型：
  - `book.dart`: 书籍模型
  - `book_source.dart`: 书源模型
  - `book_chapter.dart`: 章节模型
  - `book_source_rule.dart`: 书源规则模型
  - `replace_rule.dart`: 替换规则模型
  - `rss_source.dart`: RSS 源模型
  - `rss_article.dart`: RSS 文章模型
  - 其他模型...

### 6. 服务层 (services/)

**书籍服务 (book/)**：
- `book_service.dart`: 书籍服务主类
- `local_book_service.dart`: 本地书籍服务
- `remote_book_service.dart`: 网络书籍服务
- `epub_parser.dart`: EPUB 解析器
- `mobi/`: MOBI 格式支持
- `umd/`: UMD 格式支持

**书源服务 (source/)**：
- `book_source_service.dart`: 书源管理服务
- `book_source_debug_service.dart`: 书源调试服务
- `check_source_service.dart`: 书源检查服务
- `source_config_service.dart`: 书源配置服务
- `login_info_service.dart`: 登录信息服务

**网络服务 (network/)**：
- `network_service.dart`: 网络请求服务（HTTP 请求、Cookie 管理、编码检测）

**阅读器服务 (reader/)**：
- `cache_service.dart`: 缓存服务
- `content_processor.dart`: 内容处理服务（替换规则应用、简繁转换）

**媒体服务 (media/)**：
- `tts_service.dart`: TTS 朗读服务
- `audio_play_service.dart`: 音频播放服务
- `manga_service.dart`: 漫画服务

**其他服务**：
- `download_service.dart`: 下载服务
- `file_manage_service.dart`: 文件管理服务
- `server_service.dart`: Web 服务器服务
- `webdav_service.dart`: WebDAV 服务
- 等等...

### 7. UI层 (ui/)

**页面 (pages/)**：
- **bookshelf/**: 书架页面、书籍管理、分组管理
- **reader/**: 阅读器页面、章节列表、阅读设置
- **book_source/**: 书源管理、书源编辑、书源调试
- **search/**: 搜索页面、搜索历史
- **explore/**: 发现页面
- **rss/**: RSS 订阅页面、RSS 文章列表
- **settings/**: 设置页面、其他设置
- **theme/**: 主题设置、主题编辑
- **about/**: 关于页面、日志查看、崩溃日志
- 其他页面...

**组件 (widgets/)**：
- 通用 UI 组件

**对话框 (dialogs/)**：
- 添加到书架对话框
- 不支持文件对话框
- 其他对话框...

### 8. 工具类 (utils/)

**解析器 (parsers/)**：
- `rule_parser.dart`: 规则解析器（CSS、XPath、JSONPath、JavaScript）
- `html_parser.dart`: HTML 解析器封装
- `rule_analyzer.dart`: 规则分析器
- `elements_single.dart`: 元素索引选择器
- `analyze_by_regex.dart`: 正则表达式解析器

**JavaScript 相关**：
- `js_engine.dart`: JavaScript 引擎封装（QuickJS）
- `js_extensions.dart`: JavaScript 扩展（桥接 Dart 函数到 JavaScript）

**其他工具**：
- `app_log.dart`: 日志管理
- `crash_handler.dart`: 崩溃处理
- `encoding_detect.dart`: 编码检测
- `chinese_utils.dart`: 中文工具（简繁转换）
- `color_utils.dart`: 颜色工具
- `file_utils.dart`: 文件工具
- `network_utils.dart`: 网络工具
- `time_utils.dart`: 时间工具
- 等等...

---

## 主要功能

### 1. 书架管理

**功能描述**：
- 书籍展示：支持网格布局和列表布局
- 书籍管理：添加、删除、编辑、排序
- 分组管理：支持书籍分组、自定义分组
- 更新检查：自动检测书籍更新，显示更新数量
- 缓存管理：查看和管理书籍缓存

**相关页面**：
- `ui/pages/bookshelf/bookshelf_page.dart`: 书架主页面
- `ui/pages/bookshelf/book_manage_page.dart`: 书籍管理页面
- `ui/pages/bookshelf/group_manage_dialog.dart`: 分组管理对话框

**相关服务**：
- `services/book/book_service.dart`: 书籍服务
- `services/book_group_service.dart`: 书籍分组服务

### 2. 书源管理

**功能描述**：
- 书源导入：支持从 URL、文件、剪贴板导入书源
- 书源编辑：支持添加、编辑、删除书源
- 书源分组：支持书源分组管理
- 书源调试：支持在线调试书源规则
- 书源检查：支持检查书源是否可用

**相关页面**：
- `ui/pages/book_source/book_source_manage_page.dart`: 书源管理页面
- `ui/pages/book_source/book_source_edit_page.dart`: 书源编辑页面
- `ui/pages/book_source/book_source_debug_page.dart`: 书源调试页面
- `ui/pages/book_source/check_source_page.dart`: 书源检查页面

**相关服务**：
- `services/source/book_source_service.dart`: 书源服务
- `services/source/book_source_debug_service.dart`: 书源调试服务
- `services/source/check_source_service.dart`: 书源检查服务

### 3. 阅读器

**功能描述**：
- 阅读模式：支持普通阅读、漫画阅读、EPUB 阅读
- 阅读设置：字体、字号、行距、页边距、背景色、文字颜色
- 目录管理：章节列表、跳转、收藏
- 书签管理：添加、删除、查看书签
- 搜索功能：全文搜索、高亮显示
- 朗读功能：TTS 朗读、HTTP TTS 支持
- 自动翻页：支持自动滚动翻页

**相关页面**：
- `ui/pages/reader/reader_page.dart`: 普通阅读器页面
- `ui/pages/reader/manga_reader_page.dart`: 漫画阅读器页面
- `ui/pages/reader/chapter_list_page.dart`: 章节列表页面
- `ui/pages/reader/reader_settings_page.dart`: 阅读设置页面

**相关服务**：
- `services/reader/cache_service.dart`: 缓存服务
- `services/reader/content_processor.dart`: 内容处理服务
- `services/media/tts_service.dart`: TTS 朗读服务

### 4. 搜索功能

**功能描述**：
- 多源搜索：支持从多个书源搜索书籍
- 搜索历史：记录搜索关键词
- 搜索范围：支持选择搜索范围
- 搜索结果：显示书籍信息、作者、分类等

**相关页面**：
- `ui/pages/search/search_page.dart`: 搜索页面
- `ui/pages/search/search_history_widget.dart`: 搜索历史组件

**相关服务**：
- `services/search_book_service.dart`: 搜索服务
- `services/search_history_service.dart`: 搜索历史服务

### 5. RSS订阅

**功能描述**：
- RSS 源管理：添加、编辑、删除 RSS 源
- RSS 文章列表：显示 RSS 源的文章列表
- RSS 阅读记录：记录已读/未读状态
- RSS 收藏：收藏喜欢的文章

**相关页面**：
- `ui/pages/rss/`: RSS 相关页面
- `ui/pages/rss/rss_read_page.dart`: RSS 阅读页面

**相关服务**：
- `services/rss_service.dart`: RSS 服务
- `services/rss/rss_parser_service.dart`: RSS 解析服务
- `services/rss_read_record_service.dart`: RSS 阅读记录服务

### 6. 替换规则

**功能描述**：
- 替换规则管理：添加、编辑、删除替换规则
- 规则分组：支持规则分组管理
- 规则导入：支持从文件导入规则
- 规则应用：在阅读时自动应用替换规则

**相关页面**：
- `ui/pages/replace_rule/replace_rule_manage_page.dart`: 替换规则管理页面
- `ui/pages/replace_rule/replace_rule_edit_dialog.dart`: 替换规则编辑对话框

**相关服务**：
- `services/replace_rule_service.dart`: 替换规则服务

### 7. 阅读设置

**功能描述**：
- 字体设置：字体选择、字号、行距、字间距
- 排版设置：页边距、段间距、对齐方式
- 颜色设置：背景色、文字颜色、主题色
- 翻页设置：翻页动画、音量键翻页、点击区域
- 其他设置：自动刷新、自动备份、隐私保护

**相关页面**：
- `ui/pages/settings/settings_page.dart`: 设置页面
- `ui/pages/reader/reader_settings_page.dart`: 阅读设置页面

**相关服务**：
- `services/read_config_service.dart`: 阅读配置服务

### 8. 主题切换

**功能描述**：
- 明暗主题：支持明暗主题切换
- 自定义主题：支持自定义主题颜色
- 主题编辑：支持编辑已有主题
- 主题导入：支持导入主题配置

**相关页面**：
- `ui/pages/theme/theme_settings_page.dart`: 主题设置页面
- `ui/pages/theme/theme_edit_page.dart`: 主题编辑页面

**相关服务**：
- `services/theme_service.dart`: 主题服务
- `config/theme_config.dart`: 主题配置

### 9. 备份同步

**功能描述**：
- 本地备份：支持本地备份和恢复
- WebDAV 同步：支持 WebDAV 备份和同步
- 自动备份：支持自动备份到 WebDAV
- 备份恢复：支持从备份恢复数据

**相关页面**：
- `ui/pages/backup/backup_config_page.dart`: 备份配置页面
- `ui/pages/backup/backup_restore_page.dart`: 备份恢复页面

**相关服务**：
- `services/storage/backup_service.dart`: 备份服务
- `services/storage/restore_service.dart`: 恢复服务
- `services/storage/webdav_service.dart`: WebDAV 服务

### 10. Web服务

**功能描述**：
- HTTP 服务器：内置 HTTP 服务器（默认端口 1122）
- Web 界面：提供浏览器访问的 Web 界面
- 文件上传：支持通过浏览器上传书籍文件
- API 接口：提供 RESTful API 接口
- WebSocket：支持 WebSocket 实时通信

**相关页面**：
- Web 界面位于 `assets/web/` 目录

**相关服务**：
- `services/server_service.dart`: 服务器服务
- `services/web/web_service_manager.dart`: Web 服务管理
- `services/web/websocket_debug_handler.dart`: WebSocket 调试处理器

---

## 数据流

### 数据模型

**主要数据模型**：
- **Book**: 书籍模型（标题、作者、封面、URL、章节列表等）
- **BookSource**: 书源模型（名称、URL、规则、登录信息等）
- **BookChapter**: 章节模型（标题、URL、更新时间、VIP 标识等）
- **BookSourceRule**: 书源规则模型（搜索规则、目录规则、正文规则等）
- **ReplaceRule**: 替换规则模型（规则名称、替换规则等）
- **RssSource**: RSS 源模型（名称、URL、规则等）
- **RssArticle**: RSS 文章模型（标题、内容、发布时间等）
- **Bookmark**: 书签模型（书籍、章节、位置等）
- **ReadRecord**: 阅读记录模型（书籍、章节、位置、进度等）

**数据关系**：
```
Book (书籍)
  ├── BookChapter[] (章节列表)
  ├── Bookmark[] (书签列表)
  └── ReadRecord (阅读记录)

BookSource (书源)
  ├── BookSourceRule (规则)
  └── LoginInfo (登录信息)

ReplaceRule (替换规则)
  └── RuleGroup (规则分组)
```

### 数据持久化

**数据库存储 (sqflite)**：
- 书籍信息、章节列表、阅读记录、书签等
- 书源信息、书源规则、替换规则等
- RSS 源、RSS 文章、阅读记录等
- 其他配置数据

**本地存储 (shared_preferences)**：
- 应用配置（主题、字体、阅读设置等）
- 用户偏好设置
- 临时数据（搜索历史、最近访问等）

**文件存储**：
- 书籍缓存文件
- 封面图片缓存
- EPUB 文件
- 备份文件

### 数据同步

**本地同步**：
- 数据库事务保证数据一致性
- 缓存策略（LRU 缓存、时间过期）

**云端同步 (WebDAV)**：
- 备份文件上传到 WebDAV
- 从 WebDAV 恢复备份
- 自动检测新备份并提示恢复

**数据迁移**：
- 版本升级时自动迁移数据库结构
- 导入旧版本数据

---

## 架构设计

### 架构模式

**分层架构**：
```
┌─────────────────────────────────────┐
│           UI Layer (UI层)           │
│  ┌─────────┐  ┌─────────┐          │
│  │ Pages   │  │ Widgets │          │
│  └─────────┘  └─────────┘          │
└─────────────────────────────────────┘
           │                │
           ▼                ▼
┌─────────────────────────────────────┐
│      State Management (状态管理)     │
│  ┌─────────┐  ┌─────────┐          │
│  │Provider │  │ Riverpod│          │
│  └─────────┘  └─────────┘          │
└─────────────────────────────────────┘
           │                │
           ▼                ▼
┌─────────────────────────────────────┐
│        Service Layer (服务层)        │
│  ┌─────────┐  ┌─────────┐          │
│  │ Book    │  │ Source  │  ...     │
│  └─────────┘  └─────────┘          │
└─────────────────────────────────────┘
           │                │
           ▼                ▼
┌─────────────────────────────────────┐
│         Data Layer (数据层)          │
│  ┌─────────┐  ┌─────────┐          │
│  │Database │  │ Models  │          │
│  └─────────┘  └─────────┘          │
└─────────────────────────────────────┘
```

**核心原则**：
- **单一职责**：每个模块只负责特定功能
- **依赖注入**：通过构造函数注入依赖
- **接口隔离**：使用抽象基类定义接口
- **开闭原则**：对扩展开放，对修改关闭

### 模块关系

**依赖关系**：
```
UI Layer
  └─ depends on ─> State Management (Providers)
                      └─ depends on ─> Service Layer
                                          └─ depends on ─> Data Layer
                                                              └─ depends on ─> Core/Utils
```

**数据流向**：
1. **用户操作** → UI Layer → Provider
2. **Provider** → Service Layer → Data Layer
3. **Data Layer** → Service Layer → Provider → UI Layer

**服务依赖**：
- 所有服务继承自 `BaseService`
- 服务之间通过单例模式访问
- 网络服务被多个服务依赖
- 书源服务依赖网络服务和规则解析器

### 设计模式

**单例模式**：
- `NetworkService.instance`
- `BookService.instance`
- `SourceService.instance`
- 其他服务实例

**工厂模式**：
- 服务创建（BaseService）
- 规则解析器创建（RuleParser）

**观察者模式**：
- Riverpod 状态管理
- 事件通知（EventMessage）

**策略模式**：
- 规则解析策略（CSS、XPath、JSONPath、JavaScript）
- 内容处理策略（替换规则、简繁转换）

**适配器模式**：
- JavaScript 扩展（桥接 Dart 和 JavaScript）
- 平台适配（Android、iOS、macOS）

**模板方法模式**：
- BaseService 定义模板方法（init、dispose、execute）
- 子类实现具体逻辑

---

## 开发规范

### 代码规范

**遵循 Dart 官方代码规范**：
- 使用 `flutter_lints` 进行代码检查
- 遵循 Dart Style Guide
- 使用 2 空格缩进
- 每行不超过 80 个字符（可根据情况适当放宽）

**代码质量**：
- 避免使用 `dynamic` 类型（除非必要）
- 使用 `const` 构造函数（尽可能）
- 使用 `final` 变量（不可变变量）
- 避免深层嵌套（最多 3-4 层）

**错误处理**：
- 使用 `try-catch` 捕获异常
- 记录错误日志（AppLog.instance.put）
- 返回合理的默认值或抛出异常
- 服务初始化失败不应阻止应用启动

### 命名规范

**文件命名**：
- 使用 `snake_case`（如 `book_service.dart`）
- 类名与文件名对应（如 `BookService` 对应 `book_service.dart`）

**类命名**：
- 使用 `PascalCase`（如 `BookService`、`BookSource`）
- 抽象类以 `Base` 开头（如 `BaseService`）
- 接口以 `I` 开头或使用抽象类（如 `BaseBook`）

**变量命名**：
- 使用 `camelCase`（如 `bookService`、`chapterList`）
- 私有变量以下划线开头（如 `_bookService`、`_isInitialized`）
- 常量使用 `lowerCamelCase` 或 `UPPER_SNAKE_CASE`（如 `defaultTimeout` 或 `DEFAULT_TIMEOUT`）

**方法命名**：
- 使用 `camelCase`（如 `getBook()`、`updateChapterList()`）
- 布尔方法使用 `is`、`has`、`can` 前缀（如 `isInitialized`、`hasContent`、`canUpdate`）
- 私有方法以下划线开头（如 `_parseRule()`）

### 文件组织

**目录结构**：
- 按功能模块组织文件
- 相关文件放在同一目录
- 页面文件放在 `ui/pages/` 下，按功能分类
- 服务文件放在 `services/` 下，按功能分类

**导入顺序**：
1. Dart 标准库（`dart:...`）
2. Flutter 框架（`package:flutter/...`）
3. 第三方包（`package:...`）
4. 项目内部导入（相对路径或绝对路径）
5. 使用空行分隔不同组

**示例**：
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dio/dio.dart';
import 'package:riverpod/riverpod.dart';

import '../../data/models/book.dart';
import '../../services/book/book_service.dart';
import '../../utils/app_log.dart';
```

### 注释规范

**文档注释**：
- 公共 API 使用 `///` 文档注释
- 说明类、方法、属性的用途
- 使用 `@param`、`@returns`、`@throws` 标签（可选）

**代码注释**：
- 复杂逻辑使用 `//` 行注释
- 说明"为什么"而不是"做什么"
- 避免无意义的注释

**TODO 注释**：
- 使用 `// TODO: 描述` 标记待完成功能
- 使用 `// FIXME: 描述` 标记需要修复的问题
- 定期清理已完成的 TODO

**示例**：
```dart
/// 书籍服务
/// 负责书籍的增删改查、章节获取等功能
class BookService extends BaseService {
  /// 获取书籍章节列表
  /// 
  /// [book] 书籍对象
  /// [forceUpdate] 是否强制更新
  /// 
  /// 返回章节列表，如果获取失败返回 null
  Future<List<BookChapter>?> getChapterList(
    Book book, {
    bool forceUpdate = false,
  }) async {
    // TODO: 实现缓存逻辑
    try {
      // 从网络获取章节列表
      // ...
    } catch (e) {
      AppLog.instance.put('获取章节列表失败', error: e);
      return null;
    }
  }
}
```

---

## 附录

### A. 依赖列表

详见 `pubspec.yaml` 文件，主要依赖包括：

**核心依赖**：
- Flutter SDK (>=3.0.0 <4.0.0)
- Riverpod (^3.0.3) - 状态管理
- sqflite (^2.3.0) - 数据库
- dio (^5.4.0) - 网络请求

**解析库**：
- html (^0.15.4) - HTML 解析
- xpath_selector (^3.0.2) - XPath 查询
- json_path (^0.9.0) - JSONPath 查询
- flutter_js (^0.8.5) - JavaScript 引擎

**其他依赖**：
详见 `pubspec.yaml` 文件

### B. 平台支持

**已支持平台**：
- ✅ **Android**: 完全支持
- ✅ **iOS**: 完全支持
- ✅ **macOS**: 完全支持

**计划支持平台**：
- ⏳ **Web**: 计划中
- ⏳ **Linux**: 计划中
- ⏳ **Windows**: 计划中

**平台特定功能**：
- Android: 快捷方式、通知、分享接收、文件接收
- iOS: URL Scheme、通知
- macOS: 桌面应用支持

### C. 参考文档

**项目文档**：
- `README.md`: 项目说明
- `docs/HTML_PARSER_DIFFERENCES.md`: HTML 解析库差异说明
- `docs/HTML_PARSER_IMPROVEMENTS_SUMMARY.md`: HTML 解析库改进总结
- `docs/PROJECT_FRAMEWORK.md`: 项目框架文档（本文档）

**参考项目**：
- Legado Android: https://github.com/gedoor/legado
- Legado Android 项目本地路径: /Users/zhangmingxun/Downloads/legado-master
- 项目规则格式与参考项目兼容

**Flutter 官方文档**：
- Flutter: https://flutter.dev/docs
- Dart: https://dart.dev/guides

**技术栈文档**：
- Riverpod: https://riverpod.dev/docs/introduction/getting_started
- sqflite: https://pub.dev/packages/sqflite
- dio: https://pub.dev/packages/dio

---

**文档版本**: v1.0.0  
**最后更新**: 2026-01-07  
**维护者**: Legado Flutter Team

