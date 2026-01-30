import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// 电子墨水模式适配的 ListView Widget
/// 在电子墨水模式下自动应用相应的样式
class EInkListView extends StatelessWidget {
  /// 子 Widget 列表
  final List<Widget> children;
  
  /// 滚动方向
  final Axis scrollDirection;
  
  /// 是否反向滚动
  final bool reverse;
  
  /// 控制器
  final ScrollController? controller;
  
  /// 是否为主轴
  final bool primary;
  
  /// 物理滚动行为
  final ScrollPhysics? physics;
  
  /// 是否收缩包装
  final bool shrinkWrap;
  
  /// 内边距
  final EdgeInsetsGeometry? padding;
  
  /// 主轴对齐方式
  final MainAxisAlignment? mainAxisAlignment;
  
  /// 交叉轴对齐方式
  final CrossAxisAlignment? crossAxisAlignment;
  
  /// 主轴大小
  final MainAxisSize mainAxisSize;
  
  /// 添加自动滚动到顶部按钮
  final bool addAutomaticKeepAlives;
  
  /// 添加语义索引
  final bool addRepaintBoundaries;
  
  /// 添加语义索引
  final bool addSemanticIndexes;
  
  /// 缓存范围
  final double? cacheExtent;
  
  /// 语义子项计数
  final int? semanticChildCount;
  
  /// 拖拽开始行为
  final DragStartBehavior dragStartBehavior;
  
  /// 键盘停靠行为
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  
  /// 恢复行为
  final String? restorationId;
  
  /// 剪裁行为
  final Clip clipBehavior;

  const EInkListView({
    super.key,
    required this.children,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary = false,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
      cacheExtent: cacheExtent,
      semanticChildCount: semanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

/// 电子墨水模式适配的 ListView.builder Widget
class EInkListViewBuilder extends StatelessWidget {
  /// 项目构建器
  final Widget Function(BuildContext context, int index) itemBuilder;
  
  /// 项目数量
  final int? itemCount;
  
  /// 滚动方向
  final Axis scrollDirection;
  
  /// 是否反向滚动
  final bool reverse;
  
  /// 控制器
  final ScrollController? controller;
  
  /// 是否为主轴
  final bool primary;
  
  /// 物理滚动行为
  final ScrollPhysics? physics;
  
  /// 是否收缩包装
  final bool shrinkWrap;
  
  /// 内边距
  final EdgeInsetsGeometry? padding;
  
  /// 添加自动滚动到顶部按钮
  final bool addAutomaticKeepAlives;
  
  /// 添加语义索引
  final bool addRepaintBoundaries;
  
  /// 添加语义索引
  final bool addSemanticIndexes;
  
  /// 缓存范围
  final double? cacheExtent;
  
  /// 语义子项计数
  final int? semanticChildCount;
  
  /// 拖拽开始行为
  final DragStartBehavior dragStartBehavior;
  
  /// 键盘停靠行为
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  
  /// 恢复行为
  final String? restorationId;
  
  /// 剪裁行为
  final Clip clipBehavior;

  const EInkListViewBuilder({
    super.key,
    required this.itemBuilder,
    this.itemCount,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary = false,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
      cacheExtent: cacheExtent,
      semanticChildCount: semanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
    );
  }
}

