import 'dart:async';
import 'dart:typed_data';
import '../../utils/app_log.dart';

/// 输入流数据源
/// 参考项目：io.legado.app.help.exoplayer.InputStreamDataSource
///
/// 注意：在 Flutter 中，just_audio 不支持直接使用 InputStream
/// 这个类主要用于从 Stream 读取数据，可以作为工具类使用
class InputStreamDataSource {
  final Stream<List<int>> Function() _streamSupplier;
  StreamSubscription<List<int>>? _subscription;
  StreamController<List<int>>? _controller;
  bool _opened = false;
  int _position = 0;
  int _bytesRemaining = 0;

  /// 创建输入流数据源
  /// [streamSupplier] 提供输入流的函数
  InputStreamDataSource(Stream<List<int>> Function() streamSupplier)
      : _streamSupplier = streamSupplier;

  /// 打开数据源
  /// [position] 起始位置（字节）
  /// [length] 读取长度（字节），null 表示读取到流结束
  /// 返回可用的字节数，-1 表示未知长度
  Future<int> open({int position = 0, int? length}) async {
    try {
      _position = position;
      _bytesRemaining = length ?? -1;

      // 创建控制器用于缓冲数据
      _controller = StreamController<List<int>>(
        onListen: () {
          _subscription = _streamSupplier().listen(
            (data) {
              _controller?.add(data);
            },
            onError: (error) {
              _controller?.addError(error);
            },
            onDone: () {
              _controller?.close();
            },
            cancelOnError: false,
          );
        },
        onCancel: () {
          _subscription?.cancel();
        },
      );

      _opened = true;
      return _bytesRemaining;
    } catch (e) {
      AppLog.instance.put('InputStreamDataSource.open error: $e', error: e);
      rethrow;
    }
  }

  /// 读取数据
  /// [buffer] 目标缓冲区
  /// [offset] 缓冲区偏移量
  /// [readLength] 要读取的字节数
  /// 返回实际读取的字节数，-1 表示流结束
  Future<int> read(Uint8List buffer, int offset, int readLength) async {
    if (!_opened) {
      throw StateError('DataSource not opened');
    }

    if (readLength == 0) {
      return 0;
    }

    if (_bytesRemaining == 0) {
      return -1; // 流结束
    }

    try {
      // 计算要读取的字节数
      int bytesToRead = readLength;
      if (_bytesRemaining > 0) {
        bytesToRead = bytesToRead < _bytesRemaining ? bytesToRead : _bytesRemaining;
      }

      // 从流中读取数据
      final completer = Completer<int>();
      int totalRead = 0;
      int currentOffset = offset;
      bool isCompleted = false;

      StreamSubscription<List<int>>? readSubscription;
      readSubscription = _controller!.stream.listen(
        (data) {
          if (isCompleted) return;

          int remaining = bytesToRead - totalRead;
          if (remaining <= 0) {
            readSubscription?.cancel();
            if (!completer.isCompleted) {
              isCompleted = true;
              completer.complete(totalRead);
            }
            return;
          }

          int toCopy = data.length < remaining ? data.length : remaining;
          if (toCopy > 0 && currentOffset + toCopy <= buffer.length) {
            buffer.setRange(currentOffset, currentOffset + toCopy, data, 0);
            totalRead += toCopy;
            currentOffset += toCopy;
          }

          if (totalRead >= bytesToRead) {
            readSubscription?.cancel();
            if (!completer.isCompleted) {
              isCompleted = true;
              completer.complete(totalRead);
            }
          }
        },
        onError: (error) {
          if (!isCompleted) {
            readSubscription?.cancel();
            isCompleted = true;
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          }
        },
        onDone: () {
          if (!isCompleted) {
            readSubscription?.cancel();
            isCompleted = true;
            if (!completer.isCompleted) {
              completer.complete(totalRead > 0 ? totalRead : -1);
            }
          }
        },
        cancelOnError: false,
      );

      // 设置超时
      final result = await completer.future.timeout(
        Duration(seconds: 30),
        onTimeout: () {
          if (!isCompleted) {
            readSubscription?.cancel();
            isCompleted = true;
          }
          return totalRead > 0 ? totalRead : -1;
        },
      );

      if (_bytesRemaining > 0 && result > 0) {
        _bytesRemaining -= result;
      }

      return result;
    } catch (e) {
      AppLog.instance.put('InputStreamDataSource.read error: $e', error: e);
      return -1;
    }
  }

  /// 关闭数据源
  Future<void> close() async {
    if (!_opened) {
      return;
    }

    try {
      await _subscription?.cancel();
      await _controller?.close();
      _opened = false;
      _position = 0;
      _bytesRemaining = 0;
    } catch (e) {
      AppLog.instance.put('InputStreamDataSource.close error: $e', error: e);
    }
  }

  /// 获取当前位置
  int get position => _position;

  /// 获取剩余字节数
  int get bytesRemaining => _bytesRemaining;

  /// 是否已打开
  bool get isOpened => _opened;
}

/// 从 Uint8List 创建输入流数据源
/// 参考项目：InputStreamDataSource 的使用场景
class ByteArrayDataSource extends InputStreamDataSource {
  final Uint8List _data;

  ByteArrayDataSource(this._data)
      : super(() => Stream.value(_data));

  @override
  Future<int> open({int position = 0, int? length}) async {
    if (position < 0 || position >= _data.length) {
      throw RangeError('Position out of range: $position');
    }

    final availableLength = _data.length - position;
    final readLength = length != null && length < availableLength ? length : availableLength;

    return await super.open(position: position, length: readLength);
  }
}

