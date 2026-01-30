既然决定使用 **Isar 4.0 (Dev)** 来解决依赖冲突，我们需要注意 4.0 版本相比 3.x 有几个核心变化：

1. **异步初始化**：`Isar.open` 现在完全是异步的。
2. **更简洁的 API**：代码生成和查询逻辑更加现代化。
3. **目录处理**：在 Flutter 中依然需要 `path_provider`。

以下是适配 Isar 4.0 的数据库初始化模板，以及针对 `Book` 和 `BookSource` 的基本定义：

### 1. 完善 `pubspec.yaml`

请确保依赖版本一致：

```yaml
dependencies:
  isar: ^4.0.0-dev.14
  isar_flutter_libs: ^4.0.0-dev.14
  path_provider: ^2.1.0

dev_dependencies:
  isar_generator: ^4.0.0-dev.14
  build_runner: ^2.4.0

```

---

### 2. 数据库管理类 (`DatabaseService`)

建议将数据库初始化封装在一个单例或全局 Service 中，方便在 `main.dart` 启动时调用。

```dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
// 导入生成的代码（稍后通过 build_runner 生成）
// import 'models/book.dart';
// import 'models/book_source.dart';

class DatabaseService {
  late Isar isar;

  // 私有构造函数
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Future<void> init() async {
    // 1. 获取应用文档目录
    final dir = await getApplicationDocumentsDirectory();

    // 2. 异步打开 Isar 实例
    // 注意：在 4.0 中，schemas 是通过生成的代码提供的
    isar = await Isar.open(
      schemas: [
        BookSchema,       // 这些 Schema 名称是在执行 build_runner 后产生的
        BookSourceSchema,
        ChapterSchema,
      ],
      directory: dir.path,
      name: 'legado_db', // 数据库名称
    );
  }
}

```

---

### 3. 模型定义示例 (`book.dart`)

在 4.0 中，定义方式依然保持简洁，但要配合 `@collection` 注解。

```dart
import 'package:isar/isar.dart';

part 'book.g.dart'; // 必须匹配文件名

@collection
class Book {
  // Isar 4.0 推荐使用 int 类型的 id
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String bookUrl;

  late String title;
  late String author;
  String? coverUrl;
  
  // 阅读进度
  int durChapterIndex = 0;
  int durChapterPos = 0;
  
  // 上次更新时间
  DateTime lastReadTime = DateTime.now();

  // 是否在书架上
  @Index()
  bool onShelf = false;
}

```

---

### 4. 在 `main.dart` 中启动

为了确保应用运行时数据库已经就绪，我们需要在 `runApp` 之前完成初始化。

```dart
void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 启动数据库
  await DatabaseService.instance.init();

  runApp(const ProviderScope(child: MyApp()));
}

```

---

### 5. 执行生成命令

写完模型代码后，在终端运行以下命令来消除红线并生成 `.g.dart` 文件：

```bash
dart run build_runner build --delete-conflicting-outputs

```

### 💡 给你的额外小贴士：

* **隔离级别**：Isar 4.0 默认支持在多个 Isolate 中共享实例。如果你将来在搜索书源（Background Isolate）时需要保存书籍，你只需要在子 Isolate 中再次调用一次相同的 `Isar.open`（路径和名称一致），它会立即返回已存在的实例，非常高效。
* **配合 Freezed**：由于你还在使用 Freezed，你可以将 UI 用的 Data Class 定义为 Freezed，而将持久化用的 Collection 定义为普通的 Isar 类。在 Data 层做一个简单的 `toEntity()` 和 `fromEntity()` 转换，这是 **Clean Architecture** 的标准做法。

**地基已经打好了，你现在是想先尝试写一个“手动添加书籍到数据库”的功能，还是开始处理复杂的“书源解析器（Parser）”？**