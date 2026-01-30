# Legado Flutter

基于 Flutter 开发的跨平台开源小说阅读器，旨在还原并增强 [Legado (阅读)](https://github.com/gedoor/legado) 的核心功能与使用体验。

主要使用 Cursor 和 Qoder 开发。本人对 flutter 并不是很熟悉。

## 📖 项目简介

Legado Flutter 是一个高度可定制的阅读工具，支持通过自定义规则获取网络资源。它不仅是一个阅读器，更是一个强大的内容聚合平台。

## ✨ 核心功能

- **高度兼容的书源引擎**：支持自定义书源规则，兼容 Legado 书源格式，具备强大的内容解析能力。
- **全格式阅读支持**：支持网络小说爬取、本地 TXT、EPUB 格式阅读，并集成了 RSS 订阅功能。
- **极致个性化**：
  - 自定义替换净化规则，告别广告与错别字。
  - 丰富的阅读主题切换，支持夜间模式。
  - 灵活的字体、行高、页边距等排版设置。
- **进阶特性**：
  - 内置 TTS 朗读支持，解放双手。
  - 提供 Web 服务 API，支持远程管理。
  - 完善的书签、阅读记录及书架分组管理。

## 🏗️ 架构设计

项目采用清晰的分层架构，确保代码的可维护性与扩展性：

- **`lib/data/`**: 数据持久化与模型层，管理数据库及 JSON 模型。
- **`lib/services/`**: 业务逻辑层，涵盖书源解析、网络请求、TTS、RSS 处理等核心服务。
- **`lib/providers/`**: 状态管理层，基于 `Provider` 实现跨组件状态共享（书架、设置、更新等）。
- **`lib/ui/`**: 界面展示层，包含各功能页面（pages）与通用 UI 组件（widgets）。
- **`lib/utils/`**: 工具类，集成 JS 引擎、加密算法、HTML 解析及平台适配工具。

### 项目结构树
```text
lib/
├── main.dart                 # 应用入口
├── app.dart                  # 应用主类
├── config/                   # 配置文件 (App/Theme Config)
├── core/                     # 核心基础层 (Base, Constants, Exceptions)
├── data/                     # 数据层
│   ├── database/            # 数据库实现
│   └── models/              # 数据模型
├── services/                 # 业务逻辑服务层 (书源解析、网络、TTS、RSS 等)
├── providers/                # 状态管理
├── ui/                       # UI 展示层
│   ├── pages/               # 各功能页面 (书架/阅读器/管理/设置)
│   ├── widgets/            # 抽离的公用组件
│   └── dialogs/            # 通用对话框组件
└── utils/                    # 工具类 (Parser, JS Engine, Crypto, Helpers)
```

## 📱 平台支持

- ✅ **Android**: 深度优化，支持良好。
- ✅ **iOS**: 已完成适配，性能流畅。
- ⏳ **Web & Desktop**: 正在积极适配中，敬请期待。

## 🛠️ 开发指南

### 基础环境
- Flutter SDK: 最新稳定版
- Dart: 随 Flutter 自动安装

### 常用命令

#### 依赖管理与环境检查
```bash
flutter pub get          # 安装依赖
flutter clean            # 清理构建缓存
flutter doctor           # 检查 Flutter 环境
```

#### 代码生成 (重要)
由于项目使用了 `build_runner` 处理数据模型和规则解析，修改相关代码后需运行：
```bash
# 一次性生成
flutter pub run build_runner build --delete-conflicting-outputs

# 监听模式（开发时推荐）
flutter pub run build_runner watch --delete-conflicting-outputs
```

#### 运行项目
```bash
flutter run              # 运行到默认设备
flutter run -d macos     # 运行到 macOS
flutter run -d ios       # 运行到 iOS
flutter run -d android   # 运行到 Android
flutter run -d chrome    # 运行到 Web
```
*注：在运行应用时，按 `r` 键热重载，按 `R` 键热重启。*

#### 构建发布版本
```bash
flutter build apk --release        # 构建 Android APK
flutter build ios --release        # 构建 iOS 应用
flutter build macos --release      # 构建 macOS 应用
flutter build web --release        # 构建 Web 版本
```

#### 测试与分析
```bash
flutter test             # 运行单元测试
flutter analyze          # 代码静态分析
flutter format .         # 格式化所有代码
```

## 📜 许可协议

本项目遵循开源协议，详情请参阅项目中的 LICENSE 文件。
