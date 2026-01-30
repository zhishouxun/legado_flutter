import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import '../app_log.dart';

/// 对称加密工具类
/// 参考项目：SymmetricCryptoAndroid.kt
class SymmetricCrypto {
  final String transformation; // 如 "AES/CBC/PKCS7Padding"
  final encrypt_lib.Key? key;
  final encrypt_lib.IV? iv;

  SymmetricCrypto({
    required this.transformation,
    Uint8List? keyBytes,
    Uint8List? ivBytes,
  })  : key = keyBytes != null ? encrypt_lib.Key(keyBytes) : null,
        iv = ivBytes != null ? encrypt_lib.IV(ivBytes) : null;

  /// 设置IV
  SymmetricCrypto setIv(Uint8List ivBytes) {
    return SymmetricCrypto(
      transformation: transformation,
      keyBytes: key?.bytes,
      ivBytes: ivBytes,
    );
  }

  /// 加密（返回字节数组）
  Uint8List encrypt(String data) {
    try {
      final parts = transformation.split('/');
      final algorithm = parts.isNotEmpty ? parts[0].toUpperCase() : '';
      
      // 检查是否需要使用 pointycastle（DES/3DES）
      if (algorithm == 'DES' || algorithm == 'DESEDE' || algorithm == '3DES') {
        final dataBytes = Uint8List.fromList(utf8.encode(data));
        return _encryptWithPointyCastle(dataBytes);
      }
      
      // 使用 encrypt 包（AES）
      final encrypter = _createEncrypter();
      if (encrypter == null) {
        throw Exception('无法创建加密器: $transformation');
      }
      final encrypted = encrypter.encrypt(data, iv: iv);
      return encrypted.bytes;
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto.encrypt error: $e');
      rethrow;
    }
  }

  /// 加密（返回Base64字符串）
  String encryptBase64(String data) {
    try {
      final encrypted = encrypt(data);
      return base64Encode(encrypted);
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto.encryptBase64 error: $e');
      rethrow;
    }
  }

  /// 加密（返回十六进制字符串）
  String encryptHex(String data) {
    try {
      final encrypted = encrypt(data);
      return encrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto.encryptHex error: $e');
      rethrow;
    }
  }

  /// 解密（从字符串，自动检测Base64或Hex）
  Uint8List decrypt(String data) {
    try {
      Uint8List bytes;
      // 检测是否为十六进制
      if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(data)) {
        // 十六进制
        bytes = Uint8List.fromList(
          List.generate(data.length ~/ 2, (i) => int.parse(data.substring(i * 2, i * 2 + 2), radix: 16)),
        );
      } else {
        // Base64
        bytes = base64Decode(data);
      }
      return decryptBytes(bytes);
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto.decrypt error: $e');
      rethrow;
    }
  }

  /// 解密（从字节数组）
  Uint8List decryptBytes(Uint8List data) {
    try {
      final parts = transformation.split('/');
      final algorithm = parts.isNotEmpty ? parts[0].toUpperCase() : '';
      
      // 检查是否需要使用 pointycastle（DES/3DES）
      if (algorithm == 'DES' || algorithm == 'DESEDE' || algorithm == '3DES') {
        final decrypted = _decryptWithPointyCastle(data);
        return decrypted;
      }
      
      // 使用 encrypt 包（AES）
      final encrypter = _createEncrypter();
      if (encrypter == null) {
        throw Exception('无法创建加密器: $transformation');
      }
      final encrypted = encrypt_lib.Encrypted(data);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      return Uint8List.fromList(utf8.encode(decrypted));
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto.decryptBytes error: $e');
      rethrow;
    }
  }

  /// 解密（返回字符串）
  String decryptStr(String data) {
    try {
      final decrypted = decrypt(data);
      return utf8.decode(decrypted);
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto.decryptStr error: $e');
      rethrow;
    }
  }

  /// 创建加密器
  encrypt_lib.Encrypter? _createEncrypter() {
    try {
      // 解析 transformation，如 "AES/CBC/PKCS7Padding"
      final parts = transformation.split('/');
      if (parts.isEmpty) return null;

      final algorithm = parts[0].toUpperCase(); // AES, DES, DESede(3DES)
      
      if (key == null) {
        throw Exception('密钥不能为空');
      }

      switch (algorithm) {
        case 'AES':
          return encrypt_lib.Encrypter(encrypt_lib.AES(key!));
        case 'DES':
        case 'DESEDE':
        case '3DES':
          // 使用 pointycastle 实现 DES/3DES
          // 注意：这里返回 null，使用 _createPointyCastleEncrypter 处理
          return null;
        default:
          // 默认使用AES
          return encrypt_lib.Encrypter(encrypt_lib.AES(key!));
      }
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto._createEncrypter error: $e');
      return null;
    }
  }

  /// 使用 pointycastle 进行加密/解密（用于 DES/3DES）
  /// TODO: 需要根据实际的 pointycastle API 完善实现
  /// 当前实现：提供一个基础框架，使用 AES 作为临时替代
  Uint8List _encryptWithPointyCastle(Uint8List data) {
    try {
      // TODO: 实现真正的 DES/3DES 加密
      // 当前使用 AES 作为临时替代
      AppLog.instance.put('SymmetricCrypto: DES/3DES 加密暂未完全实现，使用 AES 作为替代');
      
      // 使用 AES 加密作为临时方案
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(key!));
      final encrypted = encrypter.encryptBytes(data, iv: iv);
      return encrypted.bytes;
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto._encryptWithPointyCastle error: $e');
      rethrow;
    }
  }

  /// 使用 pointycastle 进行解密（用于 DES/3DES）
  /// TODO: 需要根据实际的 pointycastle API 完善实现
  /// 当前实现：提供一个基础框架，使用 AES 作为临时替代
  Uint8List _decryptWithPointyCastle(Uint8List data) {
    try {
      // TODO: 实现真正的 DES/3DES 解密
      // 当前使用 AES 作为临时替代
      AppLog.instance.put('SymmetricCrypto: DES/3DES 解密暂未完全实现，使用 AES 作为替代');
      
      // 使用 AES 解密作为临时方案
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(key!));
      final encrypted = encrypt_lib.Encrypted(data);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      AppLog.instance.put('SymmetricCrypto._decryptWithPointyCastle error: $e');
      rethrow;
    }
  }

}

