在 Flutter 中设计 `ReaderConfig` 时，最关键的不是定义变量，而是要确保**响应式更新**和**持久化存储**。

当用户在阅读界面调整字体大小时，底层的分页引擎（Paginator）必须实时捕获到配置变化，重新计算分页并刷新 UI。

---

### 1. 样式配置模型设计 (ReaderConfig)

我们使用 `freezed`（推荐）或简单的类来定义配置。这里包含 Legado 最核心的排版参数。

```dart
import 'package:flutter/material.dart';

class ReaderConfig {
  // 字体设置
  final double fontSize;
  final double lineHeight; // 行高倍数，如 1.5
  final String? fontFamily;
  final FontWeight fontWeight;

  // 间距设置
  final double letterSpacing;
  final double paragraphSpacing; // 段落间距
  final EdgeInsets padding;      // 屏幕四周留白

  // 颜色与主题
  final Color backgroundColor;
  final Color textColor;
  final String themeName;        // 预设主题名称：'羊皮纸', '夜间', '护眼'

  // 交互逻辑
  final bool clickToFlip;        // 点击翻页
  final bool volumeKeyFlip;     // 音量键翻页

  ReaderConfig({
    this.fontSize = 18.0,
    this.lineHeight = 1.6,
    this.fontFamily,
    this.fontWeight = FontWeight.normal,
    this.letterSpacing = 0.5,
    this.paragraphSpacing = 10.0,
    this.padding = const EdgeInsets.fromLTRB(20, 40, 20, 20),
    this.backgroundColor = const Color(0xFFF2E6D0), // 羊皮纸色
    this.textColor = const Color(0xFF2C2C2C),
    this.themeName = '默认',
    this.clickToFlip = true,
    this.volumeKeyFlip = false,
  });

  // 转换为 TextStyles 供 TextPainter 使用
  TextStyle get textStyle => TextStyle(
    fontSize: fontSize,
    height: lineHeight,
    fontFamily: fontFamily,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: textColor,
  );

  // 用于持久化存储
  Map<String, dynamic> toJson() => { ... };
}

```

---

### 2. 状态管理与响应式链路

在 Clean Architecture 中，配置属于 **Domain/Presentation** 交界处。推荐使用 `Riverpod` 来管理，因为它能轻松实现“局部刷新”。

#### A. 配置 Provider

```dart
final readerConfigProvider = StateNotifierProvider<ReaderConfigNotifier, ReaderConfig>((ref) {
  return ReaderConfigNotifier();
});

class ReaderConfigNotifier extends StateNotifier<ReaderConfig> {
  ReaderConfigNotifier() : super(ReaderConfig()) {
    _loadFromPrefs(); // 初始化时从本地读取
  }

  void updateFontSize(double newSize) {
    state = state.copyWith(fontSize: newSize);
    _saveToPrefs();
  }
  
  // 其他更新方法...
}

```

#### B. 联动分页引擎

当 `ReaderConfig` 改变时，阅读页面需要重新分页。

```dart
// 在阅读器界面监听
ref.listen<ReaderConfig>(readerConfigProvider, (previous, next) {
  if (previous?.fontSize != next.fontSize || previous?.lineHeight != next.lineHeight) {
    // 关键：配置变了，调用 Paginator 重新计算当前章
    ref.read(readerControllerProvider.notifier).rePaginate();
  }
});

```

---

### 3. 高性能渲染的“进阶细节”

1. **字体包处理：** Legado 支持自定义字体。在 Flutter 中，如果是动态下载或外部存储的 `.ttf`，你需要使用 `FontLoader` 动态加载并获取 `fontFamily` 字符串，再更新到 `ReaderConfig` 中。
2. **Edge-to-Edge 适配：** `padding` 必须考虑到手机的刘海屏（Safe Area）。建议在 `ReaderConfig` 中默认包含一个针对 `MediaQuery.of(context).padding` 的动态偏移。
3. **段落缩进：** 这是一个小坑。Flutter 的 `TextStyle` 不支持首行缩进。
* **解决方案：** 在解析章节内容时，手动在每个段落开头添加两个全角空格 `\u3000\u3000`，或者使用自定义的 `TextPainter` 渲染逻辑。



---

### 4. 接下来该做什么？

样式配置是 UI 的灵魂。有了 `ReaderConfig`，下一步就是将它应用到**渲染层**。

我们可以尝试以下两个方向之一：

* **实现 ReaderThemeSelector**：一个底部的弹出菜单，让用户滑动滑块调节字号、切换主题颜色。
* **结合 Paginator 实现完整的 ReaderView**：展示如何把 `ReaderConfig.textStyle` 传给分页算法，并最终渲染在屏幕上。

**你对哪部分更感兴趣？**