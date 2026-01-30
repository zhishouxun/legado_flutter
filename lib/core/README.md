# Core 核心模块

核心模块包含应用的基础设施和通用功能。

## 目录结构

```
core/
├── constants/          # 常量定义
│   ├── app_constants.dart    # 应用常量
│   ├── app_patterns.dart     # 正则表达式模式
│   ├── app_status.dart       # 状态常量
│   └── prefer_key.dart       # 偏好设置键常量
├── exceptions/        # 异常定义
│   └── app_exceptions.dart   # 应用异常类
├── base/              # 基类
│   └── base_service.dart     # 服务基类
└── extensions/        # 扩展方法（待添加）
```

## 使用说明

### 常量

```dart
import 'package:legado_flutter/core/constants/app_constants.dart';
import 'package:legado_flutter/core/constants/app_patterns.dart';
import 'package:legado_flutter/core/constants/app_status.dart';
import 'package:legado_flutter/core/constants/prefer_key.dart';

// 使用应用常量
final timeout = AppConstants.defaultTimeout;
final cacheSize = AppConstants.defaultCacheSize;
final charsets = AppConstants.charsets;

// 使用正则表达式模式
final urlMatch = AppPatterns.urlRegex.firstMatch(text);
final jsMatch = AppPatterns.jsPattern.firstMatch(rule);

// 使用状态常量
if (status == AppStatus.play) {
  // 播放中
}

// 使用偏好设置键常量
final key = PreferKey.bookshelfLayout;
final volumeKey = PreferKey.volumeKeyPage;
```

### 异常

```dart
import 'package:legado_flutter/core/exceptions/app_exceptions.dart';

// 抛出异常
throw NetworkException('网络请求失败');
throw ParseException('解析失败', originalError: e);
```

### 基类

```dart
import 'package:legado_flutter/core/base/base_service.dart';

class MyService extends BaseService {
  @override
  Future<void> init() async {
    // 初始化逻辑
  }
  
  @override
  Future<void> dispose() async {
    // 清理逻辑
  }
}
```

