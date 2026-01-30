# Android 安装包打包指南

## 快速开始

### 方法一：使用 Flutter 命令（推荐）

#### 1. 构建 Debug APK（测试用）

```bash
cd /Users/zhangmingxun/Desktop/legado_flutter
flutter build apk --debug
```

**输出位置**：`build/app/outputs/flutter-apk/app-debug.apk`

**特点**：
- 包含调试信息
- 体积较大
- 适合开发和测试
- 使用 debug 签名

#### 2. 构建 Release APK（发布用）

```bash
flutter build apk --release
```

**输出位置**：`build/app/outputs/flutter-apk/app-release.apk`

**特点**：
- 代码已优化和压缩
- 体积更小，性能更好
- 适合分发给用户
- 当前使用 debug 签名（可配置正式签名）

#### 3. 构建 Split APKs（按架构分离，体积更小）

```bash
flutter build apk --release --split-per-abi
```

**输出位置**：
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (32位 ARM)
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (64位 ARM)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (64位 x86)

**特点**：
- 每个 APK 只包含特定 CPU 架构的代码
- 体积更小（通常减少 30-50%）
- 用户只需下载适合自己设备的版本

#### 4. 构建 App Bundle（用于 Google Play）

```bash
flutter build appbundle --release
```

**输出位置**：`build/app/outputs/bundle/release/app-release.aab`

**特点**：
- Google Play 推荐格式
- Google Play 会自动生成优化的 APK
- 体积最小
- 必须使用正式签名（需要配置）

## 详细步骤

### 步骤 1：清理之前的构建

```bash
flutter clean
flutter pub get
```

### 步骤 2：选择构建类型

根据需求选择以下命令之一：

```bash
# Debug 版本（测试）
flutter build apk --debug

# Release 版本（发布）
flutter build apk --release

# Split APKs（推荐，体积更小）
flutter build apk --release --split-per-abi

# App Bundle（Google Play）
flutter build appbundle --release
```

### 步骤 3：查找生成的安装包

构建完成后，安装包位置：

- **Debug APK**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Release APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Split APKs**: `build/app/outputs/flutter-apk/app-<abi>-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`

### 步骤 4：安装到设备

#### 方法一：使用 adb 安装

```bash
# 安装 Debug APK
adb install build/app/outputs/flutter-apk/app-debug.apk

# 安装 Release APK
adb install build/app/outputs/flutter-apk/app-release.apk

# 如果已安装，使用 -r 替换
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

#### 方法二：直接传输到设备

1. 将 APK 文件复制到 Android 设备
2. 在设备上打开文件管理器
3. 点击 APK 文件进行安装
4. 允许"未知来源"安装（如需要）

## 配置正式签名（可选）

### 当前状态

项目当前使用 debug 签名，适合测试。如果要发布到应用商店，需要配置正式签名。

### 创建签名密钥

#### 1. 生成密钥库

```bash
keytool -genkey -v -keystore ~/legado-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias legado
```

**参数说明**：
- `-keystore`: 密钥库文件路径
- `-keyalg`: 密钥算法（RSA）
- `-keysize`: 密钥大小（2048位）
- `-validity`: 有效期（10000天）
- `-alias`: 密钥别名

**重要**：请妥善保管密钥库文件和密码！

#### 2. 创建 key.properties 文件

在 `android` 目录下创建 `key.properties` 文件：

```properties
storePassword=你的密钥库密码
keyPassword=你的密钥密码
keyAlias=legado
storeFile=/Users/zhangmingxun/legado-release-key.jks
```

**注意**：不要将 `key.properties` 提交到版本控制系统！

#### 3. 修改 build.gradle

修改 `android/app/build.gradle`：

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... 其他配置 ...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            // 可选：启用代码混淆
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

#### 4. 更新 .gitignore

确保 `key.properties` 和密钥库文件不被提交：

```gitignore
# Android 签名文件
android/key.properties
*.jks
*.keystore
```

## 构建优化选项

### 1. 启用代码混淆（可选）

在 `android/app/build.gradle` 的 `release` 构建类型中添加：

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

### 2. 减小 APK 体积

```bash
# 使用 Split APKs（推荐）
flutter build apk --release --split-per-abi

# 或使用 App Bundle
flutter build appbundle --release
```

### 3. 查看 APK 信息

```bash
# 查看 APK 大小
ls -lh build/app/outputs/flutter-apk/app-release.apk

# 使用 aapt 查看详细信息
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
```

## 常见问题

### Q: 构建失败，提示找不到 SDK？

**解决方案**：
1. 确保 Android SDK 已正确安装
2. 检查 `android/local.properties` 中的 `sdk.dir` 路径
3. 运行 `flutter doctor` 检查环境

### Q: 构建很慢？

**解决方案**：
1. 首次构建会下载依赖，需要时间
2. 后续构建会使用缓存，速度更快
3. 使用 `--release` 模式构建会更快

### Q: APK 体积太大？

**解决方案**：
1. 使用 `--split-per-abi` 构建分离的 APK
2. 使用 App Bundle 格式
3. 启用代码混淆和资源压缩

### Q: 安装时提示"应用未安装"？

**解决方案**：
1. 卸载旧版本应用
2. 检查设备存储空间
3. 确保 APK 未损坏（重新构建）

### Q: 如何查看 APK 签名信息？

```bash
# 查看签名
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# 或使用 apksigner（Android SDK Build Tools）
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

## 版本号管理

### 修改版本号

在 `pubspec.yaml` 中修改：

```yaml
version: 1.0.0+1
# 格式：版本名+构建号
# 版本名：1.0.0（用户可见）
# 构建号：1（内部版本号，每次发布递增）
```

或在 `android/local.properties` 中设置：

```properties
flutter.versionCode=1
flutter.versionName=1.0.0
```

## 发布检查清单

- [ ] 版本号已更新
- [ ] 已配置正式签名（如需要）
- [ ] 已测试 Release 版本
- [ ] APK/AAB 已生成
- [ ] 已检查 APK 大小
- [ ] 已验证签名信息
- [ ] 已备份密钥库文件

## 下一步

构建完成后：
1. **测试安装包**：在真实设备上测试
2. **分发**：
   - 直接分发 APK（通过网站、文件分享等）
   - 或上传到 Google Play（使用 AAB 格式）
3. **更新版本**：下次发布时更新版本号

## 参考资源

- [Flutter 构建和发布文档](https://flutter.dev/docs/deployment/android)
- [Android 应用签名](https://developer.android.com/studio/publish/app-signing)
- [Google Play 发布指南](https://developer.android.com/distribute/googleplay/start)

