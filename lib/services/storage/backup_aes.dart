import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../utils/crypto/symmetric_crypto.dart';
import '../../services/local_config_service.dart';

/// 备份 AES 加密工具
/// 参考项目：io.legado.app.help.storage.BackupAES
///
/// 使用本地密码的 MD5 哈希（前16字节）作为 AES 密钥
class BackupAES {
  BackupAES._();

  /// 获取 AES 密钥（从本地密码的 MD5 哈希）
  static Uint8List _getKey() {
    final password = LocalConfigService.instance.password ?? '';
    final bytes = utf8.encode(password);
    final digest = md5.convert(bytes);
    // 取前16字节作为 AES-128 密钥
    return Uint8List.fromList(digest.bytes.take(16).toList());
  }

  /// 加密数据
  /// 参考项目：BackupAES.encrypt()
  static String encrypt(String plaintext) {
    try {
      final key = _getKey();
      final crypto = SymmetricCrypto(
        transformation: 'AES/CBC/PKCS7Padding',
        keyBytes: key,
      );
      return crypto.encryptBase64(plaintext);
    } catch (e) {
      throw Exception('备份加密失败: $e');
    }
  }

  /// 解密数据
  /// 参考项目：BackupAES.decrypt()
  static String decrypt(String ciphertext) {
    try {
      final key = _getKey();
      final crypto = SymmetricCrypto(
        transformation: 'AES/CBC/PKCS7Padding',
        keyBytes: key,
      );
      return crypto.decryptStr(ciphertext);
    } catch (e) {
      throw Exception('备份解密失败: $e');
    }
  }
}

