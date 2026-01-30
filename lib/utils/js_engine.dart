/// JavaScript引擎工具类
/// 参考项目：AnalyzeRule.evalJS 和 RhinoScriptEngine
///
/// 使用 flutter_js 包执行JavaScript代码
library;

import 'dart:convert';
import 'package:flutter_js/flutter_js.dart';

/// 函数调用回调类型
typedef JSFunctionCallback = Future<dynamic> Function(List<dynamic> args);

class JSEngine {
  static JavascriptRuntime? _runtime;
  static final Map<String, String> _scriptCache = {};
  static final Map<String, JSFunctionCallback> _functionRegistry = {};
  static int _functionIdCounter = 0;
  static bool _bridgeInitialized = false;

  /// 获取或创建JavaScript运行时
  static JavascriptRuntime getRuntime() {
    if (_runtime == null) {
      _runtime = getJavascriptRuntime();
      _bridgeInitialized = false;
    }
    return _runtime!;
  }

  /// 初始化函数桥接机制
  /// 在 JavaScript 中创建函数调用桥接，支持直接调用 Dart 函数
  static void _initFunctionBridge(JavascriptRuntime runtime) {
    if (_bridgeInitialized) return;

    // 创建函数调用桥接代码
    // 使用 Promise 来处理异步函数调用
    final bridgeCode = '''
      (function() {
        // 函数调用结果存储
        var _dartFunctionCallbacks = {};
        var _dartFunctionCallId = 0;
        
        // 创建 Promise 包装器，用于异步函数调用
        window._callDartFunction = function(functionId, args) {
          return new Promise(function(resolve, reject) {
            var callId = _dartFunctionCallId++;
            _dartFunctionCallbacks[callId] = {resolve: resolve, reject: reject};
            
            // 调用 Dart 函数（通过 evaluate 传递参数）
            // 注意：这里需要 Dart 端实现实际的调用逻辑
            try {
              // 将调用信息存储，等待 Dart 端处理
              window._pendingFunctionCalls = window._pendingFunctionCalls || [];
              window._pendingFunctionCalls.push({
                callId: callId,
                functionId: functionId,
                args: args || []
              });
              
              // 触发 Dart 端处理
              if (window._processFunctionCalls) {
                window._processFunctionCalls();
              }
            } catch (e) {
              reject(e);
            }
          });
        };
        
        // 设置函数结果（由 Dart 调用）
        window._setDartFunctionResult = function(callId, result, isError) {
          var callback = _dartFunctionCallbacks[callId];
          if (callback) {
            if (isError) {
              callback.reject(new Error(result));
            } else {
              callback.resolve(result);
            }
            delete _dartFunctionCallbacks[callId];
          }
        };
        
        // 创建函数包装器
        window._createFunctionWrapper = function(functionId, isAsync) {
          if (isAsync) {
            return function() {
              var args = Array.prototype.slice.call(arguments);
              return _callDartFunction(functionId, args);
            };
          } else {
            return function() {
              var args = Array.prototype.slice.call(arguments);
              // 同步函数直接返回（实际上异步函数无法真正同步）
              // 这里返回 Promise，调用者需要使用 await
              return _callDartFunction(functionId, args);
            };
          }
        };
      })();
    ''';

    runtime.evaluate(bridgeCode);
    _bridgeInitialized = true;
  }

  /// 注册函数到 JavaScript 环境
  /// [functionId] 函数唯一标识符
  /// [callback] Dart 函数回调
  /// [isAsync] 是否为异步函数
  static String _registerFunction(JSFunctionCallback callback, bool isAsync) {
    final functionId = 'func_${_functionIdCounter++}';
    _functionRegistry[functionId] = callback;
    return functionId;
  }

  /// 执行JavaScript代码（异步版本）
  /// 参考项目：AnalyzeRule.evalJS
  ///
  /// [jsCode] JavaScript代码
  /// [bindings] 全局对象绑定（如java, cookie, cache, source, book等）
  /// 返回执行结果
  static Future<dynamic> evalJS(
    String jsCode, {
    Map<String, dynamic>? bindings,
  }) async {
    try {
      final runtime = getRuntime();
      _initFunctionBridge(runtime);

      // 设置全局对象
      if (bindings != null) {
        for (final entry in bindings.entries) {
          await _bindValue(runtime, entry.key, entry.value);
        }
      }

      // 执行JavaScript代码（使用异步执行以支持Promise等）
      // 在执行过程中，会轮询处理函数调用
      final result = await _evaluateWithFunctionCallProcessing(runtime, jsCode);

      // 处理结果（JavascriptRuntime.evaluateAsync 返回 JsEvalResult）
      if (result.isError) {
        throw Exception('JavaScript执行错误: ${result.stringResult}');
      }

      // 获取结果字符串
      return result.stringResult;
    } catch (e) {
      throw Exception('JavaScript执行失败: $e');
    }
  }

  /// 执行 JavaScript 代码并处理函数调用
  static Future<JsEvalResult> _evaluateWithFunctionCallProcessing(
    JavascriptRuntime runtime,
    String jsCode,
  ) async {
    // 先执行代码
    var result = await runtime.evaluateAsync(jsCode);

    // 轮询处理函数调用（最多处理10次，避免无限循环）
    int maxIterations = 10;
    int iteration = 0;

    while (iteration < maxIterations) {
      await _processPendingFunctionCalls(runtime);

      // 检查是否还有待处理的调用
      final hasPendingResult = runtime.evaluate('''
        (function() {
          return window._needsFunctionCallProcessing === true;
        })();
      ''');

      if (hasPendingResult.stringResult != 'true') {
        break;
      }

      // 清除标记
      runtime.evaluate('window._needsFunctionCallProcessing = false;');

      // 等待一小段时间，让 Promise 有机会完成
      await Future.delayed(const Duration(milliseconds: 10));
      iteration++;
    }

    return result;
  }

