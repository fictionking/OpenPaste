import AppKit
import SwiftUI

/// Manages the explosion panel lifecycle and positioning
class TextExplosionPanelController {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<TextExplosionView>?

    // Prevent immediate dismissal after showing (debounce period)
    private var showTimestamp: Date?
    private let debounceInterval: TimeInterval = 0.3

    /// Create and configure the explosion panel
    func createPanel(viewModel: TextExplosionViewModel, onClose: @escaping () -> Void) -> NSPanel {
        let contentView = TextExplosionView(viewModel: viewModel, onClose: onClose)

        hostingController = NSHostingController(rootView: contentView)

        let panel = CustomPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear

        // Key settings for non-activating panel - doesn't steal focus
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false

        // Position at cursor location
        if let screen = NSScreen.main {
            let mouseLocation = NSEvent.mouseLocation
            var panelRect = panel.frame

            // Center panel at mouse position
            panelRect.origin.x = mouseLocation.x - panelRect.width / 2
            panelRect.origin.y = mouseLocation.y - panelRect.height - 30 // Offset above cursor

            // Constrain to visible screen frame
            let visibleFrame = screen.visibleFrame
            panelRect.origin.x = max(visibleFrame.minX, min(panelRect.origin.x, visibleFrame.maxX - panelRect.width))
            panelRect.origin.y = max(visibleFrame.minY, min(panelRect.origin.y, visibleFrame.maxY - panelRect.height))

            panel.setFrame(panelRect, display: false)
        }

        panel.contentViewController = hostingController

        self.panel = panel
        return panel
    }

    /// Show the panel
    func show() {
        guard let panel = panel else { return }
        showTimestamp = Date()
        panel.orderFront(nil)  // Use orderFront instead of makeKeyAndOrderFront
    }

    /// Check if point is outside panel frame (with debounce protection)
    func shouldDismiss(for point: NSPoint) -> Bool {
        guard let panel = panel else { return false }

        // Debounce: don't dismiss immediately after showing
        if let timestamp = showTimestamp,
           Date().timeIntervalSince(timestamp) < debounceInterval {
            NSLog("⏱️ [ExplosionPanel] Debounce active, ignoring click")
            return false
        }

        return !panel.frame.contains(point)
    }

    /// Close and dismiss the panel
    func close() {
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

/// Custom NSPanel subclass for the explosion panel
class ExplosionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
