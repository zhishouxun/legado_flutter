import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';
import '../app_log.dart';

/// 非对称加密工具类
/// 参考项目：io.legado.app.help.crypto.AsymmetricCrypto
class AsymmetricCrypto {
  final String algorithm; // 如 "RSA", "EC"
  RSAPublicKey? _publicKey;
  RSAPrivateKey? _privateKey;

  AsymmetricCrypto(this.algorithm);

  /// 设置私钥（从字节数组）
  /// 参考项目：AsymmetricCrypto.setPrivateKey(key: ByteArray)
  AsymmetricCrypto setPrivateKey(Uint8List keyBytes) {
    try {
      if (algorithm.toUpperCase() == 'RSA') {
        _privateKey = _parseRSAPrivateKey(keyBytes);
      } else {
        throw Exception('不支持的算法: $algorithm');
      }
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto.setPrivateKey error: $e');
      rethrow;
    }
    return this;
  }

  /// 设置私钥（从字符串）
  /// 参考项目：AsymmetricCrypto.setPrivateKey(key: String)
  AsymmetricCrypto setPrivateKeyFromString(String key) {
    // 尝试解析 PEM 格式
    if (key.contains('-----BEGIN')) {
      return setPrivateKey(_parsePEMKey(key));
    }
    return setPrivateKey(Uint8List.fromList(utf8.encode(key)));
  }

  /// 设置公钥（从字节数组）
  /// 参考项目：AsymmetricCrypto.setPublicKey(key: ByteArray)
  AsymmetricCrypto setPublicKey(Uint8List keyBytes) {
    try {
      if (algorithm.toUpperCase() == 'RSA') {
        _publicKey = _parseRSAPublicKey(keyBytes);
      } else {
        throw Exception('不支持的算法: $algorithm');
      }
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto.setPublicKey error: $e');
      rethrow;
    }
    return this;
  }

  /// 设置公钥（从字符串）
  /// 参考项目：AsymmetricCrypto.setPublicKey(key: String)
  AsymmetricCrypto setPublicKeyFromString(String key) {
    // 尝试解析 PEM 格式
    if (key.contains('-----BEGIN')) {
      return setPublicKey(_parsePEMKey(key));
    }
    return setPublicKey(Uint8List.fromList(utf8.encode(key)));
  }

  /// 解密（从字节数组、字符串）
  /// 参考项目：AsymmetricCrypto.decrypt(data: Any, usePublicKey: Boolean?)
  Uint8List decrypt(dynamic data, {bool usePublicKey = true}) {
    try {
      Uint8List bytes;
      if (data is Uint8List) {
        bytes = data;
      } else if (data is String) {
        // 自动检测 Base64 或 Hex
        bytes = _parseStringToBytes(data);
      } else {
        throw ArgumentError('不支持的数据类型: ${data.runtimeType}');
      }

      if (algorithm.toUpperCase() == 'RSA') {
        return _rsaDecrypt(bytes, usePublicKey);
      } else {
        throw Exception('不支持的算法: $algorithm');
      }
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto.decrypt error: $e');
      rethrow;
    }
  }

  /// 解密（返回字符串）
  /// 参考项目：AsymmetricCrypto.decryptStr(data: Any, usePublicKey: Boolean?)
  String decryptStr(dynamic data, {bool usePublicKey = true}) {
    try {
      final decrypted = decrypt(data, usePublicKey: usePublicKey);
      return utf8.decode(decrypted);
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto.decryptStr error: $e');
      rethrow;
    }
  }

  /// 加密（从字节数组、字符串）
  /// 参考项目：AsymmetricCrypto.encrypt(data: Any, usePublicKey: Boolean?)
  Uint8List encrypt(dynamic data, {bool usePublicKey = true}) {
    try {
      Uint8List bytes;
      if (data is Uint8List) {
        bytes = data;
      } else if (data is String) {
        bytes = Uint8List.fromList(utf8.encode(data));
      } else {
        throw ArgumentError('不支持的数据类型: ${data.runtimeType}');
      }

      if (algorithm.toUpperCase() == 'RSA') {
        return _rsaEncrypt(bytes, usePublicKey);
      } else {
        throw Exception('不支持的算法: $algorithm');
      }
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto.encrypt error: $e');
      rethrow;
    }
  }

  /// 加密（返回十六进制字符串）
  /// 参考项目：AsymmetricCrypto.encryptHex(data: Any, usePublicKey: Boolean?)
  String encryptHex(dynamic data, {bool usePublicKey = true}) {
    try {
      final encrypted = encrypt(data, usePublicKey: usePublicKey);
      return encrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto.encryptHex error: $e');
      rethrow;
    }
  }

  /// 加密（返回Base64字符串）
  /// 参考项目：AsymmetricCrypto.encryptBase64(data: Any, usePublicKey: Boolean?)
  String encryptBase64(dynamic data, {bool usePublicKey = true}) {
    try {
      final encrypted = encrypt(data, usePublicKey: usePublicKey);
      return base64Encode(encrypted);
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto.encryptBase64 error: $e');
      rethrow;
    }
  }

