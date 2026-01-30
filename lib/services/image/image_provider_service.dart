import 'dart:typed_data';
import 'dart:io';
import '../../core/base/base_service.dart';
import '../../data/models/book.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';
import '../../config/app_config.dart';
import '../../core/constants/prefer_key.dart';
import '../../utils/helpers/book_help.dart';
import '../../utils/helpers/book_extensions.dart';
import '../book/epub_parser.dart';
import '../book/mobi/mobi_reader.dart';

/// 图片内存LRU缓存
/// 参考项目：ImageProvider.kt 中的 BitmapLruCache
class _ImageLruCache {
  final int maxSize;
  final Map<String, Uint8List> _cache = {};
  final List<String> _accessOrder = [];
  int _putCount = 0;
  int _createCount = 0;
  int _evictionCount = 0;
  int _removeCount = 0;

  _ImageLruCache(this.maxSize);

  /// 计算值的大小（字节）
  int _sizeOf(String key, Uint8List value) {
    return value.lengthInBytes;
  }

  /// 获取当前缓存大小
  int size() {
    return _cache.values.fold<int>(
      0,
      (sum, value) => sum + _sizeOf('', value),
    );
  }

  /// 获取最大缓存大小
  int getMaxSize() => maxSize;

  /// 获取缓存数量
  int count() {
    return _putCount + _createCount - _evictionCount - _removeCount;
  }

  /// 获取put次数
  int putCount() => _putCount;

  /// 获取create次数
  int createCount() => _createCount;

  /// 获取eviction次数
  int evictionCount() => _evictionCount;

  /// 获取remove次数
  int removeCount() => _removeCount;

  void put(String key, Uint8List value) {
    final valueSize = _sizeOf(key, value);

    // 如果值太大，直接返回
    if (valueSize > maxSize) {
      return;
    }

    // 移除旧值
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
      _removeCount++;
    } else {
      _putCount++;
    }

    // 检查是否需要清理空间
    int currentSize = size();

    while (currentSize + valueSize > maxSize && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeAt(0);
      final oldValue = _cache.remove(oldestKey);
      if (oldValue != null) {
        currentSize -= _sizeOf(oldestKey, oldValue);
        _evictionCount++;
      }
    }

    // 添加新值
    _cache[key] = value;
    _accessOrder.add(key);
  }

  Uint8List? get(String key) {
    if (_cache.containsKey(key)) {
      // 更新访问顺序
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return _cache[key];
    }
    return null;
  }

  Uint8List? remove(String key) {
    final value = _cache.remove(key);
    if (value != null) {
      _accessOrder.remove(key);
      _removeCount++;
    }
    return value;
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
    _putCount = 0;
    _createCount = 0;
    _evictionCount = 0;
    _removeCount = 0;
  }

  Map<String, dynamic> snapshot() {
    return {
      'size': size(),
      'maxSize': maxSize,
      'count': count(),
      'putCount': _putCount,
      'createCount': _createCount,
      'evictionCount': _evictionCount,
      'removeCount': _removeCount,
    };
  }
}

/// 图片提供器服务
/// 参考项目：io.legado.app.model.ImageProvider
class ImageProviderService extends BaseService {
  static final ImageProviderService instance = ImageProviderService._init();
  ImageProviderService._init();

  /// 获取缓存大小（MB）
  int get _cacheSizeMB {
    final size = AppConfig.getInt(PreferKey.bitmapCacheSize, defaultValue: 50);
    if (size <= 0 || size >= 2048) {
      return 50; // 默认50MB
    }
    return size;
  }

  /// 获取缓存大小（字节）
  int get _cacheSizeBytes => _cacheSizeMB * 1024 * 1024;

  /// 图片LRU缓存
  late final _ImageLruCache _imageCache = _ImageLruCache(_cacheSizeBytes);

  /// 错误图片占位符（不释放，防止重复获取）
  Uint8List? _errorImageBytes;

  /// 将图片放入缓存
  /// 参考项目：ImageProvider.put()
  void put(String key, Uint8List imageBytes) {
    try {
      // 确保缓存大小足够
      _ensureCacheSize(imageBytes);
      _imageCache.put(key, imageBytes);
    } catch (e) {
      AppLog.instance.put('图片缓存失败: $key', error: e);
    }
  }

  /// 从缓存获取图片
  /// 参考项目：ImageProvider.get()
  Uint8List? get(String key) {
    try {
      return _imageCache.get(key);
    } catch (e) {
      AppLog.instance.put('获取图片缓存失败: $key', error: e);
      return null;
    }
  }

  /// 从缓存移除图片
  /// 参考项目：ImageProvider.remove()
  Uint8List? remove(String key) {
    try {
      return _imageCache.remove(key);
    } catch (e) {
      AppLog.instance.put('移除图片缓存失败: $key', error: e);
      return null;
    }
  }

