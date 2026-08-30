import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

private struct NativeReaderState {
  let documentTitle: String?
  let hasLibrary: Bool
  let hasDocument: Bool
  let hasOutline: Bool
  let canCopy: Bool
  let canIncreaseText: Bool
  let canDecreaseText: Bool
  let canResetText: Bool
  let shelfVisible: Bool
  let outlineVisible: Bool

  static let empty = NativeReaderState(
    documentTitle: nil,
    hasLibrary: false,
    hasDocument: false,
    hasOutline: false,
    canCopy: false,
    canIncreaseText: false,
    canDecreaseText: false,
    canResetText: false,
    shelfVisible: true,
    outlineVisible: true
  )

  init?(arguments: Any?) {
    guard
      let values = arguments as? [String: Any],
      let hasLibrary = values["hasLibrary"] as? Bool,
      let hasDocument = values["hasDocument"] as? Bool,
      let hasOutline = values["hasOutline"] as? Bool,
      let canCopy = values["canCopy"] as? Bool,
      let canIncreaseText = values["canIncreaseText"] as? Bool,
      let canDecreaseText = values["canDecreaseText"] as? Bool,
      let canResetText = values["canResetText"] as? Bool,
      let shelfVisible = values["shelfVisible"] as? Bool,
      let outlineVisible = values["outlineVisible"] as? Bool
    else { return nil }
    self.documentTitle = values["documentTitle"] as? String
    self.hasLibrary = hasLibrary
    self.hasDocument = hasDocument
    self.hasOutline = hasOutline
    self.canCopy = canCopy
    self.canIncreaseText = canIncreaseText
    self.canDecreaseText = canDecreaseText
    self.canResetText = canResetText
    self.shelfVisible = shelfVisible
    self.outlineVisible = outlineVisible
  }

  private init(
    documentTitle: String?,
    hasLibrary: Bool,
    hasDocument: Bool,
    hasOutline: Bool,
    canCopy: Bool,
    canIncreaseText: Bool,
    canDecreaseText: Bool,
    canResetText: Bool,
    shelfVisible: Bool,
    outlineVisible: Bool
  ) {
    self.documentTitle = documentTitle
    self.hasLibrary = hasLibrary
    self.hasDocument = hasDocument
    self.hasOutline = hasOutline
    self.canCopy = canCopy
    self.canIncreaseText = canIncreaseText
    self.canDecreaseText = canDecreaseText
    self.canResetText = canResetText
    self.shelfVisible = shelfVisible
    self.outlineVisible = outlineVisible
  }
}

private final class NativeMenuController: NSObject, NSMenuItemValidation {
  private let channel: FlutterMethodChannel
  private var state = NativeReaderState.empty
  weak var shelfItem: NSMenuItem?
  weak var outlineItem: NSMenuItem?

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
  @objc func openAppearance() { channel.invokeMethod("openAppearance", arguments: nil) }
  @objc func findDocument() { channel.invokeMethod("findDocument", arguments: nil) }
  @objc func searchLibrary() { channel.invokeMethod("searchLibrary", arguments: nil) }
  @objc func toggleShelf() { channel.invokeMethod("toggleShelf", arguments: nil) }
  @objc func toggleOutline() { channel.invokeMethod("toggleOutline", arguments: nil) }
  @objc func copySelection() { channel.invokeMethod("copySelection", arguments: nil) }
  @objc func selectAllText() { channel.invokeMethod("selectAllText", arguments: nil) }
  @objc func enlargeText() { channel.invokeMethod("enlargeText", arguments: nil) }
  @objc func shrinkText() { channel.invokeMethod("shrinkText", arguments: nil) }
  @objc func resetText() { channel.invokeMethod("resetText", arguments: nil) }
  @objc func showKeyboardShortcuts() {
    channel.invokeMethod("showKeyboardShortcuts", arguments: nil)
  }
  @objc func openSupport() { channel.invokeMethod("openSupport", arguments: nil) }
  @objc func openPrivacy() { channel.invokeMethod("openPrivacy", arguments: nil) }
  @objc func showLicenses() { channel.invokeMethod("showLicenses", arguments: nil) }

