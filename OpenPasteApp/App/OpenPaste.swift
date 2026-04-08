//
//  OpenPaste.swift
//  OpenPaste
//
//  Created on 2026-03-28.
//

import AppKit
import SwiftUI
import Carbon

// MARK: - Layout Constants

/// Default width for the floating panel
private let defaultPanelWidth: CGFloat = 300

// MARK: - Global Status Item
// 🔥 macOS 15 要求：必须在全局作用域持有强引用
var statusItem: NSStatusItem?
// 🔥 macOS 15 多线程保护：防止系统在后台线程强制回收
let statusBarLock = NSLock()

// MARK: - CustomPanel
/// Custom NSPanel subclass that can become key window even with utilityWindow style
class CustomPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

// MARK: - AppDelegate
/// Application delegate for handling Dock icon events and application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        NSLog("🚀 AppDelegate.init() called!")
    }
    /// Floating panel reference for showing on Dock icon click
    var floatingPanel: NSPanel?

    /// Track the previously active application for text insertion
    private var previousActiveApplication: NSRunningApplication?

    /// View model for clipboard data, persistence, and monitoring
    private var viewModel: ClipboardViewModel?

    /// HotKey instance
    private var hotKey: HotKey?
    private var explosionHotKey: HotKey?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var statusBarIcon: NSImage?
    private var statusBarAlternateIcon: NSImage?

    /// Explosion panel (text explosion feature)
    var explosionPanel: NSPanel?
    private var explosionViewModel: TextExplosionViewModel?
    private var explosionPanelController: TextExplosionPanelController?

    /// Services for text explosion (reused across panel displays)
    private var explosionTokenizer: TextTokenizing?
    private var explosionInserter: TextInserting?
    private var explosionOCR: OCRService?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 OpenPaste launched!")

        // Setup status bar FIRST - this is critical
        // 🔥 macOS 15 启动时序 Bug: 延迟 0.3 秒确保 NSStatusBar 系统已准备就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setupStatusBar()
        }

        // Setup application tracking observer
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Setup hotkey reload observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadHotkeys),
            name: NSNotification.Name("ReloadHotkeys"),
            object: nil
        )

        // Hide all windows except our floating panel
        NSApplication.shared.windows.forEach { window in
            window.setIsVisible(false)
        }

        // Setup global hotkey with HotKey library
        setupGlobalHotkey()

        // Create ClipboardViewModel with Core Data persistence
        let dataStore = CoreDataStore(modelName: CoreDataStore.defaultModelName)
        let expiryService = ExpiryService(dataStore: dataStore)
        let monitor = ClipboardMonitor { [weak self] content, contentType, sourceApp, title, allPasteboardData in
            Task { @MainActor in
                await self?.viewModel?.handleNewClipboardItem(
                    content: content, contentType: contentType, sourceApp: sourceApp, title: title, allPasteboardData: allPasteboardData)
            }
        }
        viewModel = ClipboardViewModel(
            dataStore: dataStore, monitor: monitor, expiryService: expiryService)

        NSLog("✅ OpenPaste setup complete")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup hotkeys
        hotKey = nil
        explosionHotKey = nil

        // Cleanup click monitors
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }

        // Cleanup explosion panel
        explosionPanel?.close()
        explosionPanel = nil
        explosionViewModel = nil
        explosionPanelController = nil
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure main window stays hidden when app becomes active
        NSApplication.shared.windows.forEach { window in
            if window !== floatingPanel {
                window.setIsVisible(false)
            }
        }
    }

    /// Track when other applications are activated
    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        // Ignore when our own app activates
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }

        // Remember the last active non-OpenPaste application
        previousActiveApplication = app
        NSLog("📱 [OpenPaste] Previous active app updated: \(app.localizedName ?? "unknown")")
    }

    /// Copy content to clipboard without triggering new entry
    /// - Parameter item: The clipboard item data to restore (including all pasteboard formats)
    func copyToClipboard(_ item: ClipboardItemData) {
        MainActor.assumeIsolated {
            NSLog("📋 copyToClipboard called for item:")
            NSLog("   - ID: \(item.id)")
            NSLog("   - Content: \(item.content.prefix(50))...")
            NSLog("   - contentType: \(item.contentType)")
            NSLog("   - CapturedAt: \(item.capturedAt)")

            // Skip change detection BEFORE writing to pasteboard (critical ordering!)
            viewModel?.skipNextChange()

            // Restore complete pasteboard data with all formats
            guard let allPasteboardDataValue = item.allPasteboardData else {
                NSLog("❌ No allPasteboardData available for item: \(item.id)")
                return
            }

            NSLog("✅ Found allPasteboardData: \(allPasteboardDataValue.count) bytes")

            guard let pasteboardData = PasteboardData.decode(from: allPasteboardDataValue) else {
                NSLog("❌ Failed to decode PasteboardData from \(allPasteboardDataValue.count) bytes")
                return
            }

            NSLog("✅ Decoded PasteboardData with \(pasteboardData.types.count) types")
            NSLog("   Writing to pasteboard...")

            // Restore all formats for accurate pasting in source apps
            PasteboardWriter.writeAll(pasteboardData, to: NSPasteboard.general)
            NSLog("✅ Restored complete pasteboard with \(pasteboardData.types.count) types")

            // Update current clipboard item tracking
            viewModel?.setCurrentClipboardItem(item.id)
        }
    }

    private func setupGlobalHotkey() {
        NSLog("🔧 Registering global hotkey...")

        let settings = AppSettings.shared

        // Create hotkey for main floating panel using AppSettings
        if let key = Key(carbonKeyCode: settings.hotkeyCode) {
            var modifiers: NSEvent.ModifierFlags = []
            if settings.hotkeyModifiers & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
            if settings.hotkeyModifiers & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
            if settings.hotkeyModifiers & UInt32(optionKey) != 0 { modifiers.insert(.option) }
            if settings.hotkeyModifiers & UInt32(controlKey) != 0 { modifiers.insert(.control) }

            hotKey = HotKey(key: key, modifiers: modifiers, keyDownHandler: { [weak self] in
                NSLog("🔥 Hotkey triggered!")
                self?.handleHotkeyToggle()
            })
            NSLog("✅ Clipboard hotkey \(settings.hotkeyDescription) registered successfully!")
        }

        // Create hotkey for text explosion using AppSettings
        if let explosionKey = Key(carbonKeyCode: settings.explosionHotkeyCode) {
            var explosionModifiers: NSEvent.ModifierFlags = []
            if settings.explosionHotkeyModifiers & UInt32(cmdKey) != 0 { explosionModifiers.insert(.command) }
            if settings.explosionHotkeyModifiers & UInt32(shiftKey) != 0 { explosionModifiers.insert(.shift) }
            if settings.explosionHotkeyModifiers & UInt32(optionKey) != 0 { explosionModifiers.insert(.option) }
            if settings.explosionHotkeyModifiers & UInt32(controlKey) != 0 { explosionModifiers.insert(.control) }

            explosionHotKey = HotKey(key: explosionKey, modifiers: explosionModifiers, keyDownHandler: { [weak self] in
                NSLog("💥 Explosion hotkey triggered!")
                Task { @MainActor in
                    self?.handleExplosionHotkey()
                }
            })
            NSLog("✅ Explosion hotkey \(settings.explosionHotkeyDescription) registered successfully!")
        }
    }

    /// Reload hotkeys when settings change
    @objc private func reloadHotkeys() {
        NSLog("🔄 Reloading hotkeys...")
        // HotKey automatically unregisters when set to nil
        hotKey = nil
        explosionHotKey = nil
        // Re-register with new settings
        setupGlobalHotkey()
    }

    private func updateStatusTitle(_ title: String) {
        DispatchQueue.main.async {
            statusItem?.button?.title = title
        }
    }

    private func toggleFloatingPanel(activateApp: Bool) {
        // Close explosion panel if visible (mutual exclusion)
        closeExplosionPanel()

        if floatingPanel == nil {
            showFloatingPanel(activateApp: activateApp)
            return
        }

        if let panel = floatingPanel, panel.isVisible {
            hideFloatingPanel()
        } else {
            showFloatingPanel(activateApp: activateApp)
        }
    }

    // MARK: - Floating Panel Management

    private func showFloatingPanel(activateApp: Bool) {
        if activateApp {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        if let panel = floatingPanel {
            let screen = NSScreen.main?.visibleFrame ?? NSRect.zero
            let topBottomMargin: CGFloat = 20

            // Recalculate frame to match screen height with margin
            let panelWidth = panel.contentView?.frame.width ?? defaultPanelWidth
            let panelHeight = screen.height - (topBottomMargin * 2)
            let targetX = screen.maxX - panelWidth
            let targetY = screen.minY + topBottomMargin

            // Set the panel frame to the correct size and position off-screen
            let offScreenFrame = NSRect(x: screen.maxX, y: targetY, width: panelWidth, height: panelHeight)
            panel.setFrame(offScreenFrame, display: false)

            // Make panel visible
            if activateApp {
                panel.makeKeyAndOrderFront(nil)
            } else {
                panel.orderFrontRegardless()
                panel.makeKey()
            }
            panel.level = .modalPanel

            // Animate in from right
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                let targetFrame = NSRect(x: targetX, y: targetY, width: panelWidth, height: panelHeight)
                panel.animator().setFrame(targetFrame, display: true)
            }
            refreshStatusBarButtonAppearance()
        } else {
            createFloatingPanel()
        }
    }

    private func createFloatingPanel() {
        // Create the hosting view for SwiftUI with ViewModel
        guard let vm = viewModel else { return }
        let contentView = FloatingPanelView(viewModel: vm) { content in
            self.copyToClipboard(content)
        }
        let hostingView = NSHostingView(rootView: contentView)

        // Get screen dimensions for positioning
        let screen = NSScreen.main?.visibleFrame ?? NSRect.zero
        let panelWidth: CGFloat = defaultPanelWidth
        let topBottomMargin: CGFloat = 20
        let panelHeight: CGFloat = screen.height - (topBottomMargin * 2)

        // Target position - flush against right edge, with margin on top/bottom
        let targetX = screen.maxX - panelWidth
        let targetY = screen.minY + topBottomMargin

        // Create panel at target position first
        let panel = CustomPanel(
            contentRect: NSRect(x: targetX, y: targetY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.title = ""
        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true

        // Enable transparency for glass effect
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // Remove all window decorations and shadows
        panel.hasShadow = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = .clear
        panel.contentView?.layer?.shadowColor = .clear
        panel.contentView?.layer?.shadowOpacity = 0
        panel.contentView?.layer?.shadowRadius = 0
        panel.level = .modalPanel

        // Remove activation frame border
        panel.styleMask.insert(.nonactivatingPanel)

        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Use modalPanel level - stays above normal windows but allows interaction
        panel.level = .modalPanel

        // Don't hide panel when it loses focus (we'll handle it manually)
        panel.hidesOnDeactivate = false

        // Prevent window from being moved below other windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Store reference
        floatingPanel = panel

        // Show the panel
        panel.orderFrontRegardless()
        panel.makeKey()

        // Slide-in animation from right
        let startFrame = NSRect(x: screen.maxX, y: targetY, width: panelWidth, height: panelHeight)
        panel.setFrame(startFrame, display: false)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(NSRect(x: targetX, y: targetY, width: panelWidth, height: panelHeight), display: true)
        }

        refreshStatusBarButtonAppearance()

        // Add click-outside observer
        addClickOutsideObserver()
    }

    private func addClickOutsideObserver() {
        if globalClickMonitor == nil {
            // Use global monitor to detect clicks anywhere on screen
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self else { return }

                // Skip status bar clicks
                if self.isStatusItemClick(event) {
                    return
                }

                // Use mouseLocation for screen coordinates (more reliable than locationInWindow)
                let clickPoint = NSEvent.mouseLocation

                // Check floating panel
                if let panel = self.floatingPanel, panel.isVisible {
                    if !panel.frame.contains(clickPoint) {
                        self.hideFloatingPanel()
                    }
                }

                // Check explosion panel
                if let explosionPanelController = self.explosionPanelController,
                   self.explosionPanel?.isVisible == true {
                    if explosionPanelController.shouldDismiss(for: clickPoint) {
                        self.closeExplosionPanel()
                    }
                }
            }
        }

        if localClickMonitor == nil {
            // Also monitor local events within the app
            localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self else { return event }

                // Skip status bar clicks
                if self.isStatusItemClick(event) {
                    return event
                }

                // Use mouseLocation for screen coordinates (more reliable)
                let screenLocation = NSEvent.mouseLocation

                // Check floating panel
                if let panel = self.floatingPanel, panel.isVisible {
                    if event.window !== panel && !panel.frame.contains(screenLocation) {
                        self.hideFloatingPanel()
                    }
                }

                // Check explosion panel
                if let explosionPanelController = self.explosionPanelController,
                   self.explosionPanel?.isVisible == true {
                    if explosionPanelController.shouldDismiss(for: screenLocation) {
                        self.closeExplosionPanel()
                    }
                }

                return event
            }
        }
    }

    private func hideFloatingPanel() {
        guard let panel = floatingPanel else { return }

        // Close explosion panel for mutual exclusion symmetry
        closeExplosionPanel()

        let currentFrame = panel.frame
        let screen = NSScreen.main?.visibleFrame ?? NSRect.zero

        // Slide-out animation to the right
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: screen.maxX, y: currentFrame.origin.y))
        } completionHandler: {
            panel.orderOut(nil)
            self.refreshStatusBarButtonAppearance()
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        // 🔥 macOS 15 多线程保护：防止系统在后台线程强制回收
        statusBarLock.lock()
        defer { statusBarLock.unlock() }

        NSLog("🔧 Setting up status bar (macOS 15 safe: action-only, no menu)")

        // 稳定长度
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.isVisible = true

        guard let button = statusItem?.button else {
            NSLog("❌ Status bar button unavailable")
            return
        }

        configureStatusBarButton(button)

        button.toolTip = "OpenPaste - 点击打开剪贴板历史"
        button.imagePosition = .imageOnly
        button.isEnabled = true
        button.appearsDisabled = false

        // 🔥 核心：纯 action，无 menu、无手势
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseDown])

        // ✅ 关键：完全不设置 menu

        NSLog("✅ Status bar ready: left-click only, no menu")
    }

    private func configureStatusBarButton(_ button: NSStatusBarButton) {
        button.title = ""

        if statusBarIcon == nil {
            statusBarIcon = makeStatusBarIcon()
        }
        if statusBarAlternateIcon == nil {
            statusBarAlternateIcon = makeStatusBarIcon()
        }

        if let icon = statusBarIcon {
            button.image = icon
            button.alternateImage = statusBarAlternateIcon
            button.imageScaling = .scaleProportionallyDown
        } else {
            button.image = nil
            button.alternateImage = nil
            button.title = "📋"
        }
    }

    private func makeStatusBarIcon() -> NSImage? {
        guard let icon = NSImage(named: "StatusBarIcon")?.copy() as? NSImage else {
            return nil
        }
        icon.isTemplate = true
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }

    private func refreshStatusBarButtonAppearance() {
        DispatchQueue.main.async {
            guard let statusItem, let button = statusItem.button else { return }
            statusItem.isVisible = true
            self.configureStatusBarButton(button)
            button.imagePosition = .imageOnly
            button.isEnabled = true
            button.appearsDisabled = false
            button.needsLayout = true
            button.needsDisplay = true
            button.superview?.needsDisplay = true
        }
    }

    private func isStatusItemClick(_ event: NSEvent) -> Bool {
        guard let button = statusItem?.button,
              let buttonWindow = button.window else {
            return false
        }

        if event.window === buttonWindow {
            let pointInButtonWindow = event.locationInWindow
            let buttonFrameInWindow = button.convert(button.bounds, to: nil)
            return buttonFrameInWindow.contains(pointInButtonWindow)
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
        let eventPointOnScreen: NSPoint

        if let eventWindow = event.window {
            let windowFrame = eventWindow.frame
            let pointInWindow = event.locationInWindow
            eventPointOnScreen = NSPoint(
                x: windowFrame.origin.x + pointInWindow.x,
                y: windowFrame.origin.y + pointInWindow.y
            )
        } else {
            eventPointOnScreen = event.locationInWindow
        }

        return buttonFrameOnScreen.contains(eventPointOnScreen)
    }

    // 左键点击：打开/切换面板
    @objc private func handleStatusItemClick(_ sender: Any?) {
        refreshStatusBarButtonAppearance()
        toggleFloatingPanel(activateApp: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.refreshStatusBarButtonAppearance()
        }
    }

    private func handleHotkeyToggle() {
        refreshStatusBarButtonAppearance()
        toggleFloatingPanel(activateApp: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.refreshStatusBarButtonAppearance()
        }
    }

    // MARK: - Text Explosion Feature

    /// Handle the explosion hotkey (Cmd+Shift+B)
    @MainActor
    private func handleExplosionHotkey() {
        // Use the tracked previous application
        let targetApp = previousActiveApplication
        NSLog("📱 [OpenPaste] Target app for insertion: \(targetApp?.localizedName ?? "none")")
        NSLog("💥 [OpenPaste] Explosion hotkey triggered, loading clipboard content...")

        // Dismiss main floating panel (mutual exclusion)
        if let panel = floatingPanel, panel.isVisible {
            hideFloatingPanel()
        }

        // Lazy initialization: create services and panel controller only on first use
        if explosionTokenizer == nil {
            explosionTokenizer = TextExplosionService()
        }
        if explosionInserter == nil {
            explosionInserter = TextInsertionService()
        }
        if explosionOCR == nil {
            explosionOCR = OCRService()
        }

        // Update the target application for insertion
        explosionInserter?.targetApplication = targetApp

        // Create view model and panel controller if not exists
        if explosionViewModel == nil {
            explosionViewModel = TextExplosionViewModel(
                tokenizer: explosionTokenizer!,
                inserter: explosionInserter!
            )
        }

        if explosionPanelController == nil {
            explosionPanelController = TextExplosionPanelController()
            // 设置面板显示在光标上方，避免遮挡输入区域
            explosionPanelController?.position = .above
        }

        // Get or create the panel (reuse existing panel if available)
        explosionPanel = explosionPanelController?.getOrCreatePanel(
            viewModel: explosionViewModel!,
            onClose: { [weak self] in
                self?.closeExplosionPanel()
            }
        )

        // Load clipboard content and show the panel
        Task { @MainActor in
            NSLog("🔍 [OpenPaste] About to call loadFromClipboard...")
            await explosionViewModel?.loadFromClipboard()
            explosionPanelController?.show()
        }
    }

    /// Close the explosion panel (hide without destroying for reuse)
    private func closeExplosionPanel() {
        explosionPanelController?.hide()
    }

    /// Show a system notification
    private func showNotification(_ message: String) {
        let notification = NSUserNotification()
        notification.title = "OpenPaste"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - FloatingPanelView

/// View wrapper for the floating panel with sidebar navigation
/// Uses HStack layout: 70pt sidebar + unified content area
struct FloatingPanelView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    let copyHandler: (ClipboardItemData) -> Void

    @State private var selectedCategory: CategorySelector = .preset(.recent)

    // MARK: - Computed Properties for Background Effects

    @ViewBuilder
    private var panelBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 12)
                .glassEffect(.clear,in: RoundedRectangle(cornerRadius: 12))
        }else{
            RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar (floating buttons outside background)
            SidebarView(
                viewModel: viewModel,
                selectedCategory: $selectedCategory
            )

            // Right content area with rounded glass background
            UnifiedContentView(
                selectedCategory: $selectedCategory,
                viewModel: viewModel,
                copyHandler: copyHandler
            )
            .frame(maxWidth: .infinity)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - PanelTab

enum PanelTab: String, CaseIterable {
    case history
    case categories
    case settings
}

// MARK: - ContentView

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.on.clipboard")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("OpenPaste")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your clipboard companion")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Press ⌘⇧V to open clipboard history")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