  /// 清空缓存
  void clear() {
    _imageCache.clear();
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStatistics() {
    return _imageCache.snapshot();
  }

  /// 确保缓存大小足够
  /// 参考项目：ImageProvider.ensureLruCacheSize()
  void _ensureCacheSize(Uint8List imageBytes) {
    final lruMaxSize = _imageCache.getMaxSize();
    final lruSize = _imageCache.size();
    final byteCount = imageBytes.lengthInBytes;

    int newSize = lruMaxSize;
    if (byteCount > lruMaxSize) {
      // 图片太大，需要扩大缓存
      newSize = (byteCount * 1.3).clamp(byteCount, 256 * 1024 * 1024).toInt();
    } else if (lruSize + byteCount > lruMaxSize && _imageCache.count() < 5) {
      // 缓存快满了，但图片数量少，扩大缓存
      newSize = ((lruSize + byteCount) * 1.3)
          .clamp(lruSize + byteCount, 256 * 1024 * 1024)
          .toInt();
    }

    // 注意：Flutter的LRU缓存不支持动态调整大小
    // 这里只是记录日志，实际缓存大小在创建时确定
    if (newSize > lruMaxSize) {
      AppLog.instance.put(
        '图片缓存建议大小: ${newSize ~/ 1024 ~/ 1024}MB (当前: ${lruMaxSize ~/ 1024 ~/ 1024}MB)',
      );
    }
  }

  /// 缓存图片（从文件或网络）
  /// 参考项目：ImageProvider.cacheImage()
  /// 
  /// [book] 书籍对象
  /// [src] 图片源（URL或路径）
  /// [bookSource] 书源（可选，用于网络图片）
  /// 返回图片文件路径
  Future<File> cacheImage(
    Book book,
    String src, [
    BookSource? bookSource,
  ]) async {
    try {
      // 获取图片文件路径
      final imageFile = await BookHelp.getImage(book, src);

      // 检查图片是否已存在
      if (await BookHelp.isImageExist(book, src)) {
        // 图片已存在，尝试加载到内存缓存
        await _loadImageToCache(src, imageFile);
        return imageFile;
      }

      // 图片不存在，需要获取
      Uint8List? imageBytes;

      if (book.isEpub) {
        // EPUB图片
        imageBytes = await EpubParser.getImageBytes(book, src);
      } else if (book.isMobi) {
        // MOBI图片
        try {
          final mobiBook = await MobiReader.readMobi(File(book.bookUrl));
          try {
            imageBytes = await mobiBook.getImageBytes(src);
          } finally {
            await mobiBook.close();
          }
        } catch (e) {
          AppLog.instance.put('获取MOBI图片失败: $src', error: e);
        }
      } else {
        // 网络图片
        await BookHelp.saveImage(bookSource, book, src, null);
        // 保存后重新获取文件
        if (await imageFile.exists()) {
          imageBytes = await imageFile.readAsBytes();
        }
      }

      // 如果获取到图片数据，保存到文件并缓存
      if (imageBytes != null) {
        await imageFile.writeAsBytes(imageBytes);
        // 放入内存缓存
        put(src, imageBytes);
      }

      return imageFile;
    } catch (e) {
      AppLog.instance.put('缓存图片失败: $src', error: e);
      rethrow;
    }
  }

  /// 从文件加载图片到缓存
  Future<void> _loadImageToCache(String key, File imageFile) async {
    try {
      if (await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        put(key, bytes);
      }
    } catch (e) {
      // 忽略加载失败
    }
  }

  /// 获取图片字节数组（优先从缓存）
  /// 参考项目：ImageProvider.getBitmap()
  /// 
  /// [book] 书籍对象
  /// [src] 图片源
  /// [bookSource] 书源（可选）
  /// 返回图片字节数组，如果获取失败返回null
  Future<Uint8List?> getImageBytes(
    Book book,
    String src, [
    BookSource? bookSource,
  ]) async {
    try {
      // 先从内存缓存获取
      final cachedBytes = get(src);
      if (cachedBytes != null) {
        return cachedBytes;
      }

      // 缓存中没有，从文件获取
      final imageFile = await BookHelp.getImage(book, src);
      if (await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        // 放入缓存
        put(src, bytes);
        return bytes;
      }

      // 文件也不存在，尝试获取
      return await _fetchImageBytes(book, src, bookSource);
    } catch (e) {
      AppLog.instance.put('获取图片失败: $src', error: e);
      return null;
    }
  }

  /// 获取图片字节数组（内部方法）
  Future<Uint8List?> _fetchImageBytes(
    Book book,
    String src,
    BookSource? bookSource,
  ) async {
    try {
      if (book.isEpub) {
        return await EpubParser.getImageBytes(book, src);
      } else if (book.isMobi) {
        final mobiBook = await MobiReader.readMobi(File(book.bookUrl));
        try {
          return await mobiBook.getImageBytes(src);
        } finally {
          await mobiBook.close();
        }
      } else if (bookSource != null) {
        // 网络图片
        await BookHelp.saveImage(bookSource, book, src, null);
        final imageFile = await BookHelp.getImage(book, src);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          // 放入缓存
          put(src, bytes);
          return bytes;
        }
      }
    } catch (e) {
      AppLog.instance.put('获取图片数据失败: $src', error: e);
    }
    return null;
  }

  /// 获取错误图片占位符
  /// 参考项目：ImageProvider.errorBitmap
  Future<Uint8List> getErrorImageBytes() async {
    if (_errorImageBytes != null) {
      return _errorImageBytes!;
    }

    try {
      // 使用Flutter的占位图片
      // 这里可以加载一个默认的错误图片
      // 暂时返回空字节数组，实际使用时应该加载一个占位图片
      _errorImageBytes = Uint8List(0);
      return _errorImageBytes!;
    } catch (e) {
      AppLog.instance.put('获取错误图片失败', error: e);
      return Uint8List(0);
    }
  }

  /// 预加载图片到缓存
  /// [book] 书籍对象
  /// [srcs] 图片源列表
  /// [bookSource] 书源（可选）
  Future<void> preloadImages(
    Book book,
    List<String> srcs, [
    BookSource? bookSource,
  ]) async {
    for (final src in srcs) {
      try {
        // 检查是否已在缓存中
        if (get(src) != null) {
          continue;
        }

        // 异步加载，不等待完成
        cacheImage(book, src, bookSource).catchError((e) {
          AppLog.instance.put('预加载图片失败: $src', error: e);
          return File(''); // 返回空文件占位
        });
      } catch (e) {
        AppLog.instance.put('预加载图片失败: $src', error: e);
      }
    }
  }
}

