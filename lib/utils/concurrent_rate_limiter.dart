import 'dart:async';
import '../data/models/book_source.dart';
import '../core/exceptions/app_exceptions.dart';
import 'app_log.dart';

/// 并发记录
/// 参考项目：AnalyzeUrl.ConcurrentRecord
class ConcurrentRecord {
  /// 是否按频率（次数/毫秒）
  final bool isConcurrent;

  /// 开始访问时间
  int time;

  /// 访问频率
  int frequency;

  ConcurrentRecord({
    required this.isConcurrent,
    required this.time,
    this.frequency = 1,
  });
}

/// 并发限流器
/// 参考项目：ConcurrentRateLimiter.kt
class ConcurrentRateLimiter {
  final BookSource? source;

  static final Map<String, ConcurrentRecord> _concurrentRecordMap = {};
  static final Object _lock = Object(); // 用于同步访问 _concurrentRecordMap

  ConcurrentRateLimiter(this.source);

  /// 开始访问,并发判断
  /// 参考项目：ConcurrentRateLimiter.fetchStart
  ConcurrentRecord? _fetchStart() {
    if (source == null) return null;

    final concurrentRate = source!.concurrentRate;
    if (concurrentRate == null ||
        concurrentRate.isEmpty ||
        concurrentRate == '0') {
      return null;
    }

    final rateIndex = concurrentRate.indexOf('/');
    final sourceKey = source!.bookSourceUrl;

    // 同步访问 Map，防止异步操作中的竞态条件
    // 注意：Dart 是单线程模型，但异步操作可能交错执行，需要确保原子性
    late ConcurrentRecord fetchRecord;
    synchronized(_lock, () {
      var record = _concurrentRecordMap[sourceKey];
      if (record == null) {
        // 创建新记录
        record = ConcurrentRecord(
          isConcurrent: rateIndex > 0,
          time: DateTime.now().millisecondsSinceEpoch,
          frequency: 1,
        );
        _concurrentRecordMap[sourceKey] = record;
      }
      fetchRecord = record;
    });

    int waitTime = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      if (!fetchRecord.isConcurrent) {
        // 并发控制非 次数/毫秒（即：毫秒数）
        if (fetchRecord.frequency > 0) {
          // 已经有访问线程,直接等待
          waitTime = int.tryParse(concurrentRate) ?? 0;
        } else {
          // 没有线程访问,判断还剩多少时间可以访问
          final nextTime =
              fetchRecord.time + (int.tryParse(concurrentRate) ?? 0);
          if (now >= nextTime) {
            fetchRecord.time = now;
            fetchRecord.frequency = 1;
            waitTime = 0;
          } else {
            waitTime = nextTime - now;
          }
        }
      } else {
        // 并发控制为 次数/毫秒
        final timePart = concurrentRate.substring(rateIndex + 1);
        final countPart = concurrentRate.substring(0, rateIndex);
        final timeMs = int.tryParse(timePart) ?? 0;
        final maxCount = int.tryParse(countPart) ?? 0;

        final nextTime = fetchRecord.time + timeMs;
        if (now >= nextTime) {
          // 已经过了限制时间,重置开始时间
          fetchRecord.time = now;
          fetchRecord.frequency = 1;
          waitTime = 0;
        } else {
          if (fetchRecord.frequency >= maxCount) {
            // 超过最大次数，需要等待
            waitTime = nextTime - now;
          } else {
            // 未超过最大次数，增加频率
            fetchRecord.frequency++;
            waitTime = 0;
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('ConcurrentRateLimiter._fetchStart error: $e');
      waitTime = 0;
    }

    if (waitTime > 0) {
      throw ConcurrentException(
        '根据并发率还需等待$waitTime毫秒才可以访问',
        waitTime: waitTime,
      );
    }

    return fetchRecord;
  }

  /// 访问结束
  /// 参考项目：ConcurrentRateLimiter.fetchEnd
  void fetchEnd(ConcurrentRecord? concurrentRecord) {
    if (concurrentRecord != null && !concurrentRecord.isConcurrent) {
      synchronized(_lock, () {
        concurrentRecord.frequency--;
        if (concurrentRecord.frequency < 0) {
          concurrentRecord.frequency = 0;
        }
      });
    }
  }

  /// 同步执行函数，确保在异步环境中的原子性
  /// 注意：Dart 是单线程模型，此函数主要用于确保代码块执行的原子性
  static void synchronized(Object lock, void Function() action) {
    action();
  }

  /// 清理不再使用的并发记录（可选，用于内存管理）
  static void cleanupUnusedRecords({Duration maxAge = const Duration(hours: 1)}) {
    synchronized(_lock, () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAgeMs = maxAge.inMilliseconds;
      final keysToRemove = <String>[];
      
      _concurrentRecordMap.forEach((key, record) {
        // 如果记录超过最大年龄且频率为0，可以清理
        if (now - record.time > maxAgeMs && record.frequency == 0) {
          keysToRemove.add(key);
        }
      });
      
      for (final key in keysToRemove) {
        _concurrentRecordMap.remove(key);
      }
    });
  }

  /// 获取并发记录，若处于并发限制状态下则会等待（异步）
  /// 参考项目：ConcurrentRateLimiter.getConcurrentRecord
  Future<ConcurrentRecord?> getConcurrentRecord() async {
    while (true) {
      try {
        return _fetchStart();
      } on ConcurrentException catch (e) {
        await Future.delayed(Duration(milliseconds: e.waitTime));
      }
    }
  }

  /// 获取并发记录，若处于并发限制状态下则会等待（阻塞）
  /// 参考项目：ConcurrentRateLimiter.getConcurrentRecordBlocking
  /// 注意：此方法会阻塞当前 isolate，建议使用异步版本 getConcurrentRecord()
  /// 警告：在 Dart 中，同步阻塞会阻塞整个 isolate，强烈不推荐使用
  @Deprecated('使用异步版本 getConcurrentRecord() 代替，避免阻塞 isolate')
  ConcurrentRecord? getConcurrentRecordBlocking() {
    // 注意：在 Dart 中无法真正实现同步阻塞而不阻塞整个 isolate
    // 此方法保留仅为兼容性，实际应该使用异步版本
    throw UnsupportedError(
      '同步阻塞方法在 Dart 中不推荐使用，请使用异步版本 getConcurrentRecord()'
    );
  }

  /// 带并发限制的执行（异步）
  /// 参考项目：ConcurrentRateLimiter.withLimit
  Future<T> withLimit<T>(Future<T> Function() block) async {
    final concurrentRecord = await getConcurrentRecord();
    try {
      return await block();
    } finally {
      fetchEnd(concurrentRecord);
    }
  }

  /// 带并发限制的执行（阻塞）
  /// 参考项目：ConcurrentRateLimiter.withLimitBlocking
  T withLimitBlocking<T>(T Function() block) {
    final concurrentRecord = getConcurrentRecordBlocking();
    try {
      return block();
    } finally {
      fetchEnd(concurrentRecord);
    }
  }
}