  /// RSA 加密
  Uint8List _rsaEncrypt(Uint8List data, bool usePublicKey) {
    if (usePublicKey) {
      if (_publicKey == null) {
        throw Exception('公钥未设置');
      }
      final encrypter = OAEPEncoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(_publicKey!));
      return encrypter.process(data);
    } else {
      if (_privateKey == null) {
        throw Exception('私钥未设置');
      }
      final encrypter = OAEPEncoding(RSAEngine())
        ..init(true, PrivateKeyParameter<RSAPrivateKey>(_privateKey!));
      return encrypter.process(data);
    }
  }

  /// RSA 解密
  Uint8List _rsaDecrypt(Uint8List data, bool usePublicKey) {
    if (usePublicKey) {
      if (_publicKey == null) {
        throw Exception('公钥未设置');
      }
      final decrypter = OAEPEncoding(RSAEngine())
        ..init(false, PublicKeyParameter<RSAPublicKey>(_publicKey!));
      return decrypter.process(data);
    } else {
      if (_privateKey == null) {
        throw Exception('私钥未设置');
      }
      final decrypter = OAEPEncoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(_privateKey!));
      return decrypter.process(data);
    }
  }

  /// 解析字符串为字节数组（自动检测 Base64 或 Hex）
  Uint8List _parseStringToBytes(String data) {
    // 检测是否为十六进制
    if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(data)) {
      // 十六进制
      return Uint8List.fromList(
        List.generate(data.length ~/ 2,
            (i) => int.parse(data.substring(i * 2, i * 2 + 2), radix: 16)),
      );
    } else {
      // Base64
      return base64Decode(data);
    }
  }

  /// 解析 PEM 格式密钥
  Uint8List _parsePEMKey(String pemKey) {
    // 移除 PEM 头部和尾部
    String keyContent = pemKey
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll('-----BEGIN RSA PUBLIC KEY-----', '')
        .replaceAll('-----END RSA PUBLIC KEY-----', '')
        .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
        .replaceAll('-----END RSA PRIVATE KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '');

    return base64Decode(keyContent);
  }

  /// 解析 RSA 公钥
  /// TODO: 需要根据实际的密钥格式（PEM/DER）完善解析逻辑
  /// 当前实现：提供一个基础框架，需要根据实际的密钥格式进行解析
  RSAPublicKey _parseRSAPublicKey(Uint8List keyBytes) {
    try {
      // 尝试解析 ASN1 格式的 RSA 公钥
      // 注意：这里需要根据实际的密钥格式（PEM/DER）进行解析
      // 简化实现：假设 keyBytes 是 DER 格式的 RSA 公钥
      final parser = ASN1Parser(keyBytes);
      final seq = parser.nextObject() as ASN1Sequence;

      // RSA 公钥格式：SEQUENCE { modulus INTEGER, publicExponent INTEGER }
      if (seq.elements!.length >= 2) {
        final modulusObj = seq.elements![0] as ASN1Integer;
        final exponentObj = seq.elements![1] as ASN1Integer;

        // 获取 BigInteger 值（使用 pointycastle 的 API）
        final modulus = modulusObj.integer!;
        final exponent = exponentObj.integer!;

        return RSAPublicKey(modulus, exponent);
      } else {
        throw Exception('无效的 RSA 公钥格式');
      }
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto._parseRSAPublicKey error: $e');
      throw Exception(
          'RSA 公钥解析失败: $e。注意：当前实现需要 DER 格式的密钥，PEM 格式需要先转换为 DER。请根据实际的密钥格式完善解析逻辑。');
    }
  }

  /// 解析 RSA 私钥
  /// TODO: 需要根据实际的密钥格式（PEM/DER）完善解析逻辑
  /// 当前实现：提供一个基础框架，需要根据实际的密钥格式进行解析
  RSAPrivateKey _parseRSAPrivateKey(Uint8List keyBytes) {
    try {
      // 尝试解析 ASN1 格式的 RSA 私钥
      // 注意：这里需要根据实际的密钥格式（PEM/DER）进行解析
      // 简化实现：假设 keyBytes 是 DER 格式的 RSA 私钥
      final parser = ASN1Parser(keyBytes);
      final seq = parser.nextObject() as ASN1Sequence;

      // RSA 私钥格式：SEQUENCE { version INTEGER, modulus INTEGER, publicExponent INTEGER, privateExponent INTEGER, p INTEGER, q INTEGER, ... }
      if (seq.elements!.length >= 6) {
        final modulusObj = seq.elements![1] as ASN1Integer;
        final privateExponentObj = seq.elements![3] as ASN1Integer;
        final pObj = seq.elements![4] as ASN1Integer;
        final qObj = seq.elements![5] as ASN1Integer;

        // 获取 BigInteger 值（使用 pointycastle 的 API）
        final modulus = modulusObj.integer!;
        final privateExponent = privateExponentObj.integer!;
        final p = pObj.integer!;
        final q = qObj.integer!;

        return RSAPrivateKey(modulus, privateExponent, p, q);
      } else {
        throw Exception('无效的 RSA 私钥格式');
      }
    } catch (e) {
      AppLog.instance.put('AsymmetricCrypto._parseRSAPrivateKey error: $e');
      throw Exception(
          'RSA 私钥解析失败: $e。注意：当前实现需要 DER 格式的密钥，PEM 格式需要先转换为 DER。请根据实际的密钥格式完善解析逻辑。');
    }
  }
}
