import Cocoa
import WebKit
import UniformTypeIdentifiers

// MARK: - Custom Bundled Asset Scheme Handler (app://markdown-studio/...)
final class BundledSchemeHandler: NSObject, WKURLSchemeHandler {
    private let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        var relativePath = requestURL.path
        if relativePath.isEmpty || relativePath == "/" {
            relativePath = "/index.html"
        }

        let fileURL = rootDirectory.appendingPathComponent(String(relativePath.dropFirst()))

        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let mimeType = Self.mimeType(for: fileURL.pathExtension)
        let response = HTTPURLResponse(
            url: requestURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mimeType,
                "Content-Length": "\(data.count)",
                "Access-Control-Allow-Origin": "*"
            ]
        )!

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js", "mjs": return "application/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "svg": return "image/svg+xml"
        case "json": return "application/json; charset=utf-8"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        case "png": return "image/png"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - AppDelegate & Native Window / Toolbar Controller
final class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate, WKScriptMessageHandler, WKUIDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    private var pendingOpenFilePath: String?
    private static let lastOpenedFilePathKey = "MarkdownStudioLastOpenedFilePath"
    private static let lastOpenedFolderPathKey = "MarkdownStudioLastOpenedFolderPath"

    // Native NSToolbar Controls
    private var paneSegmentedControl: NSSegmentedControl!
    private var syncScrollButton: NSButton!

    private enum ToolbarItemID {
        static let sidebar = NSToolbarItem.Identifier("ToggleSidebarItem")
        static let fileGroup = NSToolbarItem.Identifier("FileActionsGroup")
        static let save = NSToolbarItem.Identifier("SaveDocumentItem")
        static let formatGroup = NSToolbarItem.Identifier("MarkdownFormatGroup")
        static let paneMode = NSToolbarItem.Identifier("PaneLayoutModeItem")
        static let syncScroll = NSToolbarItem.Identifier("SyncScrollToggleItem")
        static let theme = NSToolbarItem.Identifier("ThemeToggleItem")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = appIcon
        }
        setupMainMenu()
        setupWindowAndWebView()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Support opening .md files via Finder "Open With" or Dock drop
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if webView != nil && !webView.isLoading {
            loadLocalFileIntoEditor(url: URL(fileURLWithPath: filename), sourceLabel: "Finder Open")
        } else {
            pendingOpenFilePath = filename
        }
        return true
    }

    private func setupWindowAndWebView() {
        let resourceRoot = Bundle.main.resourceURL?.appendingPathComponent("web")
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("dist")

        let config = WKWebViewConfiguration()
        let schemeHandler = BundledSchemeHandler(rootDirectory: resourceRoot)
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "app")

        let userContentController = WKUserContentController()
        // Inject class on <html> before layout so web toolbar is hidden when hosted in native NSToolbar window
        let nativeInitScript = WKUserScript(
            source: "document.documentElement.classList.add('is-native-macos');",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(nativeInitScript)
        userContentController.add(self, name: "nativeHost")
        config.userContentController = userContentController

        let frame = NSRect(x: 0, y: 0, width: 1360, height: 860)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "welcome.md"
        window.subtitle = "Markdown Studio"
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .line
        window.center()
        window.setFrameAutosaveName("MarkdownStudioMainWindow")
        window.minSize = NSSize(width: 820, height: 520)

        let toolbar = NSToolbar(identifier: "MarkdownStudioMainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar

        webView = WKWebView(frame: frame, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.uiDelegate = self
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let startURL = URL(string: "app://markdown-studio/index.html") {
            webView.load(URLRequest(url: startURL))
        }
    }

    private func restoreInitialDocumentIfNeeded() {
        // 1. If launched with a specific file from Finder / Dock, open that file first
        if let pending = pendingOpenFilePath {
            pendingOpenFilePath = nil
            let pendingURL = URL(fileURLWithPath: pending)
            if FileManager.default.fileExists(atPath: pendingURL.path) {
                loadLocalFileIntoEditor(url: pendingURL, sourceLabel: "Finder Open")
                return
            }
        }

        // 2. If a folder was previously opened, restore the folder sidebar list
        if let lastFolder = UserDefaults.standard.string(forKey: Self.lastOpenedFolderPathKey) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: lastFolder, isDirectory: &isDir), isDir.boolValue {
                loadLocalFolderIntoSidebar(folderURL: URL(fileURLWithPath: lastFolder), autoSelectFirst: false)
            }
        }

        // 3. Reopen the last opened file if it still exists on disk
        if let lastPath = UserDefaults.standard.string(forKey: Self.lastOpenedFilePathKey),
           FileManager.default.fileExists(atPath: lastPath) {
            let fileURL = URL(fileURLWithPath: lastPath)
            loadLocalFileIntoEditor(url: fileURL, sourceLabel: "Restored Last File")
        }
    }

    // MARK: - NSToolbarDelegate (Genuine Native AppKit Controls & SF Symbols)
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            ToolbarItemID.sidebar,
            ToolbarItemID.fileGroup,
            ToolbarItemID.save,
            .flexibleSpace,
            ToolbarItemID.formatGroup,
            .flexibleSpace,
            ToolbarItemID.paneMode,
            ToolbarItemID.syncScroll,
            ToolbarItemID.theme
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case ToolbarItemID.sidebar:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Files"
            item.toolTip = "Toggle Local Files Sidebar (⌘⇧E)"
            let button = NSButton(
                image: symbol("sidebar.left", description: "Toggle Sidebar"),
                target: self,
                action: #selector(toolbarToggleSidebar)
            )
            button.bezelStyle = .texturedRounded
            item.view = button
            return item

        case ToolbarItemID.fileGroup:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Open"
            let seg = NSSegmentedControl(
                images: [
                    symbol("doc.badge.plus", description: "Open Markdown File"),
                    symbol("folder.badge.plus", description: "Open Markdown Folder")
                ],
                trackingMode: .momentary,
                target: self,
                action: #selector(toolbarFileGroupClicked(_:))
            )
            seg.segmentStyle = .texturedRounded
            seg.setToolTip("Open Local Markdown File (⌘O)", forSegment: 0)
            seg.setToolTip("Open Local Folder of Markdown Files (⌘⇧O)", forSegment: 1)
            seg.setWidth(34, forSegment: 0)
            seg.setWidth(34, forSegment: 1)
            item.view = seg
            return item

        case ToolbarItemID.save:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Save"
            item.toolTip = "Save Document (⌘S)"
            let button = NSButton(
                image: symbol("square.and.arrow.down", description: "Save Document"),
                target: self,
                action: #selector(menuSave)
            )
            button.bezelStyle = .texturedRounded
            item.view = button
            return item

        case ToolbarItemID.formatGroup:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Insert"
            let seg = NSSegmentedControl(
                images: [
                    symbol("bold", description: "Bold"),
                    symbol("italic", description: "Italic"),
                    symbol("chevron.left.forwardslash.chevron.right", description: "Code Block"),
                    symbol("tablecells", description: "GFM Table"),
                    symbol("exclamationmark.bubble", description: "GitHub Alert"),
                    symbol("point.3.connected.trianglepath.dotted", description: "Mermaid Diagram")
                ],
                trackingMode: .momentary,
                target: self,
                action: #selector(toolbarFormatGroupClicked(_:))
            )
            seg.segmentStyle = .texturedRounded
            seg.setToolTip("Insert Bold (**text**)", forSegment: 0)
            seg.setToolTip("Insert Italic (*text*)", forSegment: 1)
            seg.setToolTip("Insert Syntax-Highlighted Code Block", forSegment: 2)
            seg.setToolTip("Insert GitHub Flavored Markdown Table", forSegment: 3)
            seg.setToolTip("Insert GitHub Alert Callout (> [!NOTE])", forSegment: 4)
            seg.setToolTip("Insert Mermaid Diagram Block", forSegment: 5)
            for idx in 0..<6 {
                seg.setWidth(32, forSegment: idx)
            }
            item.view = seg
            return item

        case ToolbarItemID.paneMode:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Layout"
            let seg = NSSegmentedControl(
                images: [
                    symbol("rectangle.lefthalf.filled", description: "Editor Only"),
                    symbol("rectangle.split.2x1", description: "Split View"),
                    symbol("rectangle.righthalf.filled", description: "Preview Only")
                ],
                trackingMode: .selectOne,
                target: self,
                action: #selector(toolbarPaneModeChanged(_:))
            )
            seg.segmentStyle = .texturedRounded
            seg.selectedSegment = 1
            seg.setToolTip("Editor Only — Minimize Preview (⌘1)", forSegment: 0)
            seg.setToolTip("Dual-Pane Split View (⌘2)", forSegment: 1)
            seg.setToolTip("Preview Only — Minimize Editor (⌘3)", forSegment: 2)
            for idx in 0..<3 {
                seg.setWidth(34, forSegment: idx)
            }
            paneSegmentedControl = seg
            item.view = seg
            return item

        case ToolbarItemID.syncScroll:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Sync Scroll"
            item.toolTip = "Toggle Section-Anchored Scroll Sync (⌘Y)"
            let button = NSButton(
                image: symbol("arrow.up.and.down.text.horizontal", description: "Sync Scroll"),
                target: self,
                action: #selector(toolbarSyncScrollClicked(_:))
            )
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)
            button.state = .on
            syncScrollButton = button
            item.view = button
            return item

        case ToolbarItemID.theme:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Appearance"
            item.toolTip = "Toggle Light / Dark Appearance (⌘T)"
            let button = NSButton(
                image: symbol("circle.lefthalf.filled", description: "Toggle Appearance"),
                target: self,
                action: #selector(menuToggleTheme)
            )
            button.bezelStyle = .texturedRounded
            item.view = button
            return item

        default:
            return nil
        }
    }

    private func symbol(_ name: String, description: String) -> NSImage {
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: description) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            return img.withSymbolConfiguration(config) ?? img
        }
        return NSImage()
    }

    // MARK: - NSToolbar Action Handlers
    @objc private func toolbarToggleSidebar() {
        webView.evaluateJavaScript("window.markdownStudio.toggleSidebar();", completionHandler: nil)
    }

    @objc private func toolbarFileGroupClicked(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            promptOpenFile()
        } else if sender.selectedSegment == 1 {
            promptOpenFolder()
        }
    }

    @objc private func toolbarFormatGroupClicked(_ sender: NSSegmentedControl) {
        let snippets = ["bold", "italic", "code", "table", "alert", "mermaid"]
        let idx = sender.selectedSegment
        guard idx >= 0 && idx < snippets.count else { return }
        webView.evaluateJavaScript("window.markdownStudio.insertSnippet('\(snippets[idx])');", completionHandler: nil)
    }

    @objc private func toolbarPaneModeChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            menuViewEditorOnly()
        case 1:
            menuViewSplit()
        case 2:
            menuViewPreviewOnly()
        default:
            break
        }
    }

    @objc private func toolbarSyncScrollClicked(_ sender: NSButton) {
        menuToggleSyncScroll()
    }

    // MARK: - WKScriptMessageHandler (JS -> Swift Bridge)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "appReady":
            restoreInitialDocumentIfNeeded()
        case "openFile":
            promptOpenFile()
        case "openFolder":
            promptOpenFolder()
        case "readFileAtPath":
            if let path = body["path"] as? String {
                let label = (body["sourceLabel"] as? String) ?? "macOS Folder"
                loadLocalFileIntoEditor(url: URL(fileURLWithPath: path), sourceLabel: label)
            }
        case "saveFile":
            let content = (body["content"] as? String) ?? ""
            let existingPath = body["path"] as? String
            let suggestedName = (body["suggestedName"] as? String) ?? "document.md"
            saveDocument(content: content, existingPath: existingPath, suggestedName: suggestedName, forceSaveAs: false)
        case "saveFileAs":
            let content = (body["content"] as? String) ?? ""
            let suggestedName = (body["suggestedName"] as? String) ?? "document.md"
            saveDocument(content: content, existingPath: nil, suggestedName: suggestedName, forceSaveAs: true)
        case "documentEdited":
            let isDirty = (body["isDirty"] as? Bool) ?? false
            let fileName = (body["fileName"] as? String) ?? "welcome.md"
            let stats = (body["stats"] as? String) ?? "Markdown Studio"
            window.isDocumentEdited = isDirty
            window.title = fileName
            window.subtitle = stats
        case "paneModeChanged":
            let minimized = body["minimized"] as? String
            if minimized == "preview" {
                paneSegmentedControl?.selectedSegment = 0
            } else if minimized == "editor" {
                paneSegmentedControl?.selectedSegment = 2
            } else {
                paneSegmentedControl?.selectedSegment = 1
            }
        case "syncScrollChanged":
            if let enabled = body["enabled"] as? Bool {
                syncScrollButton?.state = enabled ? .on : .off
            }
        default:
            break
        }
    }

    // MARK: - Native File & Folder Dialogs (NSOpenPanel / NSSavePanel)
    @objc func promptOpenFile() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown Document"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var allowed: [UTType] = [.plainText]
        if let mdType = UTType(filenameExtension: "md") {
            allowed.insert(mdType, at: 0)
        }
        if let markdownType = UTType(filenameExtension: "markdown") {
            allowed.append(markdownType)
        }
        panel.allowedContentTypes = allowed

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadLocalFileIntoEditor(url: url, sourceLabel: "macOS Native File")
        }
    }

    @objc func promptOpenFolder() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let folderURL = panel.url else { return }
            self?.loadLocalFolderIntoSidebar(folderURL: folderURL)
        }
    }

    private func loadLocalFileIntoEditor(url: URL, sourceLabel: String) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        window.representedURL = url
        window.title = url.lastPathComponent
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        UserDefaults.standard.set(url.path, forKey: Self.lastOpenedFilePathKey)

        let payload: [String: Any] = [
            "name": url.lastPathComponent,
            "path": url.path,
            "content": content,
            "sourceLabel": sourceLabel
        ]
        invokeJS("window.markdownStudio.loadNativeFile", with: payload)
    }

    private func loadLocalFolderIntoSidebar(folderURL: URL, autoSelectFirst: Bool = true) {
        let fm = FileManager.default
        let validExts = Set(["md", "markdown", "mdx", "txt"])
        var fileItems: [[String: String]] = []

        if let items = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for itemURL in items where validExts.contains(itemURL.pathExtension.lowercased()) {
                fileItems.append([
                    "name": itemURL.lastPathComponent,
                    "path": itemURL.path
                ])
            }
        }

        fileItems.sort { ($0["name"] ?? "") < ($1["name"] ?? "") }
        UserDefaults.standard.set(folderURL.path, forKey: Self.lastOpenedFolderPathKey)

        let payload: [String: Any] = [
            "folderName": folderURL.lastPathComponent,
            "files": fileItems,
            "autoSelectFirst": autoSelectFirst
        ]
        invokeJS("window.markdownStudio.loadNativeFolder", with: payload)
    }

    private func saveDocument(content: String, existingPath: String?, suggestedName: String, forceSaveAs: Bool) {
        if !forceSaveAs, let path = existingPath, !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                window.representedURL = url
                window.isDocumentEdited = false
                UserDefaults.standard.set(url.path, forKey: Self.lastOpenedFilePathKey)
                invokeJS("window.markdownStudio.didSaveNativeFile", with: [
                    "name": url.lastPathComponent,
                    "path": url.path
                ])
                return
            } catch {
                // Fall through to NSSavePanel if direct write fails
            }
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Save Markdown Document"
        savePanel.nameFieldStringValue = suggestedName
        savePanel.canCreateDirectories = true
        if let mdType = UTType(filenameExtension: "md") {
            savePanel.allowedContentTypes = [mdType, .plainText]
        }

        savePanel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                self?.window.representedURL = url
                self?.window.isDocumentEdited = false
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
                UserDefaults.standard.set(url.path, forKey: Self.lastOpenedFilePathKey)
                self?.invokeJS("window.markdownStudio.didSaveNativeFile", with: [
                    "name": url.lastPathComponent,
                    "path": url.path
                ])
            } catch {
                NSSound.beep()
            }
        }
    }

    private func invokeJS(_ functionExpr: String, with dictionary: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("\(functionExpr)(\(jsonString));", completionHandler: nil)
    }

    // MARK: - Menu Actions
    @objc func menuNewDocument() {
        window.representedURL = nil
        UserDefaults.standard.removeObject(forKey: Self.lastOpenedFilePathKey)
        webView.evaluateJavaScript("window.markdownStudio.newDocument();", completionHandler: nil)
    }

    @objc func menuSave() {
        webView.evaluateJavaScript("window.markdownStudio.triggerSave(false);", completionHandler: nil)
    }

    @objc func menuSaveAs() {
        webView.evaluateJavaScript("window.markdownStudio.triggerSave(true);", completionHandler: nil)
    }

    @objc func menuResetDemo() {
        window.representedURL = nil
        UserDefaults.standard.removeObject(forKey: Self.lastOpenedFilePathKey)
        webView.evaluateJavaScript("window.markdownStudio.resetDemo();", completionHandler: nil)
    }

    @objc func menuViewEditorOnly() {
        paneSegmentedControl?.selectedSegment = 0
        webView.evaluateJavaScript("window.markdownStudio.setPaneMode('preview');", completionHandler: nil)
    }

    @objc func menuViewSplit() {
        paneSegmentedControl?.selectedSegment = 1
        webView.evaluateJavaScript("window.markdownStudio.setPaneMode(null);", completionHandler: nil)
    }

    @objc func menuViewPreviewOnly() {
        paneSegmentedControl?.selectedSegment = 2
        webView.evaluateJavaScript("window.markdownStudio.setPaneMode('editor');", completionHandler: nil)
    }

    @objc func menuToggleSyncScroll() {
        webView.evaluateJavaScript("window.markdownStudio.toggleSyncScroll();", completionHandler: nil)
    }

    @objc func menuToggleTheme() {
        webView.evaluateJavaScript("window.markdownStudio.toggleTheme();", completionHandler: nil)
    }

    // MARK: - Native macOS Menu Bar Construction
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        // 1. Application Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Markdown Studio", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Markdown Studio", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Markdown Studio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "New Document", action: #selector(menuNewDocument), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open File…", action: #selector(promptOpenFile), keyEquivalent: "o")
        let openFolderItem = fileMenu.addItem(withTitle: "Open Folder…", action: #selector(promptOpenFolder), keyEquivalent: "O")
        openFolderItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Save", action: #selector(menuSave), keyEquivalent: "s")
        let saveAsItem = fileMenu.addItem(withTitle: "Save As…", action: #selector(menuSaveAs), keyEquivalent: "S")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Load Built-in Demo", action: #selector(menuResetDemo), keyEquivalent: "r")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // 4. View Menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        let sidebarItem = viewMenu.addItem(withTitle: "Toggle Files Sidebar", action: #selector(toolbarToggleSidebar), keyEquivalent: "E")
        sidebarItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Editor Only (Minimize Preview)", action: #selector(menuViewEditorOnly), keyEquivalent: "1")
        viewMenu.addItem(withTitle: "Split View (Dual Pane)", action: #selector(menuViewSplit), keyEquivalent: "2")
        viewMenu.addItem(withTitle: "Preview Only (Minimize Editor)", action: #selector(menuViewPreviewOnly), keyEquivalent: "3")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Toggle Synchronized Scrolling", action: #selector(menuToggleSyncScroll), keyEquivalent: "y")
        viewMenu.addItem(withTitle: "Toggle Light / Dark Theme", action: #selector(menuToggleTheme), keyEquivalent: "t")

        // 5. Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
    }
}

// MARK: - Application Entry Point
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
