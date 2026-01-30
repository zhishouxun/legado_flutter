import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var flutterViewController: FlutterViewController?
  
  override func awakeFromNib() {
    let controller = FlutterViewController()
    self.flutterViewController = controller
    
    // iPhone 16 Pro Max 尺寸: 430 x 932 点
    let iPhone16ProMaxWidth: CGFloat = 430
    let iPhone16ProMaxHeight: CGFloat = 932
    
    // 计算窗口大小（包含标题栏等）
    let contentRect = NSRect(x: 0, y: 0, width: iPhone16ProMaxWidth, height: iPhone16ProMaxHeight)
    let windowRect = self.frameRect(forContentRect: contentRect)
    
    // 设置窗口大小和位置（居中显示）
    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      let x = screenRect.midX - windowRect.width / 2
      let y = screenRect.midY - windowRect.height / 2
      let centeredRect = NSRect(x: x, y: y, width: windowRect.width, height: windowRect.height)
      self.setFrame(centeredRect, display: true)
    } else {
      self.setFrame(windowRect, display: true)
    }
    
    // 设置最小和最大窗口大小
    self.minSize = NSSize(width: iPhone16ProMaxWidth, height: iPhone16ProMaxHeight)
    self.maxSize = NSSize(width: iPhone16ProMaxWidth * 2, height: iPhone16ProMaxHeight * 2)
    
    self.contentViewController = controller

    RegisterGeneratedPlugins(registry: controller)
    
    // 手动注册 charset_converter 插件（使用自定义实现）
    CharsetConverterPlugin.register(with: controller.registrar(forPlugin: "CharsetConverterPlugin"))

    super.awakeFromNib()
  }
  
  // 确保窗口在后台时也能继续渲染
  // 解决问题：macOS 窗口不在前台时启动页面会卡住
  override var canBecomeKey: Bool {
    return true
  }
  
  override var canBecomeMain: Bool {
    return true
  }
}
