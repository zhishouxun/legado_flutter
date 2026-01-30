# Android SDK 配置问题修复指南

## 问题描述

Flutter doctor 显示以下错误：
- ✗ Flutter requires Android SDK 36 and the Android BuildTools 28.0.3
- ! Some Android licenses not accepted

## 解决方案

### 1. 更新 Android SDK

**注意**：Android SDK 36 目前还不存在（最新是 SDK 35）。这个错误可能是 Flutter 版本问题。请按以下步骤操作：

#### 方法一：通过 Android Studio 更新

1. 打开 **Android Studio**
2. 进入 **Tools > SDK Manager**
3. 在 **SDK Platforms** 标签页：
   - 勾选 **Android 14.0 (API 34)**（已安装）
   - 如果有 **Android 15.0 (API 35)**，也勾选安装
4. 在 **SDK Tools** 标签页：
   - 勾选 **Android SDK Build-Tools 34.0.0**（或最新版本）
   - 勾选 **Android SDK Command-line Tools**
   - 勾选 **Android SDK Platform-Tools**
5. 点击 **Apply** 安装

#### 方法二：通过命令行更新

```bash
# 设置 Android SDK 路径（根据你的实际路径调整）
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

# 使用 sdkmanager 安装 SDK
# 注意：如果 sdkmanager 不存在，需要先安装 Command-line Tools
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platforms;android-34"
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "build-tools;34.0.0"
```

### 2. 接受 Android 许可证

运行以下命令接受所有 Android 许可证：

```bash
flutter doctor --android-licenses
```

如果上面的命令不工作，尝试：

```bash
# 方法一：使用 Flutter 的许可证接受工具
yes | flutter doctor --android-licenses

# 方法二：直接使用 sdkmanager
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses
```

**注意**：需要按 `y` 接受每个许可证。

### 3. 验证修复

运行以下命令检查是否已修复：

```bash
flutter doctor -v
```

应该看到：
```
Android toolchain - develop for Android devices (Android SDK version XX.X.X)
    ✓ Android SDK 已正确配置
    ✓ Android licenses 已接受
```

### 4. 如果问题仍然存在

#### 检查 Flutter 版本

```bash
flutter --version
```

如果 Flutter 版本过新，可能需要：
1. 降级到稳定版本：`flutter downgrade`
2. 或等待 Flutter 更新支持当前 Android SDK

#### 检查 Android SDK 路径

```bash
# 查看当前 Android SDK 路径
echo $ANDROID_HOME

# 或在 macOS 上
echo $HOME/Library/Android/sdk
```

确保 `local.properties` 文件中有正确的 SDK 路径：

```properties
sdk.dir=/Users/你的用户名/Library/Android/sdk
```

#### 清理并重新配置

```bash
# 清理 Flutter 缓存
flutter clean

# 重新获取依赖
flutter pub get

# 重新检查
flutter doctor
```

### 5. 项目配置说明

项目已配置为使用：
- **compileSdk**: 34 (Android 14)
- **targetSdk**: 34
- **minSdk**: 21 (Android 5.0)
- **buildToolsVersion**: 34.0.0

这些配置是合理的，不需要修改。问题主要在于：
1. 确保安装了 Android SDK 34
2. 确保安装了 BuildTools 34.0.0（或更新版本）
3. 接受所有 Android 许可证

## 常见问题

### Q: 为什么要求 SDK 36？
A: 这可能是 Flutter 版本的问题。实际上 Android SDK 36 还不存在。请确保安装了 SDK 34 或 35，项目配置使用 SDK 34 是合理的。

### Q: BuildTools 28.0.3 不存在？
A: BuildTools 版本号通常是 30.x, 31.x, 33.x, 34.x 等。28.0.3 这个版本号看起来不对。请使用 BuildTools 34.0.0 或更新版本。

### Q: 如何找到 Android SDK 路径？
A: 
- **macOS**: `~/Library/Android/sdk`
- **Linux**: `~/Android/Sdk`
- **Windows**: `%LOCALAPPDATA%\Android\Sdk`

### Q: 许可证接受失败？
A: 确保：
1. 网络连接正常
2. 使用 `yes |` 前缀自动接受所有许可证
3. 或者手动运行并逐个输入 `y`

## 下一步

修复完成后，运行：

```bash
flutter devices  # 检查设备连接
flutter run      # 运行应用
```

