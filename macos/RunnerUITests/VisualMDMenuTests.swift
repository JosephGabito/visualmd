import AppKit
import Darwin
import XCTest

@MainActor
final class VisualMDMenuTests: XCTestCase {
  private var app: XCUIApplication!
  private var profile: String!

  private var profileRoot: URL {
    uiTestStorageRoot
      .appendingPathComponent(profile, isDirectory: true)
  }

  private var uiTestStorageRoot: URL {
    URL(fileURLWithPath: hostHomePath, isDirectory: true)
      .appendingPathComponent("Library/Containers/com.visualmd.visualmd/Data")
      .appendingPathComponent("tmp/Visual MD UI Tests", isDirectory: true)
  }

  private var hostHomePath: String {
    guard let account = getpwuid(getuid()) else {
      XCTFail("The UI test runner could not resolve its host account.")
      return NSHomeDirectory()
    }
    return String(cString: account.pointee.pw_dir)
  }

  private var preferencesURL: URL {
    profileRoot.appendingPathComponent("preferences.json")
  }

  private var sessionURL: URL {
    profileRoot.appendingPathComponent("session.json")
  }

  private var fixtureRoot: URL {
    URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("Visual MD Fixtures", isDirectory: true)
      .appendingPathComponent(profile, isDirectory: true)
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
    profile = "test-\(UUID().uuidString)"
    app = XCUIApplication()
    app.launchEnvironment["VISUAL_MD_UI_TEST_PROFILE"] = profile
    app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
  }

  override func tearDownWithError() throws {
    if (testRun?.failureCount ?? 0) > 0 {
      let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      screenshot.name = "Visual MD UI test failure"
      screenshot.lifetime = .keepAlways
      add(screenshot)
    }

    if app.state != .notRunning {
      app.terminate()
    }
    try? FileManager.default.removeItem(at: profileRoot)
    try? FileManager.default.removeItem(at: fixtureRoot)
    app = nil
    profile = nil
  }

  func testCleanLaunchPresentsAUsableWindow() throws {
    launch()

    XCTAssertTrue(app.staticTexts["A quiet place to read Markdown."].exists)
    XCTAssertTrue(app.menuBars.menuBarItems["File"].isEnabled)
    XCTAssertTrue(app.menuBars.menuBarItems["View"].isEnabled)
  }

  func testRelaunchPresentsTheMainWindowAgain() throws {
    launch()
    app.terminate()
    XCTAssertTrue(waitForApplicationToStop(timeout: 5))

    launch()

    XCTAssertTrue(app.windows.firstMatch.exists)
    XCTAssertTrue(app.staticTexts["A quiet place to read Markdown."].exists)
  }

  func testSettingsOpenCloseAndOpenAgain() throws {
    launch()

    openMenu("Visual MD", item: "Settings…")
    XCTAssertTrue(app.buttons["Paper"].waitForExistence(timeout: 5))
    app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    XCTAssertTrue(app.buttons["Paper"].waitForNonExistence(timeout: 5))

    openMenu("Visual MD", item: "Settings…")
    XCTAssertTrue(app.buttons["Paper"].waitForExistence(timeout: 5))
  }

  func testKeyboardShortcutsOpenAndClose() throws {
    launch()

    openMenu("Help", item: "Keyboard Shortcuts")
    XCTAssertTrue(app.staticTexts["Keyboard Shortcuts"].waitForExistence(timeout: 5))
    let done = app.buttons["Done"]
    XCTAssertTrue(done.waitForExistence(timeout: 5))
    app.typeKey(.escape, modifierFlags: [])

    XCTAssertTrue(app.staticTexts["Keyboard Shortcuts"].waitForNonExistence(timeout: 5))
  }

