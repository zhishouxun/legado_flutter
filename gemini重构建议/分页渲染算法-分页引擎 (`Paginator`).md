这是整个阅读器最核心的“黑盒”逻辑。`Paginator` 的任务是：输入 `String content` 和 `ReaderConfig`，输出一个 `List<PageRange>`，并确保这个过程足够快，不阻塞用户操作。

为了实现高性能，我们需要将 `Paginator` 设计为一个**无状态的计算工具**，并利用 Flutter 的 `Isolate` 进行后台处理。

---

### 1. 分页引擎核心架构

### 2. 代码实现：`Paginator` 类

这个类专门负责计算。注意，我们使用了 `TextPainter` 来测量文字。

```dart
import 'package:flutter/material.dart';

class PageRange {
  final int start;
  final int end;
  PageRange(this.start, this.end);
}

class Paginator {
  final double width;
  final double height;
  final ReaderConfig config;

  Paginator({
    required this.width,
    required this.height,
    required this.config,
  });

  /// 核心分页逻辑
  List<PageRange> calculatePages(String content) {
    List<PageRange> pages = [];
    int currentStart = 0;

    // 实际可用绘制区域（扣除内边距）
    double renderWidth = width - config.padding.left - config.padding.right;
    double renderHeight = height - config.padding.top - config.padding.bottom;

    while (currentStart < content.length) {
      // 截取剩余文本进行排版测量
      final textSpan = TextSpan(
        text: content.substring(currentStart),
        style: config.textStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 100, // 给予一个足够大的行数限制
      );

      textPainter.layout(maxWidth: renderWidth);

      // 使用 getPositionForOffset 找到在该高度下能容纳的最后一个字符位置
      // 我们取左下角的坐标 (renderWidth, renderHeight)
      final endPosition = textPainter.getPositionForOffset(Offset(renderWidth, renderHeight));
      
      int pageCharCount = endPosition.offset;

      // 防止死循环：如果一个字符都装不下，强行装一个
      if (pageCharCount <= 0) pageCharCount = 1;

      int currentEnd = currentStart + pageCharCount;
      
      // 修正：确保不会超出总长度
      if (currentEnd > content.length) currentEnd = content.length;

      pages.add(PageRange(currentStart, currentEnd));
      currentStart = currentEnd;

      // 释放内存
      textPainter.dispose();
    }
    return pages;
  }
}

```

---

### 3. 高性能异步调度 (Data 层接入)

由于分页涉及大量的文本计算，直接在 UI 线程运行会导致掉帧。我们需要封装一个服务，在后台 Isolate 中运行。

```dart
class PaginationService {
  /// 在子 Isolate 中执行分页，避免卡顿
  static Future<List<PageRange>> computePages({
    required String content,
    required double width,
    required double height,
    required ReaderConfig config,
  }) async {
    // 使用 Flutter 提供的 compute 函数
    return await compute(_internalPaginate, {
      'content': content,
      'width': width,
      'height': height,
      'config': config,
    });
  }

  static List<PageRange> _internalPaginate(Map<String, dynamic> params) {
    final paginator = Paginator(
      width: params['width'],
      height: params['height'],
      config: params['config'],
    );
    return paginator.calculatePages(params['content']);
  }
}

```

---

### 4. 关键技术细节优化

#### A. 段落缩进与清洗

Legado 风格的阅读器通常需要首行缩进。

* **建议：** 在 `Paginator` 接收 `content` 之前，先进行内容清洗：
```dart
String cleanContent(String raw) {
  return raw
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .map((line) => "\u3000\u3000$line") // 添加两个全角空格
    .join('\n\n'); // 段落间距
}

```



#### B. 跨章分页连续性

当用户读到一章的最后一页，点击下一页时，我们需要：

1. 立即展示下一章的第 1 页（如果已预分页）。
2. 如果没缓存，显示加载中并异步调用 `PaginationService`。

#### C. 布局约束捕获

**坑点：** `MediaQuery.of(context).size` 获取的是屏幕尺寸，但阅读器实际区域可能被顶栏或底栏占用。

* **对策：** 使用 `LayoutBuilder` 获取阅读容器的精确 `BoxConstraints`，然后将 `constraints.maxWidth` 传给分页引擎。

---

### 5. 接下来的开发建议

现在你有了“配置模型”和“分页引擎”，你可以尝试将它们组合成一个 **`ReaderController`**。

这个 Controller 的职责将是：

1. **加载书籍内容** (从本地 Isar 数据库)。
2. **触发分页** (调用 PaginationService)。
3. **管理当前页码** (通知 UI 渲染 `PageRange` 对应的文字)。

**你想看这个 `ReaderController` 的实现，还是想了解如何利用 `CustomPainter` 高效地把这些 `PageRange` 画到屏幕上？**