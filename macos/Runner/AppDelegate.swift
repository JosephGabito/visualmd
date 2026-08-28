import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var pendingOpenFiles: [String] = []

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    let accepted = deliverOpenFiles(filenames)
    if !accepted {
      pendingOpenFiles.append(contentsOf: filenames)
    }
    mainFlutterWindow?.makeKeyAndOrderFront(self)
    sender.activate(ignoringOtherApps: true)
    sender.reply(toOpenOrPrint: .success)
  }

  func takePendingOpenFiles() -> [String] {
    let files = pendingOpenFiles
    pendingOpenFiles.removeAll()
    return files
  }

  private func deliverOpenFiles(_ filenames: [String]) -> Bool {
    guard let window = mainFlutterWindow as? MainFlutterWindow else { return false }
    return window.deliverOpenFiles(filenames)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      mainFlutterWindow?.makeKeyAndOrderFront(self)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