  func testLicensesUseTheReaderSurfaceAndAnExplicitCloseAction() throws {
    launch()

    openMenu("Help", item: "Open-Source Licenses")
    XCTAssertTrue(element(label: "Open-Source Licenses").waitForExistence(timeout: 15))
    let close = app.buttons["Close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    close.click()

    XCTAssertTrue(app.staticTexts["A quiet place to read Markdown."].waitForExistence(timeout: 5))
  }

  func testUnavailableDocumentCommandsAreDisabledOnCleanLaunch() throws {
    launch()

    let shelf = revealMenuItem("View", item: "Shelf")
    XCTAssertFalse(shelf.isEnabled)
    app.typeKey(.escape, modifierFlags: [])

    let find = revealMenuItem("Edit", item: "Find in Document…")
    XCTAssertFalse(find.isEnabled)
  }

  func testClosingTheOnlyWindowQuitsVisualMD() throws {
    launch()

    let closeWindow = revealMenuItem("File", item: "Close Window")
    XCTAssertTrue(
      closeWindow.isEnabled,
      "Close Window is present but disabled while the main window is open."
    )
    closeWindow.click()

    XCTAssertTrue(
      waitForApplicationToStop(timeout: 5),
      "Closing Visual MD's only window left the application running without a window."
    )
  }

  func testThemeCanChange() throws {
    launch()

    openMenu("Visual MD", item: "Settings…")
    XCTAssertTrue(app.buttons["Paper"].waitForExistence(timeout: 5))
    focusAppearanceRow(offsetFromFirst: 5)
    XCTAssertTrue(
      waitForPreference("theme", containing: "paper", timeout: 5),
      "Expected the persisted theme at \(preferencesURL.path)."
    )

    XCTAssertTrue(button(labelBeginningWith: "Appearance: Paper").waitForExistence(timeout: 5))
  }

  func testParagraphModeCanChange() throws {
    launch()

    openMenu("Visual MD", item: "Settings…")
    let indented = app.buttons["Book-style indents"]
    XCTAssertTrue(indented.waitForExistence(timeout: 5))
    focusAppearanceRow(offsetFromFirst: 3)
    XCTAssertTrue(waitForPreference("paragraphs", equalTo: "indented", timeout: 5))
  }

  func testTypographyCanChange() throws {
    launch()

    openMenu("Visual MD", item: "Settings…")
    let sans = app.buttons["Sans"]
    XCTAssertTrue(sans.waitForExistence(timeout: 5))
    focusAppearanceRow(offsetFromFirst: 1)
    XCTAssertTrue(waitForPreference("readingMode", equalTo: "sans", timeout: 5))

    XCTAssertTrue(
      app.buttons.matching(
        NSPredicate(format: "label BEGINSWITH 'Appearance:' AND label ENDSWITH ', Sans'")
      ).firstMatch.waitForExistence(timeout: 5)
    )
  }

  func testOpenMarkdownCanBeCancelledSafely() throws {
    launch()

    openMenu("File", item: "Open…")
    let panel = app.sheets.firstMatch
    XCTAssertTrue(panel.waitForExistence(timeout: 5))
    panel.buttons["Cancel"].click()

    XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["A quiet place to read Markdown."].exists)
  }

