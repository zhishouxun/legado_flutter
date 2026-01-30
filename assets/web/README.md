# assets/web 目录说明

## 目录作用

`assets/web` 目录包含了用于 **Web 服务** 的静态资源文件。当应用启动 Web 服务时，这些文件会被提供给浏览器访问。

## 功能说明

### 1. 主页面 (`index.html`)
- **路径**: `/` 或 `/index.html`
- **功能**: Web 服务的主导航页面
- **内容**: 提供到各个功能模块的链接入口
  - 书架管理
  - 书源管理
  - 传书功能
  - RSS 订阅源管理

### 2. Vue 前端应用 (`vue/`)
- **路径**: `/vue/index.html`
- **功能**: 基于 Vue.js 的 Web 前端应用
- **特性**:
  - 书架管理界面
  - 书源管理界面
  - RSS 订阅源管理界面
  - 章节阅读界面
- **技术栈**: Vue.js + TypeScript

### 3. WiFi 传书功能 (`uploadBook/`)
- **路径**: `/uploadBook/index.html`
- **功能**: 通过 WiFi 上传书籍文件到应用
- **使用场景**: 
  - 在电脑浏览器中打开 Web 服务地址
  - 访问 `/uploadBook/index.html`
  - 选择本地书籍文件上传
  - 文件会自动添加到应用的书架中

### 4. 帮助文档 (`help/`)
- **路径**: `/help/index.html`
- **功能**: 应用使用帮助文档
- **内容**: 包含多个 Markdown 格式的帮助文档
  - `appHelp.md` - 应用使用帮助
  - `debugHelp.md` - 调试帮助
  - `dictRuleHelp.md` - 字典规则帮助
  - `httpTTSHelp.md` - HTTP TTS 帮助
  - `jsHelp.md` - JavaScript 规则帮助
  - `readMenuHelp.md` - 阅读菜单帮助
  - `regexHelp.md` - 正则表达式帮助
  - `replaceRuleHelp.md` - 替换规则帮助
  - `ruleHelp.md` - 规则帮助
  - `SourceMBookHelp.md` - 书源管理帮助
  - `SourceMRssHelp.md` - RSS 源管理帮助
  - `txtTocRuleHelp.md` - TXT 目录规则帮助
  - `webDavBookHelp.md` - WebDAV 书籍帮助
  - `webDavHelp.md` - WebDAV 帮助
  - `xpathHelp.md` - XPath 帮助

## 使用方式

### 启动 Web 服务
1. 在应用设置中启用 Web 服务
2. 应用会启动一个本地 HTTP 服务器（默认端口：1122）
3. 获取服务地址（例如：`http://192.168.1.100:1122`）

### 访问 Web 界面
1. 在电脑浏览器中打开服务地址
2. 访问主页面：`http://192.168.1.100:1122/`
3. 或直接访问功能页面：
   - 书架：`http://192.168.1.100:1122/vue/index.html`
   - 传书：`http://192.168.1.100:1122/uploadBook/index.html`
   - 帮助：`http://192.168.1.100:1122/help/index.html`

## 技术实现

### 参考项目（Android）
- 使用 `NanoHTTPD` 作为 HTTP 服务器
- 使用 `AssetsWeb` 类从 assets 目录提供静态文件
- 通过 `WebService` 管理服务器生命周期

### Flutter 项目
- 使用 `shelf` 作为 HTTP 服务器
- 需要实现静态文件服务功能
- 通过 `WebServiceManager` 管理服务器

## 文件结构

```
assets/web/
├── index.html              # 主页面
├── favicon.ico             # 网站图标
├── assets/                 # 静态资源
│   ├── css/               # 样式文件
│   └── js/                # JavaScript 文件
├── vue/                    # Vue 前端应用
│   ├── index.html
│   └── assets/            # Vue 应用资源
├── uploadBook/            # WiFi 传书功能
│   ├── index.html
│   ├── css/
│   ├── js/
│   └── img/
└── help/                   # 帮助文档
    ├── index.html
    ├── css/
    ├── js/
    └── md/                # Markdown 帮助文档
```

## 注意事项

1. **静态文件服务**: Flutter 项目需要实现从 assets 目录提供静态文件的功能
2. **CORS 支持**: Web 服务需要支持跨域请求（CORS）
3. **API 接口**: Web 服务还提供 RESTful API 接口，用于前端与后端数据交互
4. **WebSocket**: 部分功能（如书源调试）使用 WebSocket 进行实时通信

