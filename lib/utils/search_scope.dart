import '../data/models/book_source.dart';
import '../services/source/book_source_service.dart';
import '../config/app_config.dart';

/// 搜索范围管理类
/// 参考项目：io.legado.app.ui.book.search.SearchScope
class SearchScope {
  String _scope;

  SearchScope([String? scope]) : _scope = scope ?? '';

  /// 从分组列表创建
  SearchScope.fromGroups(List<String> groups) : _scope = groups.join(',');

  /// 从书源创建
  SearchScope.fromSource(BookSource source)
      : _scope = '${source.bookSourceName.replaceAll(':', '')}::${source.bookSourceUrl}';

  /// 从书源部分创建
  SearchScope.fromSourcePart(BookSource source)
      : _scope = '${source.bookSourceName.replaceAll(':', '')}::${source.bookSourceUrl}';

  /// 更新范围
  void update(String scope) {
    _scope = scope;
    _save();
  }

  /// 更新分组列表
  void updateGroups(List<String> groups) {
    _scope = groups.join(',');
    _save();
  }

  /// 更新书源
  void updateSource(BookSource source) {
    _scope = '${source.bookSourceName}::${source.bookSourceUrl}';
    _save();
  }

  /// 是否为单个书源
  bool isSource() {
    return _scope.contains('::');
  }

  /// 是否为空（全部书源）
  bool isAll() {
    return _scope.isEmpty;
  }

  /// 显示名称
  String get display {
    if (_scope.contains('::')) {
      return _scope.substringBefore('::');
    }
    if (_scope.isEmpty) {
      return '全部书源';
    }
    return _scope;
  }

  /// 显示名称列表
  List<String> get displayNames {
    final list = <String>[];
    if (_scope.contains('::')) {
      list.add(_scope.substringBefore('::'));
    } else {
      final groups = _scope.split(',').where((g) => g.trim().isNotEmpty).toList();
      list.addAll(groups);
    }
    return list;
  }

  /// 移除范围
  void remove(String scope) {
    if (isSource()) {
      _scope = '';
    } else {
      final groups = _scope.split(',');
      final newGroups = groups.where((g) => g.trim() != scope.trim()).toList();
      _scope = newGroups.join(',');
    }
    _save();
  }

  /// 获取书源列表
  Future<List<BookSource>> getBookSources() async {
    final list = <BookSource>{};
    
    if (_scope.isEmpty) {
      // 全部书源
      final allSources = await BookSourceService.instance.getAllBookSources(enabledOnly: true);
      list.addAll(allSources);
    } else if (_scope.contains('::')) {
      // 单个书源
      final url = _scope.substringAfter('::');
      final source = await BookSourceService.instance.getBookSourceByUrl(url);
      if (source != null && source.enabled) {
        list.add(source);
      }
    } else {
      // 分组
      final groups = _scope.split(',').where((g) => g.trim().isNotEmpty).toList();
      final allSources = await BookSourceService.instance.getAllBookSources(enabledOnly: true);
      
      for (final source in allSources) {
        final group = source.bookSourceGroup;
        if (group != null) {
          for (final selectedGroup in groups) {
            if (group.contains(selectedGroup.trim())) {
              list.add(source);
              break;
            }
          }
        }
      }
    }
    
    // 按自定义顺序排序
    final sortedList = list.toList();
    sortedList.sort((a, b) => a.customOrder.compareTo(b.customOrder));
    return sortedList;
  }

  /// 保存到配置
  void _save() {
    AppConfig.setSearchScope(_scope);
    if (isAll() || isSource() || _scope.contains(',')) {
      AppConfig.setSearchGroup('');
    } else {
      AppConfig.setSearchGroup(_scope);
    }
  }

  /// 从配置加载
  static Future<SearchScope> load() async {
    final scope = AppConfig.getSearchScope();
    return SearchScope(scope);
  }

  @override
  String toString() => _scope;
}

/// String扩展方法
extension StringExtension on String {
  String substringBefore(String delimiter) {
    final index = indexOf(delimiter);
    return index == -1 ? this : substring(0, index);
  }

  String substringAfter(String delimiter) {
    final index = indexOf(delimiter);
    return index == -1 ? '' : substring(index + delimiter.length);
  }
}