  func testOpeningARealMarkdownFileDisplaysItsTitleAndContent() throws {
    let file = try fixture(
      "release-fixture.md",
      contents: "# Release Fixture\n\n## Only the release fixture contains this sentence.\n"
    )
    launch()

    try openWithNativePicker(file)

    XCTAssertTrue(app.staticTexts["Release Fixture"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(
      app.groups["Only the release fixture contains this sentence."]
        .waitForExistence(timeout: 5)
    )
  }

  func testOpeningAFolderShowsNestedMarkdownOnTheShelf() throws {
    let folder = try nestedLibraryFixture()
    setWindowWidth(1_400)
    launch()

    try openWithNativePicker(folder)

    XCTAssertTrue(libraryHeader.waitForExistence(timeout: 10))
    let nestedFolder = app.buttons["guide, folder"]
    XCTAssertTrue(nestedFolder.waitForExistence(timeout: 5))
    nestedFolder.click()
    XCTAssertTrue(app.buttons["Nested Truth, document"].waitForExistence(timeout: 5))
  }

  func testAuthorizedFolderStillWorksAfterRelaunch() throws {
    let folder = try nestedLibraryFixture()
    setWindowWidth(1_400)
    launch()
    try openWithNativePicker(folder)
    XCTAssertTrue(app.staticTexts["Root Guide"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(waitUntil(timeout: 5) { FileManager.default.fileExists(atPath: self.sessionURL.path) })

    app.terminate()
    launch()

    XCTAssertTrue(app.staticTexts["Root Guide"].firstMatch.waitForExistence(timeout: 10))
  }

  func testCompactShelfAndOutlineUseOneOverlayAtATime() throws {
    setWindowWidth(900)
    launch()
    openSampleLibrary()

    openMenu("View", item: "Shelf")
    XCTAssertTrue(libraryHeader.waitForExistence(timeout: 5))
    XCTAssertFalse(outlineHeader.exists)

    openMenu("View", item: "Outline")
    XCTAssertTrue(outlineHeader.waitForExistence(timeout: 5))
    XCTAssertFalse(libraryHeader.exists)

    app.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(outlineHeader.waitForNonExistence(timeout: 5))
  }

  func testWidePanelsStayDockedAndRememberVisibility() throws {
    setWindowWidth(1_400)
    launch()
    openSampleLibrary()
    XCTAssertTrue(libraryHeader.waitForExistence(timeout: 5))
    XCTAssertTrue(outlineHeader.waitForExistence(timeout: 5))

    openMenu("View", item: "Shelf")
    XCTAssertTrue(libraryHeader.waitForNonExistence(timeout: 5))
    XCTAssertTrue(waitForPreference("shelfVisible", equalTo: "false", timeout: 5))
    app.terminate()
    launch()

    XCTAssertFalse(libraryHeader.exists)
    XCTAssertTrue(outlineHeader.waitForExistence(timeout: 10))
  }

  func testOutlineIsDisabledWhenDocumentHasNoHeadings() throws {
    let file = try fixture(
      "plain.md",
      contents: "This document deliberately contains no headings.\n"
    )
    launch()
    try openWithNativePicker(file)

    let outline = revealMenuItem("View", item: "Outline")
    XCTAssertFalse(outline.isEnabled)
  }

  func testFullScreenRoundTripKeepsTheDocument() throws {
    launch()
    openSampleLibrary()
    XCTAssertTrue(app.groups["Welcome to Visual MD"].firstMatch.exists)

    app.typeKey("f", modifierFlags: [.command, .control])
    XCTAssertTrue(waitUntil(timeout: 10) { self.app.windows.firstMatch.frame.width >= 1_700 })
    XCTAssertTrue(app.groups["Welcome to Visual MD"].firstMatch.exists)

    app.typeKey("f", modifierFlags: [.command, .control])
    XCTAssertTrue(waitUntil(timeout: 10) { self.app.windows.firstMatch.frame.width < 1_700 })
    XCTAssertTrue(app.groups["Welcome to Visual MD"].firstMatch.exists)
  }

  func testMenuAndKeyboardTextSizeCommandsHaveParity() throws {
    launch()
    openSampleLibrary()

    let actualAtDefault = revealMenuItem("View", item: "Actual Size")
    XCTAssertFalse(actualAtDefault.isEnabled)
    app.typeKey(.escape, modifierFlags: [])

    openMenu("View", item: "Increase Text Size")
    XCTAssertTrue(waitForPreference("textSize", equalTo: "19.0", timeout: 5))
    openMenu("View", item: "Actual Size")
    XCTAssertTrue(waitForPreference("textSize", equalTo: "18.0", timeout: 5))

    app.typeKey("+", modifierFlags: [.command])
    XCTAssertTrue(waitForPreference("textSize", equalTo: "19.0", timeout: 5))
    app.typeKey("0", modifierFlags: [.command])
    XCTAssertTrue(waitForPreference("textSize", equalTo: "18.0", timeout: 5))
  }

  func testNativeSelectAllMakesCopyAvailableAndCopiesTheWholeDocument() throws {
    launch()
    openSampleLibrary()
    NSPasteboard.general.clearContents()

    openMenu("Edit", item: "Select All")
    let copy = revealMenuItem("Edit", item: "Copy")
    XCTAssertTrue(copy.isEnabled)
    copy.click()

    XCTAssertTrue(
      waitUntil(timeout: 5) {
        NSPasteboard.general.string(forType: .string)?.contains("Welcome to Visual MD") == true
      },
      "The native Copy command did not receive Flutter's document selection."
    )
  }

  func testNewWorkspaceInvalidatesCopyBeforeAnotherDocumentOpens() throws {
    launch()
    openSampleLibrary()

    openMenu("Edit", item: "Select All")
    let selectedCopy = revealMenuItem("Edit", item: "Copy")
    XCTAssertTrue(selectedCopy.isEnabled)
    app.typeKey(.escape, modifierFlags: [])

    openMenu("File", item: "New Workspace")
    XCTAssertTrue(
      app.staticTexts["A quiet place to read Markdown."].waitForExistence(timeout: 5)
    )

    let emptyCopy = revealMenuItem("Edit", item: "Copy")
    XCTAssertFalse(emptyCopy.isEnabled)
    app.typeKey(.escape, modifierFlags: [])

    openSampleLibrary()
    let reopenedCopy = revealMenuItem("Edit", item: "Copy")
    XCTAssertFalse(reopenedCopy.isEnabled)
  }

  func testCommandWAndCommandQBothLeaveNoWindowlessApplication() throws {
    launch()
    app.typeKey("w", modifierFlags: [.command])
    XCTAssertTrue(waitForApplicationToStop(timeout: 5))

    launch()
    app.typeKey("q", modifierFlags: [.command])
    XCTAssertTrue(waitForApplicationToStop(timeout: 5))
  }

  func testMalformedRecoveryStateDoesNotPreventLaunch() throws {
    app.launchEnvironment["VISUAL_MD_UI_TEST_MALFORMED_SESSION"] = "1"

    launch()

    XCTAssertTrue(app.staticTexts["A quiet place to read Markdown."].waitForExistence(timeout: 10))
    XCTAssertTrue(app.menuBars.menuBarItems["File"].isEnabled)
  }

  func testTextSizeCanIncreaseDecreaseAndReturnToActualSize() throws {
    launch()
    openSampleLibrary()

    openMenu("View", item: "Increase Text Size")
    XCTAssertTrue(waitForPreference("textSize", equalTo: "19.0", timeout: 5))

    openMenu("View", item: "Actual Size")
    XCTAssertTrue(waitForPreference("textSize", equalTo: "18.0", timeout: 5))

    openMenu("View", item: "Decrease Text Size")
    XCTAssertTrue(waitForPreference("textSize", equalTo: "17.0", timeout: 5))
  }

  private func launch() {
    app.launch()

    XCTAssertTrue(
      app.wait(for: .runningForeground, timeout: 15),
      "Visual MD did not reach the foreground after launch."
    )
    XCTAssertTrue(
      app.windows.firstMatch.waitForExistence(timeout: 15),
      "Visual MD launched without presenting its main window."
    )
  }

  private func openSampleLibrary() {
    openMenu("File", item: "Open Sample Library")
    XCTAssertTrue(
      app.groups["Welcome to Visual MD"].firstMatch.waitForExistence(timeout: 10),
      "The sample library did not finish opening."
    )
  }

  private func openMenu(_ menu: String, item: String) {
    let menuItem = revealMenuItem(menu, item: item)
    XCTAssertTrue(menuItem.isEnabled, "\(menu) → \(item) is disabled.")
    menuItem.click()
  }

  private func button(labelBeginningWith prefix: String) -> XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", prefix)
    ).firstMatch
  }

  private func element(label: String) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", label))
      .firstMatch
  }

  private var libraryHeader: XCUIElement {
    app.groups.matching(NSPredicate(format: "label BEGINSWITH 'LIBRARY'"))
      .firstMatch
  }

  private var outlineHeader: XCUIElement {
    app.groups.matching(NSPredicate(format: "label BEGINSWITH 'ON THIS PAGE'"))
      .firstMatch
  }

  private func setWindowWidth(_ width: Int) {
    app.launchEnvironment["VISUAL_MD_UI_TEST_WINDOW_WIDTH"] = String(width)
  }

  @discardableResult
  private func fixture(_ relativePath: String, contents: String) throws -> URL {
    let target = fixtureRoot.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: target.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(contents.utf8).write(to: target)
    return target
  }

  private func nestedLibraryFixture() throws -> URL {
    _ = try fixture("Library/index.md", contents: "# Root Guide\n\nStart here.\n")
    _ = try fixture(
      "Library/guide/nested.md",
      contents: "# Nested Truth\n\nThe nested document is available.\n"
    )
    return fixtureRoot.appendingPathComponent("Library", isDirectory: true)
  }

  private func openWithNativePicker(_ url: URL) throws {
    openMenu("File", item: "Open…")
    let panel = app.sheets.firstMatch
    XCTAssertTrue(panel.waitForExistence(timeout: 5), "The native Open panel did not appear.")

    app.typeKey("g", modifierFlags: [.command, .shift])
    let pathField = app.textFields.firstMatch
    XCTAssertTrue(pathField.waitForExistence(timeout: 5), "The Go to Folder field did not appear.")
    pathField.typeText(url.path)
    app.typeKey(.return, modifierFlags: [])

    let open = panel.buttons["Open"]
    XCTAssertTrue(open.waitForExistence(timeout: 5), "The native Open action is missing.")
    open.click()
    XCTAssertTrue(panel.waitForNonExistence(timeout: 10), "The native Open panel did not close.")
  }

  private func focusAppearanceRow(offsetFromFirst: Int) {
    // Opening the menu gives keyboard focus to its first actionable row.
    // Move only by the distance from that row, then use its public keyboard
    // activation contract. This avoids coordinate assumptions about the
    // reader's typography or the current screen scale.
    for _ in 0..<offsetFromFirst {
      app.typeKey(.tab, modifierFlags: [])
    }
    app.typeKey(.space, modifierFlags: [])
  }

  private func revealMenuItem(_ menu: String, item: String) -> XCUIElement {
    let menuBarItem = app.menuBars.menuBarItems[menu]
    XCTAssertTrue(
      menuBarItem.waitForExistence(timeout: 5),
      "The native \(menu) menu is missing."
    )
    menuBarItem.click()

    let menuItem = app.menuItems[item]
    XCTAssertTrue(
      menuItem.waitForExistence(timeout: 5),
      "The \(menu) menu does not offer \(item)."
    )
    return menuItem
  }

  private func waitForApplicationToStop(timeout: TimeInterval) -> Bool {
    waitUntil(timeout: timeout) { self.app.state == .notRunning }
  }

  private func waitForPreference(
    _ key: String,
    equalTo expected: String? = nil,
    containing fragment: String? = nil,
    timeout: TimeInterval
  ) -> Bool {
    waitUntil(timeout: timeout) {
      guard
        let data = try? Data(contentsOf: self.preferencesURL),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let value = json[key] as? String
      else {
        return false
      }
      if let expected { return value == expected }
      if let fragment { return value.contains(fragment) }
      return true
    }
  }

  private func waitUntil(
    timeout: TimeInterval,
    condition: @escaping () -> Bool
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    return condition()
  }
}
