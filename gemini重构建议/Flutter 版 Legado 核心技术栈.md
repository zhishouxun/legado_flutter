结合我们之前的深度讨论，复刻 **Legado (阅读)** Flutter 版的核心思路是：**用 Flutter 的跨端渲染能力，去承载一套复杂的“Jsoup + JS”协议引擎。**

以下是为您总结的该项目**完整技术栈建议**：

---

## 🛠️ Flutter 版 Legado 核心技术栈

### 1. 核心架构 (Architecture)

* **设计模式：** **Clean Architecture (DDD)**
* 将解析逻辑（Data）、业务实体（Domain）和界面渲染（Presentation）彻底解耦。


* **状态管理：** **Riverpod**
* 原因：原生支持全局 Provider，方便在阅读器各处共享 `ReaderConfig`，且对异步搜索流（Stream）的支持非常优雅。



---

### 2. 数据持久化 (Storage)

* **主数据库：** **Isar Database**
* 原因：NoSQL 架构，性能远超 SQLite；原生支持二进制序列化，存储小说章节这种大文本非常快；支持多线程 Isolate 操作。


* **简单配置：** **Shared Preferences**
* 用于存储简单的开关设置（如：是否开启音量键翻页）。


* **文件系统：** **Path Provider**
* 用于管理本地下载的 `.ttf` 字体文件和书籍缓存目录。



---

### 3. 书源解析引擎 (Parser Engine)

这是项目的“发动机”，需要模拟安卓原生的 Jsoup 逻辑：

* **HTML 解析：** **`html` (Dart 库)**
* 提供类似 Jsoup 的 CSS 选择器功能。


* **JS 运行环境：** **`flutter_js` (基于 QuickJS)**
* 用于执行书源规则中的自定义 JavaScript 代码。


* **数据定位：** **`xpath_parse`** & **`json_path`**
* 兼容不同书源定义的定位协议。


* **网络请求：** **Dio**
* 配合 `dio_cookie_manager` 处理需要登录的书源。



---

### 4. 阅读器渲染 (Reader UI)

这是视觉体验的核心：

* **分页计算：** **`TextPainter`**
* 利用底层渲染 API 进行文本测量，实现精准分页。


* **高性能绘制：** **`CustomPaint` + `Canvas**`
* 直接在画布上绘制文字，避免几千个 Widget 导致的内存抖动。


* **容器控件：** **`PageView.builder`**
* 实现顺滑的平移翻页效果。


* **图片加载：** **`cached_network_image`**
* 缓存书源中的书籍封面。



---

### 5. 功能增强 (Utilities)

* **后台处理：** **`Isolates` (compute)**
* 将耗时的搜索、解析、分页逻辑移出主线程，保证 UI 60fps。


* **同步功能：** **`webdav_client`**
* 实现 Legado 用户刚需的 WebDAV 进度同步。


* **代码生成：** **`freezed`** & **`json_serializable`**
* 自动生成 Immutable 类和 JSON 转换代码，减少样板代码。



---

## 💡 技术栈总结表

| 模块 | 推荐工具 | 作用 |
| --- | --- | --- |
| **语言** | Dart 3.x | 利用其模式匹配和强类型特性 |
| **状态管理** | Riverpod | 解决复杂的全局状态联动 |
| **数据库** | Isar | 存储万量级的书籍和章节 |
| **网络** | Dio | 支持拦截器、Cookie 和并发请求 |
| **JS 环境** | flutter_js | 运行书源里的动态解析规则 |
| **排版** | TextPainter | 核心分页算法的底层支撑 |
| **UI 组件** | CustomPaint | 追求像素级的阅读排版自由度 |

---

## 📅 下一步行动建议

既然你已经确定了技术栈，我建议你从**最稳固的部分**开始构建：

1. **第一步：** 先用 **Isar** 定义好 `Book` 和 `BookSource` 的模型（Model）。
2. **第二步：** 编写一个简单的 **Repo 层**，实现从本地加载书籍列表。
3. **第三步：** 引入 **`html` 库**，尝试写一个能解析“百度搜索结果”的小 Demo，验证你的 CSS 选择器逻辑。

**如果你准备好了，我可以先为你生成 `Isar` 数据库的初始化配置代码，帮你把“地基”打好。需要吗？**