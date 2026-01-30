# Android 端运行指南

## 前置要求

### 1. 环境准备
- ✅ Flutter SDK 已安装（建议 3.0+）
- ✅ Android Studio 已安装
- ✅ Android SDK 已配置（API Level 21+，targetSdk 34）
- ✅ Java JDK 8+ 已安装

### 2. 检查 Flutter 环境
```bash
flutter doctor
```
确保以下项都正常：
- Flutter SDK
- Android toolchain
- Android Studio
- Connected device（如果有设备连接）

## 运行步骤

### 方法一：使用 Flutter 命令（推荐）

#### 1. 检查连接的设备
```bash
flutter devices
```
应该能看到连接的 Android 设备或模拟器。

#### 2. 获取依赖
```bash
flutter pub get
```

#### 3. 运行应用
```bash
# Debug 模式运行
flutter run

# 或者指定设备
flutter run -d <device-id>

# Release 模式运行（性能更好）
flutter run --release
```

### 方法二：使用 Android Studio

1. **打开项目**
   - 在 Android Studio 中选择 `File > Open`
   - 选择项目根目录 `/Users/zhangmingxun/Desktop/legado_flutter`

2. **配置 Flutter SDK**
   - `File > Settings > Languages & Frameworks > Flutter`
   - 设置 Flutter SDK 路径

3. **运行应用**
   - 点击工具栏的运行按钮（▶️）
   - 或使用快捷键 `Shift + F10`（Windows/Linux）或 `Ctrl + R`（macOS）

### 方法三：使用命令行构建 APK

#### 构建 Debug APK
```bash
flutter build apk --debug
```
生成的 APK 位置：`build/app/outputs/flutter-apk/app-debug.apk`

#### 构建 Release APK
```bash
flutter build apk --release
```
生成的 APK 位置：`build/app/outputs/flutter-apk/app-release.apk`

#### 构建 App Bundle（用于 Google Play）
```bash
flutter build appbundle --release
```
生成的 AAB 位置：`build/app/outputs/bundle/release/app-release.aab`

## Android SDK 配置问题

### 如果遇到 SDK 版本错误

如果 `flutter doctor` 显示 SDK 版本问题：

1. **更新 Android SDK**
   - 打开 Android Studio > Tools > SDK Manager
   - 安装 Android SDK 34 和 BuildTools 34.0.0

2. **接受 Android 许可证**
   ```bash
   flutter doctor --android-licenses
   ```
   或使用：
   ```bash
   yes | flutter doctor --android-licenses
   ```

3. **详细修复步骤**：参考 `ANDROID_SDK_FIX.md`

## 常见问题排查

### 1. 设备未连接
**问题**：`flutter devices` 显示无设备

**解决方案**：
- 确保 Android 设备已启用 USB 调试
- 在设备上允许 USB 调试授权
- 检查 USB 连接线
- 运行 `adb devices` 检查设备是否被识别

### 2. Gradle 构建失败
**问题**：构建时出现 Gradle 错误

**解决方案**：
```bash
# 清理构建缓存
flutter clean
cd android
./gradlew clean
cd ..

# 重新获取依赖
flutter pub get

# 重新运行
flutter run
```

### 3. 权限问题
**问题**：应用无法访问网络或存储

**检查**：`android/app/src/main/AndroidManifest.xml` 中已包含必要权限：
- `INTERNET` - 网络访问
- `READ_EXTERNAL_STORAGE` - 读取存储
- `WRITE_EXTERNAL_STORAGE` - 写入存储
- `ACCESS_NETWORK_STATE` - 网络状态
- `POST_NOTIFICATIONS` - 通知权限（Android 13+）

### 4. 签名问题（Release 构建）
**问题**：Release 构建需要签名配置

**解决方案**：
- Debug 模式使用默认签名（已配置）
- Release 模式需要配置签名密钥（参考 Android 官方文档）

### 5. 依赖冲突
**问题**：`flutter pub get` 失败

**解决方案**：
```bash
# 清理并重新获取
flutter clean
flutter pub get

# 如果仍有问题，检查 pubspec.yaml 中的依赖版本
```

## 性能优化建议

### Debug 模式
- 适合开发和调试
- 包含调试信息，运行较慢
- 支持热重载（Hot Reload）

### Release 模式
- 性能最优，适合测试和发布
- 代码已优化和压缩
- 不支持热重载

### Profile 模式
```bash
flutter run --profile
```
- 用于性能分析
- 包含性能分析工具

## 调试技巧

### 1. 查看日志
```bash
# 实时查看日志
flutter logs

# 或使用 adb
adb logcat
```

### 2. 热重载
- 在运行应用时，按 `r` 键进行热重载
- 按 `R` 键进行热重启
- 按 `q` 键退出

### 3. 检查性能
```bash
# 运行性能分析
flutter run --profile
```

## 项目配置信息

- **应用包名**：`io.legado.app`
- **最低 SDK**：21（Android 5.0）
- **目标 SDK**：34（Android 14）
- **编译 SDK**：34
- **Kotlin 版本**：1.9.22
- **Gradle 版本**：8.1.0

## 下一步

运行成功后，你可以：
1. 测试应用功能
2. 使用热重载快速开发
3. 构建 Release 版本进行测试
4. 准备发布到 Google Play

## 参考资源

- [Flutter 官方文档](https://flutter.dev/docs)
- [Android 开发指南](https://developer.android.com/guide)
- [Flutter 性能优化](https://flutter.dev/docs/perf)

