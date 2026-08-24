import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

private final class NativeFileMenuController: NSObject {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  @objc func newWorkspace() { channel.invokeMethod("newWorkspace", arguments: nil) }
  @objc func openReaderSources() { channel.invokeMethod("openReaderSources", arguments: nil) }
  @objc func openWorkspace() { channel.invokeMethod("openWorkspace", arguments: nil) }
  @objc func openSampleLibrary() { channel.invokeMethod("openSampleLibrary", arguments: nil) }
  @objc func saveWorkspace() { channel.invokeMethod("saveWorkspace", arguments: nil) }
  @objc func saveWorkspaceAs() { channel.invokeMethod("saveWorkspaceAs", arguments: nil) }
  @objc func addFolder() { channel.invokeMethod("addFolder", arguments: nil) }
  @objc func addMarkdown() { channel.invokeMethod("addMarkdown", arguments: nil) }
}

class MainFlutterWindow: NSWindow {
  private var fileMenuController: NativeFileMenuController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // One title bar, not two: hide the system one and let the reading room
    // extend underneath it. The traffic lights stay; the app's own top bar
    // leaves room for them (see PlatformAdapters.topBar) and handles dragging.
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.titlebarSeparatorStyle = .none
    // An empty unified toolbar makes the title bar tall enough that the
    // traffic lights sit vertically centred in the app's top bar.
    self.toolbarStyle = .unified
    let toolbar = NSToolbar(identifier: "visualmd.chrome")
    toolbar.showsBaselineSeparator = false
    self.toolbar = toolbar
    self.minSize = NSSize(width: 720, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let commands = FlutterMethodChannel(
      name: "com.visualmd.visualmd/commands",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    let readerSourcePicker = FlutterMethodChannel(
      name: "com.visualmd.visualmd/reader-source-picker",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    readerSourcePicker.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pick", let self else {
        result(FlutterMethodNotImplemented)
        return
      }

      let panel = NSOpenPanel()
      panel.title = "Open"
      panel.prompt = "Open"
      panel.canChooseFiles = true
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = true
      panel.resolvesAliases = true
      panel.allowedContentTypes = [
        .folder,
        UTType(filenameExtension: "md"),
        UTType(filenameExtension: "markdown"),
        UTType(filenameExtension: "mdown"),
        UTType(filenameExtension: "mkd"),
      ].compactMap { $0 }

      panel.beginSheetModal(for: self) { response in
        guard response == .OK else {
          result([])
          return
        }
        result(
          panel.urls.compactMap { url -> [String: String]? in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
              return ["kind": "folder", "path": url.path]
            }
            return ["kind": "markdown", "path": url.path]
          })
      }
    }

