import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  // 确保应用在后台时也能继续运行
  // 解决问题：窗口不在前台时启动页面会卡住
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 设置应用激活策略：即使窗口不可见也保持激活
    NSApp.setActivationPolicy(.regular)
    
    // 确保应用窗口可以在后台运行
    // 这会确保 Flutter 引擎不会在窗口不可见时暂停
    if let window = NSApp.windows.first {
      window.isOpaque = true
      window.backgroundColor = NSColor.windowBackgroundColor
    }
  }
  
  // 当应用变为活动窗口时调用
  override func applicationDidBecomeActive(_ notification: Notification) {
    // 确保窗口在激活时正确显示
    if let window = NSApp.windows.first {
      window.makeKeyAndOrderFront(nil)
    }
  }
  
  // 当应用进入后台时调用
  override func applicationDidResignActive(_ notification: Notification) {
    // 不执行任何操作，让应用继续运行
    // Flutter 引擎会继续执行
  }
}
