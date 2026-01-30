# iOS 平台配置

## 已完成的配置

✅ **AppIcon.appiconset** - 已创建，包含所有必需的图标尺寸
✅ **Contents.json** - 已配置图标清单
✅ **Info.plist** - 已创建应用配置文件
✅ **AppDelegate.swift** - 已创建应用委托
✅ **Main.storyboard** - 已创建主界面
✅ **LaunchScreen.storyboard** - 已创建启动屏幕

## 图标配置

### 已生成的图标尺寸

#### iPhone 图标
- ✅ `Icon-App-20x20@2x.png` (40x40) - 通知图标
- ✅ `Icon-App-20x20@3x.png` (60x60) - 通知图标
- ✅ `Icon-App-29x29@1x.png` (29x29) - 设置图标
- ✅ `Icon-App-29x29@2x.png` (58x58) - 设置图标
- ✅ `Icon-App-29x29@3x.png` (87x87) - 设置图标
- ✅ `Icon-App-40x40@2x.png` (80x80) - Spotlight 图标
- ✅ `Icon-App-40x40@3x.png` (120x120) - Spotlight 图标
- ✅ `Icon-App-60x60@2x.png` (120x120) - 应用图标
- ✅ `Icon-App-60x60@3x.png` (180x180) - 应用图标

#### iPad 图标
- ✅ `Icon-App-20x20@1x.png` (20x20) - 通知图标
- ✅ `Icon-App-20x20@2x.png` (40x40) - 通知图标
- ✅ `Icon-App-29x29@1x.png` (29x29) - 设置图标
- ✅ `Icon-App-29x29@2x.png` (58x58) - 设置图标
- ✅ `Icon-App-40x40@1x.png` (40x40) - Spotlight 图标
- ✅ `Icon-App-40x40@2x.png` (80x80) - Spotlight 图标
- ✅ `Icon-App-76x76@1x.png` (76x76) - 应用图标
- ✅ `Icon-App-76x76@2x.png` (152x152) - 应用图标
- ✅ `Icon-App-83.5x83.5@2x.png` (167x167) - iPad Pro 应用图标

#### App Store 图标
- ✅ `Icon-App-1024x1024@1x.png` (1024x1024) - App Store 图标

## 图标来源

所有图标都从 Android 的 `mipmap-xxxhdpi/ic_launcher.png` (192x192) 转换而来，使用 macOS 的 `sips` 工具调整到所需尺寸。

## 需要手动完成的工作

### 1. 创建 Xcode 项目文件

iOS 项目需要完整的 Xcode 项目配置。可以使用以下命令生成：

```bash
flutter create --platforms=ios .
```

或者使用 Xcode 手动创建项目。

### 2. 配置 Bundle Identifier

在 Xcode 项目中设置 Bundle Identifier（例如：`io.legado.app`）。

### 3. 配置签名

在 Xcode 中配置代码签名，以便在设备上运行或发布到 App Store。

### 4. 测试

运行以下命令测试应用：
```bash
flutter run -d ios
```

或者使用 Xcode 打开项目并运行。

## 注意事项

- 包名：建议使用 `io.legado.app`（与 Android 保持一致）
- 最低 iOS 版本：建议 iOS 12.0 或更高
- 所有图标尺寸已从 Android 图标转换完成
- 图标设计在所有平台保持一致

## 图标验证

所有图标文件已生成并放置在正确位置：
```
ios/Runner/Assets.xcassets/AppIcon.appiconset/
├── Contents.json
├── Icon-App-20x20@1x.png
├── Icon-App-20x20@2x.png
├── Icon-App-20x20@3x.png
├── Icon-App-29x29@1x.png
├── Icon-App-29x29@2x.png
├── Icon-App-29x29@3x.png
├── Icon-App-40x40@1x.png
├── Icon-App-40x40@2x.png
├── Icon-App-40x40@3x.png
├── Icon-App-60x60@2x.png
├── Icon-App-60x60@3x.png
├── Icon-App-76x76@1x.png
├── Icon-App-76x76@2x.png
├── Icon-App-83.5x83.5@2x.png
└── Icon-App-1024x1024@1x.png
```

共 15 个图标文件，覆盖所有必需的尺寸。

