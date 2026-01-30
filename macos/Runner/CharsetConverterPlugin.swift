import Cocoa
import FlutterMacOS
import Foundation

public class CharsetConverterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "charset_converter", binaryMessenger: registrar.messenger)
    let instance = CharsetConverterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "decode" {
      // charset_converter 包的 API 使用字典格式: {"charset": String, "data": Uint8List}
      guard let args = call.arguments as? [String: Any],
            let charset = args["charset"] as? String,
            let data = args["data"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments: \(String(describing: call.arguments))", details: nil))
        return
      }
      
      let bytes = data.data
      let decoded = decodeBytes(bytes, charset: charset)
      
      if let decoded = decoded {
        result(decoded)
      } else {
        result(FlutterError(code: "DECODE_ERROR", message: "Failed to decode with charset: \(charset)", details: nil))
      }
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func decodeBytes(_ bytes: Data, charset: String) -> String? {
    // 将charset名称转换为CFStringEncoding
    let cfEncoding = charsetToCFStringEncoding(charset)
    guard cfEncoding != kCFStringEncodingInvalidId else {
      return nil
    }
    
    // 使用CFStringCreateWithBytes解码
    let cfString = bytes.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> CFString? in
      guard let baseAddress = pointer.baseAddress else { return nil }
      return CFStringCreateWithBytes(
        nil,
        baseAddress.assumingMemoryBound(to: UInt8.self),
        bytes.count,
        cfEncoding,
        false
      )
    }
    
    return cfString as String?
  }
  
  private func charsetToCFStringEncoding(_ charset: String) -> CFStringEncoding {
    let lowerCharset = charset.lowercased()
    
    switch lowerCharset {
    case "gbk", "gb2312", "gb18030":
      return CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
    case "big5", "big5-hkscs":
      return CFStringEncoding(CFStringEncodings.big5.rawValue)
    case "shift-jis", "shift_jis", "sjis":
      return CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)
    case "euc-jp":
      return CFStringEncoding(CFStringEncodings.EUC_JP.rawValue)
    case "euc-kr":
      return CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)
    case "windows-1252":
      // Windows Latin-1 (CP1252) - use IANA conversion
      return CFStringConvertIANACharSetNameToEncoding("windows-1252" as CFString)
    case "windows-1250":
      // Windows Latin-2 (CP1250) - use IANA conversion
      return CFStringConvertIANACharSetNameToEncoding("windows-1250" as CFString)
    case "windows-1251":
      // Windows Cyrillic (CP1251) - use IANA conversion
      return CFStringConvertIANACharSetNameToEncoding("windows-1251" as CFString)
    default:
      // 尝试通过名称查找
      let encoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
      if encoding != kCFStringEncodingInvalidId {
        return encoding
      }
      return kCFStringEncodingInvalidId
    }
  }
}

