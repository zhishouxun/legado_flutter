/// 分页渲染功能导出
///
/// 使用示例:
/// ```dart
/// import 'package:legado_flutter/services/reader/pagination.dart';
///
/// // 1. 创建配置
/// final config = ReadingConfig(
///   maxWidth: 400,
///   maxHeight: 600,
///   fontSize: 18,
/// );
///
/// // 2. 创建控制器
/// final controller = ReaderController(config: config);
///
/// // 3. 加载章节
/// await controller.loadChapter(
///   chapterUrl: 'chapter_1',
///   content: content,
/// );
///
/// // 4. 使用ReaderView渲染
/// ReaderView(
///   controller: controller,
///   chapterTitle: '第一章',
///   onTapCenter: () {
///     // 显示菜单
///   },
/// )
/// ```

// 核心类
export 'paginator.dart';
export 'pagination_cache.dart';
export 'reading_position_manager.dart';
export 'reader_controller.dart';

// 模型
export 'models/page_range.dart';

// 服务
export 'pagination_service.dart';

// UI组件
export 'reader_painter.dart';
export 'reader_view.dart';