    let atomicFiles = FlutterMethodChannel(
      name: "com.visualmd.visualmd/atomic-files",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    atomicFiles.setMethodCallHandler { call, result in
      guard let arguments = call.arguments as? [String: String] else {
        result(FlutterError(code: "argument", message: "File data is required.", details: nil))
        return
      }

      switch call.method {
      case "writeSelected":
        guard let target = arguments["target"], let contents = arguments["contents"] else {
          result(
            FlutterError(
              code: "argument", message: "A target and contents are required.", details: nil))
          return
        }
        do {
          // NSSavePanel extends the sandbox to its exact URL. Foundation owns
          // the auxiliary file used by .atomic, so no ungranted sibling path
          // crosses the Flutter boundary.
          try Data(contents.utf8).write(
            to: URL(fileURLWithPath: target),
            options: .atomic
          )
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "atomic-write",
              message: error.localizedDescription,
              details: nil
            ))
        }
      case "replace":
        guard
          let target = arguments["target"],
          let temporary = arguments["temporary"],
          let backup = arguments["backup"]
        else {
          result(FlutterError(code: "argument", message: "File paths are required.", details: nil))
          return
        }
        do {
          let manager = FileManager.default
          let targetURL = URL(fileURLWithPath: target)
          let temporaryURL = URL(fileURLWithPath: temporary)
          let backupURL = URL(fileURLWithPath: backup)
          if manager.fileExists(atPath: backup) {
            try manager.removeItem(at: backupURL)
          }
          if manager.fileExists(atPath: target) {
            _ = try manager.replaceItemAt(
              targetURL,
              withItemAt: temporaryURL,
              backupItemName: backupURL.lastPathComponent
            )
          } else {
            try manager.moveItem(at: temporaryURL, to: targetURL)
          }
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "atomic-replace",
              message: error.localizedDescription,
              details: nil
            ))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let bookmarks = FlutterMethodChannel(
      name: "com.visualmd.visualmd/bookmarks",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    bookmarks.setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "create":
          guard let path = call.arguments as? String else {
            result(FlutterError(code: "argument", message: "A path is required.", details: nil))
            return
          }
          let data = try URL(fileURLWithPath: path).bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          result(FlutterStandardTypedData(bytes: data))
        case "resolve":
          guard let typed = call.arguments as? FlutterStandardTypedData else {
            result(
              FlutterError(code: "argument", message: "Bookmark data is required.", details: nil))
            return
          }
          var stale = false
          let url = try URL(
            resolvingBookmarkData: typed.data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
          )
          let data =
            stale
            ? try url.bookmarkData(
              options: [.withSecurityScope],
              includingResourceValuesForKeys: nil,
              relativeTo: nil
            )
            : typed.data
          result([
            "path": url.path,
            "bookmark": FlutterStandardTypedData(bytes: data),
            "refreshed": stale,
          ])
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(
          FlutterError(
            code: "bookmark",
            message: error.localizedDescription,
            details: nil
          ))
      }
    }

    super.awakeFromNib()
    DispatchQueue.main.async { [weak self] in
      self?.installFileMenu(channel: commands)
    }
  }

  private func installFileMenu(channel: FlutterMethodChannel) {
    guard let mainMenu = NSApp.mainMenu else { return }
    if mainMenu.items.contains(where: { $0.title == "File" }) { return }

    let controller = NativeFileMenuController(channel: channel)
    fileMenuController = controller
    let submenu = NSMenu(title: "File")
    submenu.addItem(
      item(
        "New Workspace", key: "n", action: #selector(NativeFileMenuController.newWorkspace),
        target: controller))
    submenu.addItem(
      item(
        "Open…", key: "o", action: #selector(NativeFileMenuController.openReaderSources),
        target: controller))
    submenu.addItem(
      item(
        "Open Workspace…", key: "o", modifiers: [.command, .shift],
        action: #selector(NativeFileMenuController.openWorkspace), target: controller))
    submenu.addItem(
      item(
        "Open Sample Library", key: "o", modifiers: [.command, .option],
        action: #selector(NativeFileMenuController.openSampleLibrary), target: controller))
    submenu.addItem(.separator())
    submenu.addItem(
      item(
        "Save Workspace", key: "s", action: #selector(NativeFileMenuController.saveWorkspace),
        target: controller))
    submenu.addItem(
      item(
        "Save Workspace As…", key: "s", modifiers: [.command, .shift],
        action: #selector(NativeFileMenuController.saveWorkspaceAs), target: controller))
    submenu.addItem(.separator())
    submenu.addItem(
      item("Add Folder…", action: #selector(NativeFileMenuController.addFolder), target: controller)
    )
    submenu.addItem(
      item(
        "Add Markdown…", action: #selector(NativeFileMenuController.addMarkdown), target: controller
      ))

    let file = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
    file.submenu = submenu
    mainMenu.insertItem(file, at: min(1, mainMenu.items.count))
  }

  private func item(
    _ title: String,
    key: String = "",
    modifiers: NSEvent.ModifierFlags = [.command],
    action: Selector,
    target: AnyObject
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
    item.target = target
    return item
  }
}