  /// 处理待处理的函数调用
  static Future<void> _processPendingFunctionCalls(
      JavascriptRuntime runtime) async {
    try {
      // 检查是否有待处理的函数调用
      final pendingCallsResult = runtime.evaluate('''
        (function() {
          if (!window._pendingFunctionCalls || window._pendingFunctionCalls.length === 0) {
            return null;
          }
          var calls = window._pendingFunctionCalls;
          window._pendingFunctionCalls = [];
          return JSON.stringify(calls);
        })();
      ''');

      final resultStr = pendingCallsResult.stringResult;
      if (resultStr != 'null' && resultStr.isNotEmpty) {
        final pendingCalls = jsonDecode(resultStr) as List;

        for (final call in pendingCalls) {
          final callMap = call as Map<String, dynamic>;
          final callId = callMap['callId'] as int;
          final functionId = callMap['functionId'] as String;
          final args = callMap['args'] as List;

          try {
            final callback = _functionRegistry[functionId];
            if (callback != null) {
              final result = await callback(args);
              final resultJson = jsonEncode(result);
              runtime.evaluate('''
                _setDartFunctionResult($callId, JSON.parse('$resultJson'), false);
              ''');
            } else {
              runtime.evaluate('''
                _setDartFunctionResult($callId, 'Function not found: $functionId', true);
              ''');
            }
          } catch (e) {
            final errorStr = e.toString().replaceAll("'", "\\'");
            runtime.evaluate('''
              _setDartFunctionResult($callId, '$errorStr', true);
            ''');
          }
        }
      }
    } catch (e) {
      // 忽略处理错误
    }
  }

  /// 绑定值到 JavaScript 环境
  static Future<void> _bindValue(
      JavascriptRuntime runtime, String key, dynamic value) async {
    if (value is Function) {
      // 处理函数绑定
      // 判断是否为异步函数（返回 Future）
      final isAsync = true; // 假设所有函数都可能是异步的
      final functionId = _registerFunction((args) async {
        try {
          // 根据函数签名调用
          if (value is Future<dynamic> Function()) {
            return await value();
          } else if (value is Future<dynamic> Function(dynamic)) {
            return await value(args.isNotEmpty ? args[0] : null);
          } else if (value is Future<dynamic> Function(dynamic, dynamic)) {
            return await value(
              args.isNotEmpty ? args[0] : null,
              args.length > 1 ? args[1] : null,
            );
          } else if (value is Future<dynamic> Function(
              dynamic, dynamic, dynamic)) {
            return await value(
              args.isNotEmpty ? args[0] : null,
              args.length > 1 ? args[1] : null,
              args.length > 2 ? args[2] : null,
            );
          } else if (value is dynamic Function()) {
            return value();
          } else if (value is dynamic Function(dynamic)) {
            final arg = args.isNotEmpty ? args[0] : null;
            return value(arg);
          } else if (value is dynamic Function(dynamic, dynamic)) {
            return value(
              args.isNotEmpty ? args[0] : null,
              args.length > 1 ? args[1] : null,
            );
          } else if (value is dynamic Function(dynamic, dynamic, dynamic)) {
            return value(
              args.isNotEmpty ? args[0] : null,
              args.length > 1 ? args[1] : null,
              args.length > 2 ? args[2] : null,
            );
          } else {
            // 尝试直接调用
            return Function.apply(value, args);
          }
        } catch (e) {
          throw Exception('Function call error: $e');
        }
      }, isAsync);

      // 在 JavaScript 中创建函数包装器
      final escapedKey = key.replaceAll("'", "\\'");
      final wrapperCode = '''
        $escapedKey = _createFunctionWrapper('$functionId', true);
      ''';
      runtime.evaluate(wrapperCode);
    } else if (value is Map) {
      // 处理 Map 对象，递归绑定
      final escapedKey = key.replaceAll("'", "\\'");
      runtime.evaluate('var $escapedKey = {};');

      for (final entry in value.entries) {
        final escapedSubKey = entry.key.toString().replaceAll("'", "\\'");
        await _bindValue(runtime, '$escapedKey.$escapedSubKey', entry.value);
      }
    } else if (value is List) {
      // 复杂对象转换为JSON
      final jsonStr = jsonEncode(value)
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
      final escapedKey = key.replaceAll("'", "\\'");
      runtime.evaluate('var $escapedKey = JSON.parse(\'$jsonStr\');');
    } else {
      // 简单值直接设置
      final escapedValue = value
          .toString()
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\\', '\\\\');
      final escapedKey = key.replaceAll("'", "\\'");
      runtime.evaluate('var $escapedKey = \'$escapedValue\';');
    }
  }

  /// 编译并缓存脚本（参考项目：compileScriptCache）
  static String compileScriptCache(String jsCode) {
    // 简单的缓存机制
    if (_scriptCache.containsKey(jsCode)) {
      return _scriptCache[jsCode]!;
    }

    // 编译脚本（flutter_js会自动处理）
    _scriptCache[jsCode] = jsCode;
    return jsCode;
  }

  /// 清理缓存
  static void clearCache() {
    _scriptCache.clear();
    _functionRegistry.clear();
    _functionIdCounter = 0;
    _bridgeInitialized = false;
  }

  /// 释放运行时
  static void dispose() {
    _runtime?.dispose();
    _runtime = null;
    clearCache();
  }
}