  @objc func closeWindow() { NSApp.keyWindow?.performClose(nil) }

  func update(_ state: NativeReaderState) {
    self.state = state
    shelfItem?.state = state.shelfVisible ? .on : .off
    outlineItem?.state = state.outlineVisible && state.hasOutline ? .on : .off
  }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    switch menuItem.action {
    case #selector(saveWorkspace), #selector(saveWorkspaceAs),
      #selector(searchLibrary), #selector(toggleShelf):
      return state.hasLibrary
    case #selector(toggleOutline):
      return state.hasOutline
    case #selector(copySelection):
      return state.canCopy
    case #selector(selectAllText), #selector(findDocument):
      return state.hasDocument
    case #selector(enlargeText):
      return state.canIncreaseText
    case #selector(shrinkText):
      return state.canDecreaseText
    case #selector(resetText):
      return state.canResetText
    default:
      return true
    }
  }
}

class MainFlutterWindow: NSWindow {
  private var nativeMenuController: NativeMenuController?
  private var externalOpenItems: FlutterMethodChannel?
  private var externalOpenItemsReady = false
  private var nativeReaderState = NativeReaderState.empty

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
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(hideToolbarForFullScreen(_:)),
      name: NSWindow.willEnterFullScreenNotification,
      object: self
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(restoreToolbarAfterFullScreen(_:)),
      name: NSWindow.willExitFullScreenNotification,
      object: self
    )
    self.minSize = NSSize(width: 720, height: 480)
    // AppKit restores a saved frame when the autosave name is assigned and
    // keeps it current as the user moves or resizes the window. When no saved
    // frame exists, the 1280 x 800 frame supplied by MainMenu.xib remains the
    // first-launch default.
    _ = self.setFrameAutosaveName("visualmd.main-window")

    #if DEBUG
      if ProcessInfo.processInfo.environment["VISUAL_MD_UI_TEST_PROFILE"] != nil,
        let rawWidth = ProcessInfo.processInfo.environment["VISUAL_MD_UI_TEST_WINDOW_WIDTH"],
        let width = Double(rawWidth),
        let screen = NSScreen.main
      {
        let size = NSSize(width: min(max(width, 720), 1_800), height: 800)
        let origin = NSPoint(
          x: screen.visibleFrame.midX - size.width / 2,
          y: screen.visibleFrame.midY - size.height / 2
        )
        self.setFrame(NSRect(origin: origin, size: size), display: true)
      }
    #endif

    RegisterGeneratedPlugins(registry: flutterViewController)

    #if DEBUG
      if ProcessInfo.processInfo.environment["VISUAL_MD_UI_TEST_PROFILE"] != nil {
        // Flutter normally creates its semantics tree when macOS announces an
        // assistive-technology client. XCTest does not reliably make that
        // announcement for Flutter's virtual view, so debug UI-test launches
        // explicitly enable the same engine bridge. This code is absent from
        // the Release binary submitted to the App Store.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          flutterViewController.engine.setValue(true, forKey: "semanticsEnabled")
        }
      }
    #endif

    let commands = FlutterMethodChannel(
      name: "com.visualmd.visualmd/commands",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    commands.setMethodCallHandler { [weak self] call, result in
      guard call.method == "updateReaderState" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let state = NativeReaderState(arguments: call.arguments), let self else {
        result(
          FlutterError(
            code: "argument", message: "Complete reader state is required.", details: nil))
        return
      }
      self.nativeReaderState = state
      if let documentTitle = state.documentTitle, !documentTitle.isEmpty {
        self.title = documentTitle
      } else {
        self.title = "Visual MD"
      }
      self.nativeMenuController?.update(state)
      result(nil)
    }

    let externalOpenItems = FlutterMethodChannel(
      name: "com.visualmd.visualmd/external-open-items",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    self.externalOpenItems = externalOpenItems
    externalOpenItems.setMethodCallHandler { [weak self] call, result in
      guard call.method == "ready", let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.externalOpenItemsReady = true
      if let appDelegate = NSApp.delegate as? AppDelegate {
        _ = self.deliverOpenFiles(appDelegate.takePendingOpenFiles())
      }
      result(nil)
    }

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
      self?.installNativeMenus(channel: commands)
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  /// Delivers Finder requests only after Dart has installed its receiver.
  /// AppDelegate retains cold-launch requests until this method returns true.
  func deliverOpenFiles(_ filenames: [String]) -> Bool {
    guard externalOpenItemsReady, let externalOpenItems else { return false }
    let records = filenames.map { path -> [String: Any] in
      let url = URL(fileURLWithPath: path)
      var record: [String: Any] = ["path": path]
      if let bookmark = try? url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      ) {
        record["bookmark"] = FlutterStandardTypedData(bytes: bookmark)
      }
      return record
    }
    if !records.isEmpty {
      externalOpenItems.invokeMethod("open", arguments: records)
    }
    return true
  }

  @objc private func hideToolbarForFullScreen(_ notification: Notification) {
    // The empty toolbar exists only to centre the traffic lights in a normal
    // window. Fullscreen has no persistent traffic lights; keeping the toolbar
    // would cover the Flutter top bar with an empty native strip.
    toolbar?.isVisible = false
  }

  @objc private func restoreToolbarAfterFullScreen(_ notification: Notification) {
    toolbar?.isVisible = true
  }

  private func installNativeMenus(channel: FlutterMethodChannel) {
    guard let mainMenu = NSApp.mainMenu else { return }
    let controller = NativeMenuController(channel: channel)
    nativeMenuController = controller

    installApplicationMenu(in: mainMenu, controller: controller)
    installFileMenu(in: mainMenu, controller: controller)
    installEditMenu(in: mainMenu, controller: controller)
    installViewMenu(in: mainMenu, controller: controller)
    installHelpMenu(in: mainMenu, controller: controller)
    controller.update(nativeReaderState)
  }

  private func installApplicationMenu(
    in mainMenu: NSMenu,
    controller: NativeMenuController
  ) {
    guard let submenu = mainMenu.items.first?.submenu else { return }
    let oldSettings = submenu.items.first {
      $0.title == "Preferences…" || $0.title == "Settings…"
    }
    oldSettings?.title = "Settings…"
    oldSettings?.target = controller
    oldSettings?.action = #selector(NativeMenuController.openAppearance)
  }

  private func installFileMenu(
    in mainMenu: NSMenu,
    controller: NativeMenuController
  ) {
    if mainMenu.items.contains(where: { $0.title == "File" }) { return }
    let submenu = NSMenu(title: "File")
    submenu.addItem(
      item(
        "New Workspace", key: "n", action: #selector(NativeMenuController.newWorkspace),
        target: controller))
    submenu.addItem(
      item(
        "Open…", key: "o", action: #selector(NativeMenuController.openReaderSources),
        target: controller))
    submenu.addItem(
      item(
        "Open Workspace…", key: "o", modifiers: [.command, .shift],
        action: #selector(NativeMenuController.openWorkspace), target: controller))
    submenu.addItem(
      item(
        "Open Sample Library", key: "o", modifiers: [.command, .option],
        action: #selector(NativeMenuController.openSampleLibrary), target: controller))
    submenu.addItem(.separator())
    submenu.addItem(
      item(
        "Save Workspace", key: "s", action: #selector(NativeMenuController.saveWorkspace),
        target: controller))
    submenu.addItem(
      item(
        "Save Workspace As…", key: "s", modifiers: [.command, .shift],
        action: #selector(NativeMenuController.saveWorkspaceAs), target: controller))
    submenu.addItem(.separator())
    submenu.addItem(
      item("Add Folder…", action: #selector(NativeMenuController.addFolder), target: controller)
    )
    submenu.addItem(
      item(
        "Add Markdown…", action: #selector(NativeMenuController.addMarkdown), target: controller
      ))
    submenu.addItem(.separator())
    submenu.addItem(
      item(
        "Close Window", key: "w", action: #selector(NativeMenuController.closeWindow),
        target: controller))

    let file = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
    file.submenu = submenu
    mainMenu.insertItem(file, at: min(1, mainMenu.items.count))
  }

  private func installEditMenu(
    in mainMenu: NSMenu,
    controller: NativeMenuController
  ) {
    let submenu = ensureMenu(named: "Edit", in: mainMenu, at: 2)
    submenu.removeAllItems()
    submenu.addItem(
      item(
        "Copy", key: "c", action: #selector(NativeMenuController.copySelection),
        target: controller))
    submenu.addItem(
      item(
        "Select All", key: "a", action: #selector(NativeMenuController.selectAllText),
        target: controller))
    submenu.addItem(.separator())
    submenu.addItem(
      item(
        "Find in Document…", key: "f", action: #selector(NativeMenuController.findDocument),
        target: controller))
    submenu.addItem(
      item(
        "Search Library…", key: "f", modifiers: [.command, .shift],
        action: #selector(NativeMenuController.searchLibrary), target: controller))
  }

  private func installViewMenu(
    in mainMenu: NSMenu,
    controller: NativeMenuController
  ) {
    let submenu = ensureMenu(named: "View", in: mainMenu, at: 3)
    submenu.removeAllItems()
    let shelfItem = item(
      "Shelf", key: "b", action: #selector(NativeMenuController.toggleShelf),
      target: controller)
    controller.shelfItem = shelfItem
    submenu.addItem(shelfItem)
    let outlineItem = item(
      "Outline", key: "b", modifiers: [.command, .shift],
      action: #selector(NativeMenuController.toggleOutline), target: controller)
    controller.outlineItem = outlineItem
    submenu.addItem(outlineItem)
    submenu.addItem(.separator())
    submenu.addItem(
      item(
        "Increase Text Size", key: "+", action: #selector(NativeMenuController.enlargeText),
        target: controller))
    submenu.addItem(
      item(
        "Decrease Text Size", key: "-", action: #selector(NativeMenuController.shrinkText),
        target: controller))
    submenu.addItem(
      item(
        "Actual Size", key: "0", action: #selector(NativeMenuController.resetText),
        target: controller))
    submenu.addItem(.separator())
    submenu.addItem(
      item(
        "Enter Full Screen", key: "f", modifiers: [.command, .control],
        action: #selector(NSWindow.toggleFullScreen(_:)), target: nil))
  }

  private func installHelpMenu(
    in mainMenu: NSMenu,
    controller: NativeMenuController
  ) {
    let submenu = ensureMenu(named: "Help", in: mainMenu, at: mainMenu.items.count)
    NSApp.helpMenu = submenu
    submenu.removeAllItems()
    submenu.addItem(
      item(
        "Keyboard Shortcuts", action: #selector(NativeMenuController.showKeyboardShortcuts),
        target: controller))
    submenu.addItem(.separator())
    submenu.addItem(
      item("Support", action: #selector(NativeMenuController.openSupport), target: controller))
    submenu.addItem(
      item("Privacy", action: #selector(NativeMenuController.openPrivacy), target: controller))
    submenu.addItem(
      item(
        "Open-Source Licenses", action: #selector(NativeMenuController.showLicenses),
        target: controller))
  }

  private func ensureMenu(named title: String, in mainMenu: NSMenu, at index: Int) -> NSMenu {
    if let existing = mainMenu.items.first(where: { $0.title == title })?.submenu {
      return existing
    }
    let submenu = NSMenu(title: title)
    let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    menuItem.submenu = submenu
    mainMenu.insertItem(menuItem, at: min(index, mainMenu.items.count))
    return submenu
  }

  private func item(
    _ title: String,
    key: String = "",
    modifiers: NSEvent.ModifierFlags = [.command],
    action: Selector,
    target: AnyObject?
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
    item.target = target
    return item
  }
}
