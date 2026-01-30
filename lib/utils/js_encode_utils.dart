import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'crypto/symmetric_crypto.dart';
import 'crypto/asymmetric_crypto.dart';
import 'crypto/sign.dart';
import 'app_log.dart';

/// JavaScript编码工具类
/// 参考项目：JsEncodeUtils.kt
class JsEncodeUtils {
  /// MD5编码（32位）
  /// 参考项目：JsEncodeUtils.md5Encode
  static String md5Encode(String str) {
    try {
      final bytes = utf8.encode(str);
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      AppLog.instance.put('JsEncodeUtils.md5Encode error: $e');
      return '';
    }
  }

  /// MD5编码（16位）
  /// 参考项目：JsEncodeUtils.md5Encode16
  static String md5Encode16(String str) {
    try {
      final md5Str = md5Encode(str);
      return md5Str.substring(8, 24);
    } catch (e) {
      AppLog.instance.put('JsEncodeUtils.md5Encode16 error: $e');
      return '';
    }
  }

  /// 创建对称加密对象
  /// 参考项目：JsEncodeUtils.createSymmetricCrypto
  static SymmetricCrypto createSymmetricCrypto(
    String transformation, {
    Uint8List? key,
    Uint8List? iv,
  }) {
    return SymmetricCrypto(
      transformation: transformation,
      keyBytes: key,
      ivBytes: iv,
    );
  }

  /// 创建对称加密对象（从字符串key）
  static SymmetricCrypto createSymmetricCryptoFromString(
    String transformation, {
    String? key,
    String? iv,
  }) {
    return SymmetricCrypto(
      transformation: transformation,
      keyBytes: key != null ? utf8.encode(key) : null,
      ivBytes: iv != null ? utf8.encode(iv) : null,
    );
  }

  /// 生成摘要，并转为16进制字符串
  /// 参考项目：JsEncodeUtils.digestHex
  static String digestHex(String data, String algorithm) {
    try {
      final bytes = utf8.encode(data);
      Hash hash;
      
      switch (algorithm.toUpperCase()) {
        case 'MD5':
          hash = md5;
          break;
        case 'SHA1':
          hash = sha1;
          break;
        case 'SHA256':
          hash = sha256;
          break;
        case 'SHA512':
          hash = sha512;
          break;
        default:
          hash = md5; // 默认使用MD5
      }
      
      final digest = hash.convert(bytes);
      return digest.toString();
    } catch (e) {
      AppLog.instance.put('JsEncodeUtils.digestHex error: $e');
      return '';
    }
  }

  /// 生成摘要，并转为Base64字符串
  /// 参考项目：JsEncodeUtils.digestBase64Str
  static String digestBase64Str(String data, String algorithm) {
    try {
      final bytes = utf8.encode(data);
      Hash hash;
      
      switch (algorithm.toUpperCase()) {
        case 'MD5':
          hash = md5;
          break;
        case 'SHA1':
          hash = sha1;
          break;
        case 'SHA256':
          hash = sha256;
          break;
        case 'SHA512':
          hash = sha512;
          break;
        default:
          hash = md5; // 默认使用MD5
      }
      
      final digest = hash.convert(bytes);
      return base64Encode(digest.bytes);
    } catch (e) {
      AppLog.instance.put('JsEncodeUtils.digestBase64Str error: $e');
      return '';
    }
  }

  /// 生成散列消息鉴别码，并转为16进制字符串
  /// 参考项目：JsEncodeUtils.HMacHex
  static String hMacHex(String data, String algorithm, String key) {
    try {
      final keyBytes = utf8.encode(key);
      final dataBytes = utf8.encode(data);
      
      final hmac = Hmac(_getHash(algorithm), keyBytes);
      final digest = hmac.convert(dataBytes);
      return digest.toString();
    } catch (e) {
      AppLog.instance.put('JsEncodeUtils.hMacHex error: $e');
      return '';
    }
  }

  /// 生成散列消息鉴别码，并转为Base64字符串
  /// 参考项目：JsEncodeUtils.HMacBase64
  static String hMacBase64(String data, String algorithm, String key) {
    try {
      final keyBytes = utf8.encode(key);
      final dataBytes = utf8.encode(data);
      
      final hmac = Hmac(_getHash(algorithm), keyBytes);
      final digest = hmac.convert(dataBytes);
      return base64Encode(digest.bytes);
    } catch (e) {
      AppLog.instance.put('JsEncodeUtils.hMacBase64 error: $e');
      return '';
    }
  }

  /// 获取Hash算法
  static Hash _getHash(String algorithm) {
    switch (algorithm.toUpperCase()) {
      case 'MD5':
        return md5;
      case 'SHA1':
        return sha1;
      case 'SHA256':
        return sha256;
      case 'SHA512':
        return sha512;
      default:
        return md5; // 默认使用MD5
    }
  }

  /// 创建非对称加密对象
  /// 参考项目：JsEncodeUtils.createAsymmetricCrypto
  static AsymmetricCrypto createAsymmetricCrypto(String algorithm) {
    return AsymmetricCrypto(algorithm);
  }

  /// 创建签名对象
  /// 参考项目：JsEncodeUtils.createSign
  static Sign createSign(String algorithm) {
    return Sign(algorithm);
  }
}

