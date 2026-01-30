import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';
import '../app_log.dart';

/// 签名工具类
/// 参考项目：io.legado.app.help.crypto.Sign
class Sign {
  final String algorithm; // 如 "RSA", "EC"
  RSAPublicKey? _publicKey;
  RSAPrivateKey? _privateKey;

  Sign(this.algorithm);

  /// 设置私钥（从字节数组）
  /// 参考项目：Sign.setPrivateKey(key: ByteArray)
  Sign setPrivateKey(Uint8List keyBytes) {
    try {
      if (algorithm.toUpperCase() == 'RSA') {
        _privateKey = _parseRSAPrivateKey(keyBytes);
      } else {
        throw Exception('不支持的算法: $algorithm');
      }
    } catch (e) {
      AppLog.instance.put('Sign.setPrivateKey error: $e');
      rethrow;
    }
    return this;
  }

  /// 设置私钥（从字符串）
  /// 参考项目：Sign.setPrivateKey(key: String)
  Sign setPrivateKeyFromString(String key) {
    // 尝试解析 PEM 格式
    if (key.contains('-----BEGIN')) {
      return setPrivateKey(_parsePEMKey(key));
    }
    return setPrivateKey(Uint8List.fromList(utf8.encode(key)));
  }

  /// 设置公钥（从字节数组）
  /// 参考项目：Sign.setPublicKey(key: ByteArray)
  Sign setPublicKey(Uint8List keyBytes) {
    try {
      if (algorithm.toUpperCase() == 'RSA') {
        _publicKey = _parseRSAPublicKey(keyBytes);
      } else {
        throw Exception('不支持的算法: $algorithm');
      }
    } catch (e) {
      AppLog.instance.put('Sign.setPublicKey error: $e');
      rethrow;
    }
    return this;
  }

  /// 设置公钥（从字符串）
  /// 参考项目：Sign.setPublicKey(key: String)
  Sign setPublicKeyFromString(String key) {
    // 尝试解析 PEM 格式
    if (key.contains('-----BEGIN')) {
      return setPublicKey(_parsePEMKey(key));
    }
    return setPublicKey(Uint8List.fromList(utf8.encode(key)));
  }

  /// 签名（从字节数组、字符串）
  /// 参考项目：Sign.sign(data: Any)
  Uint8List sign(dynamic data) {
    try {
      Uint8List bytes;
      if (data is Uint8List) {
        bytes = data;
      } else if (data is String) {
        bytes = Uint8List.fromList(utf8.encode(data));
      } else {
        throw ArgumentError('不支持的数据类型: ${data.runtimeType}');
      }

      if (_privateKey == null) {
        throw Exception('私钥未设置');
      }

      if (algorithm.toUpperCase() == 'RSA') {
        return _rsaSign(bytes);
      } else {
        throw Exception('不支持的算法: $algorithm');
      }
    } catch (e) {
      AppLog.instance.put('Sign.sign error: $e');
      rethrow;
    }
  }

  /// 签名（返回十六进制字符串）
  /// 参考项目：Sign.signHex(data: Any)
  String signHex(dynamic data) {
    try {
      final signature = sign(data);
      return signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      AppLog.instance.put('Sign.signHex error: $e');
      rethrow;
    }
  }

  /// 验证签名
  /// 参考项目：Sign.verify(data: Any, signature: Any)
  bool verify(dynamic data, dynamic signature) {
    try {
      Uint8List dataBytes;
      if (data is Uint8List) {
        dataBytes = data;
      } else if (data is String) {
        dataBytes = Uint8List.fromList(utf8.encode(data));
      } else {
        throw ArgumentError('不支持的数据类型: ${data.runtimeType}');
      }

      Uint8List signatureBytes;
      if (signature is Uint8List) {
        signatureBytes = signature;
      } else if (signature is String) {
        // 自动检测 Base64 或 Hex
        signatureBytes = _parseStringToBytes(signature);
      } else {
        throw ArgumentError('不支持的签名类型: ${signature.runtimeType}');
      }

      if (_publicKey == null) {
        throw Exception('公钥未设置');
      }

      if (algorithm.toUpperCase() == 'RSA') {
        return _rsaVerify(dataBytes, signatureBytes);
      } else {
        throw Exception('不支持的算法: $algorithm');
      }
    } catch (e) {
      AppLog.instance.put('Sign.verify error: $e');
      return false;
    }
  }

  /// RSA 签名
  Uint8List _rsaSign(Uint8List data) {
    if (_privateKey == null) {
      throw Exception('私钥未设置');
    }

    // 使用 SHA-256 进行签名
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(_privateKey!));

    return signer.generateSignature(data).bytes;
  }

  /// RSA 验证签名
  bool _rsaVerify(Uint8List data, Uint8List signature) {
    if (_publicKey == null) {
      throw Exception('公钥未设置');
    }

    try {
      // 使用 SHA-256 进行验证
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
      signer.init(false, PublicKeyParameter<RSAPublicKey>(_publicKey!));

      final sig = RSASignature(signature);
      return signer.verifySignature(data, sig);
    } catch (e) {
      AppLog.instance.put('Sign._rsaVerify error: $e');
      return false;
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
      AppLog.instance.put('Sign._parseRSAPublicKey error: $e');
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
      AppLog.instance.put('Sign._parseRSAPrivateKey error: $e');
      throw Exception(
          'RSA 私钥解析失败: $e。注意：当前实现需要 DER 格式的密钥，PEM 格式需要先转换为 DER。请根据实际的密钥格式完善解析逻辑。');
    }
  }
}
