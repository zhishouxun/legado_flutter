# defaultData 目录说明

## 目录作用

`assets/defaultData` 目录包含了应用的默认数据文件，这些文件在首次使用或版本升级时会被导入到数据库中。

## 文件列表

### 1. bookSources.json
- **用途**: 默认书源列表
- **使用位置**: 书源导入功能
- **状态**: ✅ 已实现（通过书源导入功能）

### 2. coverRule.json
- **用途**: 封面搜索规则配置
- **使用位置**: `CoverSearchService.searchCover()`
- **状态**: ✅ 已实现（CoverSearchService 会优先使用封面规则搜索，失败时回退到默认搜索）
- **参考项目**: `BookCover.kt` 的 `getConfig()` 方法

### 3. dictRules.json
- **用途**: 默认字典规则列表
- **使用位置**: `DictRuleService.importDefaultRules()`
- **状态**: ✅ 已实现（从 assets 加载）

### 4. directLinkUpload.json
- **用途**: 直链上传规则配置
- **使用位置**: `DirectLinkUploadService.uploadFile()`
- **状态**: ✅ 已实现（通过 DirectLinkUploadService 服务使用）
- **参考项目**: `DirectLinkUpload.kt`

### 5. httpTTS.json
- **用途**: 默认 HTTP TTS 配置列表
- **使用位置**: `HttpTTSService.importDefaultHttpTTS()`
- **状态**: ✅ 已实现（从 assets 加载）

### 6. keyboardAssists.json
- **用途**: 默认键盘辅助配置列表
- **使用位置**: `KeyboardAssistService.importDefaultKeyboardAssists()`
- **状态**: ✅ 已实现（在版本升级时自动导入）

### 7. readConfig.json
- **用途**: 默认阅读配置列表
- **使用位置**: `ReadConfigService.getPresetConfigs()`
- **状态**: ✅ 已实现（通过 ReadConfigService 服务管理预设配置）
- **参考项目**: `ReadBookConfig.kt` 的 `readConfigs` 属性

### 8. rssSources.json
- **用途**: 默认 RSS 源列表
- **使用位置**: `RssService.importDefaultRssSources()`
- **状态**: ✅ 已实现（从 assets 加载）

### 9. themeConfig.json
- **用途**: 默认主题配置列表
- **使用位置**: `ThemeService.loadConfigs()`
- **状态**: ✅ 已实现（从 assets 加载）

### 10. txtTocRule.json
- **用途**: 默认 TXT 目录规则列表
- **使用位置**: `TxtTocRuleService.importDefaultRules()`
- **状态**: ✅ 已实现（从 assets 加载）

## 实现状态总结

### ✅ 已完全实现
1. **dictRules.json** - 字典规则默认数据
2. **txtTocRule.json** - TXT 目录规则默认数据
3. **themeConfig.json** - 主题配置默认数据
4. **httpTTS.json** - HTTP TTS 配置默认数据
5. **rssSources.json** - RSS 源默认数据
6. **keyboardAssists.json** - 键盘辅助默认数据
7. **coverRule.json** - 封面搜索规则配置
8. **readConfig.json** - 阅读配置预设
9. **directLinkUpload.json** - 直链上传规则
10. **bookSources.json** - 默认书源（首次启动时自动导入）

### ✅ 已完全实现（新增）
1. **coverRule.json** - 封面规则（CoverSearchService 已使用）
2. **readConfig.json** - 阅读配置（ReadConfigService 已使用）
3. **directLinkUpload.json** - 直链上传规则（DirectLinkUploadService 已使用）

### ✅ 已完全实现（新增）
1. **bookSources.json** - 默认书源（首次启动时自动导入，如果数据库中没有书源）

## 使用方式

### DefaultData 工具类
所有默认数据都通过 `DefaultData` 工具类加载：

```dart
// 获取默认数据
final httpTTS = await DefaultData.instance.httpTTS;
final dictRules = await DefaultData.instance.dictRules;
final themeConfigs = await DefaultData.instance.themeConfigs;
// ... 等等
```

### 版本升级时自动导入
在 `main.dart` 中调用 `DefaultData.instance.upVersion()` 来检查版本升级并导入默认数据。

### 手动导入
各个服务提供了导入方法：
- `DictRuleService.importDefaultRules()`
- `TxtTocRuleService.importDefaultRules()`
- `HttpTTSService.importDefaultHttpTTS()`
- `RssService.importDefaultRssSources()`
- `KeyboardAssistService.importDefaultKeyboardAssists()`
- `DefaultData.importDefaultBookSources()` - 导入默认书源
- `ReadConfigService.importDefaultPresets()` - 导入默认阅读配置预设

### 服务使用
- `CoverSearchService.searchCover()` - 使用 coverRule.json 配置进行封面搜索
- `ReadConfigService.getPresetConfigs()` - 获取所有阅读配置预设
- `DirectLinkUploadService.uploadFile()` - 使用 directLinkUpload.json 规则上传文件

## 参考项目实现

参考项目中的 `DefaultData.kt` 提供了：
- 所有默认数据的 lazy 属性
- `upVersion()` 方法用于版本升级时导入
- 各个导入方法（`importDefaultHttpTTS()`, `importDefaultTocRules()` 等）

## 注意事项

1. **默认数据标识**：
   - HttpTTS: id < 0 为默认数据
   - TxtTocRule: id < 0 为默认数据
   - RssSource: sourceGroup like 'legado' 为默认数据

2. **版本升级**：需要在 `main.dart` 中调用 `upVersion()` 来检查版本并导入默认数据

3. **数据库初始化**：keyboardAssists 表在创建时会自动导入默认数据（通过版本升级检查）

