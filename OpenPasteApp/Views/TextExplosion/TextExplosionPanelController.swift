import AppKit
import SwiftUI

/// Panel position relative to cursor
enum PanelPosition {
    case above    // 显示在光标上方（默认）
    case below    // 显示在光标下方
    case left     // 显示在光标左侧
    case right    // 显示在光标右侧
}

/// Manages the explosion panel lifecycle and positioning
/// Panel is created once and reused across hotkey presses
class TextExplosionPanelController {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<TextExplosionView>?
    private var hideOnResignKeyObserver: AnyObject?

    // Prevent immediate dismissal after showing (debounce period)
    private var showTimestamp: Date?
    private let debounceInterval: TimeInterval = 0.3

    // Panel position configuration
    var position: PanelPosition = .above

    /// Lazy-create or reuse the panel
    @MainActor
    func getOrCreatePanel(viewModel: TextExplosionViewModel, onClose: @escaping () -> Void) -> NSPanel {
        if let existingPanel = panel {
            // Reuse existing panel - just update the hosting controller
            let contentView = TextExplosionView(viewModel: viewModel, onClose: onClose)
            hostingController = NSHostingController(rootView: contentView)
            existingPanel.contentViewController = hostingController
            self.panel = existingPanel
            return existingPanel
        }

        // First time: create new panel
        let contentView = TextExplosionView(viewModel: viewModel, onClose: onClose)
        hostingController = NSHostingController(rootView: contentView)

        let newPanel = CustomPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 280),
            styleMask: [.fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu
        newPanel.backgroundColor = .clear
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.hidesOnDeactivate = false
        newPanel.isMovableByWindowBackground = true

        newPanel.contentViewController = hostingController

        // Add observer for window losing key status to auto-hide
        hideOnResignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: newPanel,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }

        self.panel = newPanel
        return newPanel
    }

    /// Reposition panel at cursor location
    func repositionAtCursor() {
        guard let panel = panel else { return }

        if let screen = NSScreen.main {
            let mouseLocation = NSEvent.mouseLocation
            let panelSize = panel.frame.size
            let offset: CGFloat = 15  // 距离光标的间距

            var origin: CGPoint

            switch position {
            case .above:
                // 显示在光标上方，水平居中
                origin = CGPoint(
                    x: mouseLocation.x - panelSize.width / 2,
                    y: mouseLocation.y - panelSize.height - offset
                )

            case .below:
                // 显示在光标下方，水平居中
                origin = CGPoint(
                    x: mouseLocation.x - panelSize.width / 2,
                    y: mouseLocation.y + offset
                )

            case .left:
                // 显示在光标左侧，垂直居中
                origin = CGPoint(
                    x: mouseLocation.x - panelSize.width - offset,
                    y: mouseLocation.y - panelSize.height / 2
                )

            case .right:
                // 显示在光标右侧，垂直居中
                origin = CGPoint(
                    x: mouseLocation.x + offset,
                    y: mouseLocation.y - panelSize.height / 2
                )
            }

            // 确保面板在可见区域内
            let visibleFrame = screen.visibleFrame
            var panelRect = CGRect(origin: origin, size: panelSize)

            // 边界检查
            panelRect.origin.x = max(visibleFrame.minX, min(panelRect.origin.x, visibleFrame.maxX - panelSize.width))
            panelRect.origin.y = max(visibleFrame.minY, min(panelRect.origin.y, visibleFrame.maxY - panelSize.height))

            panel.setFrame(panelRect, display: false)
        }
    }

    /// Show the panel at cursor location
    func show() {
        guard let panel = panel else { return }
        showTimestamp = Date()
        repositionAtCursor()
        // Order front and make key to ensure panel has focus for click events
        panel.orderFront(nil)
        panel.makeKey()
    }

    /// Hide the panel (doesn't destroy it)
    func hide() {
        panel?.orderOut(nil)
    }

    /// Check if point is outside panel frame (with debounce protection)
    func shouldDismiss(for point: NSPoint) -> Bool {
        guard let panel = panel else { return false }

        if let timestamp = showTimestamp,
           Date().timeIntervalSince(timestamp) < debounceInterval {
            return false
        }

        return !panel.frame.contains(point)
    }

    /// Close and destroy the panel
    func close() {
        // Remove notification observer
        if let observer = hideOnResignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            hideOnResignKeyObserver = nil
        }
        panel?.close()
        panel = nil
        hostingController = nil
    }

    /// Check if a point is inside the panel frame
    func isPointInside(_ point: NSPoint) -> Bool {
        guard let panel = panel else { return false }
        return panel.frame.contains(point)
    }
}
