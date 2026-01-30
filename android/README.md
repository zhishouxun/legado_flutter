# Android 平台配置

## 已完成的配置

✅ **MainActivity.kt** - 已创建，包含快捷方式功能
✅ **AndroidManifest.xml** - 已配置 URL Scheme 和权限
✅ **build.gradle** - 已配置依赖和编译选项
✅ **settings.gradle** - 已配置项目设置
✅ **gradle.properties** - 已配置 Gradle 属性

## 快捷方式功能

应用启动时会自动创建三个快捷方式：
1. **书架** - 打开主页面
2. **最后阅读** - 如果有最后阅读的书籍，打开阅读页面
3. **朗读** - 打开朗读功能

## 需要手动完成的工作

### 1. 添加应用图标

将应用图标文件添加到以下目录：
- `app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
- `app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
- `app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
- `app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
- `app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)

或者使用 Android Studio 的 Image Asset Studio 生成图标。

### 2. 配置签名（可选）

如果需要发布到应用商店，需要配置签名密钥。在 `app/build.gradle` 的 `buildTypes` 中配置 `signingConfig`。

### 3. 测试

运行以下命令测试应用：
```bash
flutter run
```

或者使用 Android Studio 打开项目并运行。

## 注意事项

- 包名：`io.legado.app`
- 最低 SDK 版本：21 (Android 5.0)
- 目标 SDK 版本：34 (Android 14)
- URL Scheme：`legado://`

## 快捷方式工作原理

1. Flutter 端 `ShortcutService` 在应用启动时调用 `buildShortcuts()`
2. 通过 MethodChannel 调用 Android 原生代码
3. Android 端创建快捷方式并注册到系统
4. 用户长按应用图标可以看到快捷方式
5. 点击快捷方式会触发 URL Scheme，由 `UrlSchemeService` 处理

