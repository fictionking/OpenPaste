import AppKit
import SwiftUI

/// Manages the explosion panel lifecycle and positioning
/// Panel is created once and reused across hotkey presses
class TextExplosionPanelController {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<TextExplosionView>?
    private var hideOnResignKeyObserver: AnyObject?

    // Prevent immediate dismissal after showing (debounce period)
    private var showTimestamp: Date?
    private let debounceInterval: TimeInterval = 0.3

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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
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
            var panelRect = panel.frame

            panelRect.origin.x = mouseLocation.x - panelRect.width / 2
            panelRect.origin.y = mouseLocation.y - panelRect.height - 30

            let visibleFrame = screen.visibleFrame
            panelRect.origin.x = max(visibleFrame.minX, min(panelRect.origin.x, visibleFrame.maxX - panelRect.width))
            panelRect.origin.y = max(visibleFrame.minY, min(panelRect.origin.y, visibleFrame.maxY - panelRect.height))

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
