# 异步搜索系统使用指南

本指南说明如何使用Flutter版Legado的高性能异步搜索系统。

## 目录

- [系统架构](#系统架构)
- [核心组件](#核心组件)
- [快速开始](#快速开始)
- [性能优化](#性能优化)
- [常见问题](#常见问题)

---

## 系统架构

异步搜索系统采用**流式加载(Streaming)**架构,基于以下设计原则:

```
[用户输入] 
    ↓
[SearchModel] ← 搜索引擎入口
    ↓
[AsyncSearchService] ← 核心搜索服务(Stream)
    ↓
[并发控制] → [批量书源] → [NetworkService + LegadoParser]
    ↓                              ↓
[SearchResult流] ←─────────── [解析结果]
    ↓
[去重器 + 排序] → [SearchResultDeduplicator]
    ↓
[UI实时更新] ← StreamBuilder监听
```

**核心优势**:
1. **流式加载**: 搜索结果"出一个显示一个",无需等待全部完成
2. **并发控制**: 每批10个书源并发,避免服务器压力过大
3. **后台解析**: 网络请求和HTML解析不阻塞UI线程
4. **自动去重**: 避免不同书源返回相同书籍
5. **可取消**: 支持随时取消搜索,释放资源

---

## 核心组件

### 1. AsyncSearchService

高性能异步搜索服务,提供基于Stream的搜索API。

**文件**: `lib/services/book/async_search_service.dart`

**主要方法**:
```dart
class AsyncSearchService {
  /// 搜索所有书源,返回Stream流
  Stream<SearchResult> searchAllSources(
    String keyword,
    List<BookSource> sources, {
    int batchSize = 10,           // 每批并发数
    bool saveToDatabase = true,    // 是否保存到数据库
    Duration timeout = const Duration(seconds: 30),
  });
  
  /// 取消当前搜索
  void cancelSearch();
}
```

**搜索结果包装类**:
```dart
class SearchResult {
  final Book? book;             // 搜索到的书籍
  final String sourceName;      // 书源名称
  final bool isError;           // 是否出错
  final String? errorMessage;   // 错误信息
  final int respondTime;        // 响应时间(ms)
}
```

### 2. SearchModel

搜索模型,封装搜索逻辑,提供回调机制。

**文件**: `lib/services/book/search_model.dart`

**使用示例**:
```dart
final searchModel = SearchModel(
  onSearchStart: () {
    print('搜索开始');
  },
  onSearchSuccess: (books) {
    print('找到${books.length}本书');
    // 实时更新UI
  },
  onSearchFinish: (isEmpty) {
    print('搜索完成');
  },
  onSearchCancel: (error) {
    print('搜索取消或出错');
  },
);

// 开始搜索
await searchModel.search(
  searchId: 1,
  keyword: '诡秘之主',
  sources: enabledSources,
  precisionSearch: false,
);

// 取消搜索
searchModel.cancelSearch();

// 释放资源
searchModel.dispose();
```

### 3. SearchResultDeduplicator

搜索结果去重器,根据书名和作者去重。

**使用示例**:
```dart
final deduplicator = SearchResultDeduplicator();

// 添加书籍(自动去重)
if (deduplicator.addBook(book)) {
  print('新书籍: ${book.name}');
} else {
  print('重复书籍,已跳过');
}

// 获取所有去重后的书籍
final uniqueBooks = deduplicator.getAllBooks();
print('去重后共${deduplicator.count}本书');
```

---

## 快速开始

### 方式一: 使用SearchModel(推荐)

**优点**: 开箱即用,自动处理去重、排序、取消

```dart
import 'package:legado_flutter/services/book/search_model.dart';
import 'package:legado_flutter/data/models/book_source.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  SearchModel? _searchModel;
  List<Book> _results = [];
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    _initSearchModel();
  }
  
  void _initSearchModel() {
    _searchModel = SearchModel(
      onSearchStart: () {
        setState(() {
          _isSearching = true;
          _results.clear();
        });
      },
      onSearchSuccess: (books) {
        setState(() {
          _results = books;
        });
      },
      onSearchFinish: (isEmpty) {
        setState(() {
          _isSearching = false;
        });
      },
      onSearchCancel: (error) {
        setState(() {
          _isSearching = false;
        });
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('搜索出错: $error')),
          );
        }
      },
    );
  }
  
  Future<void> _performSearch(String keyword) async {
    // 获取启用的书源
    final sources = await BookSourceService.instance.getAllBookSources(
      enabledOnly: true,
    );
    
    // 开始搜索
    await _searchModel!.search(
      searchId: DateTime.now().millisecondsSinceEpoch,
      keyword: keyword,
      sources: sources,
      precisionSearch: false,
    );
  }
  
  @override
  void dispose() {
    _searchModel?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(hintText: '搜索书籍'),
          onSubmitted: _performSearch,
        ),
      ),
      body: _isSearching
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final book = _results[index];
                return ListTile(
                  title: Text(book.name),
                  subtitle: Text(book.author),
                );
              },
            ),
    );
  }
}
```

### 方式二: 直接使用AsyncSearchService

**优点**: 更灵活,可自定义处理逻辑

```dart
import 'package:legado_flutter/services/book/async_search_service.dart';

class MySearchWidget extends StatefulWidget {
  @override
  _MySearchWidgetState createState() => _MySearchWidgetState();
}

class _MySearchWidgetState extends State<MySearchWidget> {
  final AsyncSearchService _searchService = AsyncSearchService();
  final SearchResultDeduplicator _deduplicator = SearchResultDeduplicator();
  StreamSubscription<SearchResult>? _subscription;
  List<Book> _books = [];
  
  Future<void> _startSearch(String keyword, List<BookSource> sources) async {
    // 清空之前的结果
    setState(() {
      _books.clear();
    });
    _deduplicator.clear();
    
    // 订阅搜索流
    _subscription = _searchService
        .searchAllSources(
          keyword,
          sources,
          batchSize: 10,
          saveToDatabase: true,
        )
        .listen(
          (result) {
            // 忽略错误结果
            if (result.isError) {
              print('书源${result.sourceName}出错: ${result.errorMessage}');
              return;
            }
            
            // 去重并添加
            if (result.book != null && _deduplicator.addBook(result.book!)) {
              setState(() {
                _books.add(result.book!);
              });
            }
          },
          onDone: () {
            print('搜索完成,共找到${_deduplicator.count}本书');
          },
          onError: (error) {
            print('搜索出错: $error');
          },
        );
  }
  
  void _cancelSearch() {
    _subscription?.cancel();
    _searchService.cancelSearch();
  }
  
  @override
  void dispose() {
    _cancelSearch();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // UI代码...
  }
}
```

---

## 性能优化

### 1. 调整并发数量

```dart
// 网络条件好时,增加并发数
final stream = asyncSearchService.searchAllSources(
  keyword,
  sources,
  batchSize: 20, // 每批20个书源
);

// 服务器压力大时,减少并发数
final stream = asyncSearchService.searchAllSources(
  keyword,
  sources,
  batchSize: 5, // 每批5个书源
);
```

### 2. 调整超时时间

```dart
// 网络慢时,增加超时时间
final stream = asyncSearchService.searchAllSources(
  keyword,
  sources,
  timeout: const Duration(seconds: 60), // 60秒超时
);
```

### 3. 图片懒加载

搜索结果通常带有封面图,务必使用`cached_network_image`:

```dart
import 'package:cached_network_image/cached_network_image.dart';

ListTile(
  leading: CachedNetworkImage(
    imageUrl: book.coverUrl ?? '',
    placeholder: (context, url) => CircularProgressIndicator(),
    errorWidget: (context, url, error) => Icon(Icons.book),
    width: 50,
    height: 70,
    fit: BoxFit.cover,
  ),
  title: Text(book.name),
);
```

### 4. 结果分页显示

当搜索结果很多时(>100本书),建议使用虚拟滚动:

```dart
import 'package:flutter/material.dart';

ListView.builder(
  itemCount: _books.length,
  itemBuilder: (context, index) {
    final book = _books[index];
    return BookTile(book: book);
  },
  // 使用cacheExtent提升滚动性能
  cacheExtent: 500,
);
```

### 5. 数据库批量保存

虽然AsyncSearchService已经自动保存,但如果禁用了自动保存,可以手动批量保存:

```dart
// 禁用自动保存
final stream = asyncSearchService.searchAllSources(
  keyword,
  sources,
  saveToDatabase: false,
);

// 收集所有结果后批量保存
final allBooks = <SearchBook>[];
await for (final result in stream) {
  if (!result.isError && result.book != null) {
    allBooks.add(_bookToSearchBook(result.book!));
  }
}

// 批量保存
await SearchBookService.instance.saveSearchBooks(allBooks);
```

---

## 常见问题

### Q1: 如何限制搜索的书源数量?

```dart
// 只搜索前10个书源
final limitedSources = sources.take(10).toList();

await searchModel.search(
  searchId: 1,
  keyword: keyword,
  sources: limitedSources,
);
```

### Q2: 如何实现搜索进度条?

```dart
class _SearchPageState extends State<SearchPage> {
  int _searchedCount = 0;
  int _totalCount = 0;
  
  Future<void> _performSearch(String keyword) async {
    final sources = await BookSourceService.instance.getAllBookSources(
      enabledOnly: true,
    );
    
    setState(() {
      _searchedCount = 0;
      _totalCount = sources.length;
    });
    
    // 使用AsyncSearchService直接订阅
    final searchService = AsyncSearchService();
    searchService
        .searchAllSources(keyword, sources, batchSize: 10)
        .listen((result) {
      setState(() {
        _searchedCount++;
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _totalCount > 0 ? _searchedCount / _totalCount : 0,
    );
  }
}
```

### Q3: 如何在后台继续搜索?

**答**: SearchModel本身就是独立的搜索引擎,不受UI生命周期影响。即使页面被销毁,搜索任务仍会继续:

```dart
// 页面销毁时,不dispose SearchModel
@override
void dispose() {
  // 不调用 _searchModel?.dispose();
  super.dispose();
}

// 在应用级别管理SearchModel
class MyApp extends StatelessWidget {
  static final SearchModel globalSearchModel = SearchModel();
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(/* ... */);
  }
}
```

### Q4: 如何实现精确搜索?

```dart
await searchModel.search(
  searchId: 1,
  keyword: keyword,
  sources: sources,
  precisionSearch: true, // 开启精确搜索
);
```

精确搜索只返回书名或作者**完全匹配**或**包含关键词**的结果。

### Q5: 搜索结果如何排序?

SearchModel内置智能排序逻辑:

1. **完全匹配**: 书名或作者完全匹配关键词的书籍排在最前面
2. **包含关键词**: 书名或作者包含关键词的书籍排在中间
3. **其他**: 其他书籍排在最后(精确搜索模式会排除此类)

### Q6: 如何处理搜索错误?

```dart
final searchModel = SearchModel(
  onSearchCancel: (error) {
    if (error != null) {
      // 记录错误日志
      AppLog.instance.put('搜索失败', error: error);
      
      // 显示给用户
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索出错: $error')),
      );
    }
  },
);
```

### Q7: 如何统计搜索响应时间?

```dart
_searchSubscription = searchService
    .searchAllSources(keyword, sources)
    .listen((result) {
  if (!result.isError) {
    print('书源${result.sourceName}响应时间: ${result.respondTime}ms');
  }
});
```

---

## 最佳实践

### 1. 及时释放资源

```dart
@override
void dispose() {
  _searchModel?.dispose();  // 释放SearchModel
  _subscription?.cancel();  // 取消Stream订阅
  super.dispose();
}
```

### 2. 避免重复搜索

```dart
int _lastSearchId = 0;

Future<void> _performSearch(String keyword) async {
  final searchId = DateTime.now().millisecondsSinceEpoch;
  
  // 取消之前的搜索
  if (_lastSearchId != 0) {
    _searchModel?.cancelSearch();
  }
  
  _lastSearchId = searchId;
  
  await _searchModel?.search(
    searchId: searchId,
    keyword: keyword,
    sources: sources,
  );
}
```

### 3. 缓存书源列表

```dart
class SearchService {
  List<BookSource>? _cachedSources;
  DateTime? _cacheTime;
  
  Future<List<BookSource>> getEnabledSources() async {
    // 缓存5分钟
    if (_cachedSources != null && 
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < Duration(minutes: 5)) {
      return _cachedSources!;
    }
    
    _cachedSources = await BookSourceService.instance.getAllBookSources(
      enabledOnly: true,
    );
    _cacheTime = DateTime.now();
    
    return _cachedSources!;
  }
}
```

### 4. 错误重试机制

AsyncSearchService已内置重试机制(通过NetworkService的retryCount参数),默认重试1次。

---

## 参考文档

- **Gemini重构建议**: `gemini重构建议/异步搜索逻辑.md`
- **Legado解析器**: `lib/utils/parsers/LEGADO_PARSER_GUIDE.md`
- **网络服务**: `lib/services/network/network_service.dart`

---

## 更新日志

- **2026-01-30**: 初始版本,实现基于Stream的异步搜索系统
