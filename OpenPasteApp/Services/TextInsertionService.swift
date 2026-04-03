import Foundation
import Cocoa

/// Result of a text insertion operation
enum InsertionResult: Equatable {
    case insertedDirectly
    case failed(String)

    static func == (lhs: InsertionResult, rhs: InsertionResult) -> Bool {
        switch (lhs, rhs) {
        case (.insertedDirectly, .insertedDirectly):
            return true
        case (.failed(let lhsMsg), .failed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

/// Protocol for text insertion services
protocol TextInserting {
    var targetApplication: NSRunningApplication? { get set }
    func checkAccessibilityPermission() -> Bool
    func requestAccessibilityPermission()
    func insertText(_ text: String) async -> InsertionResult
}

/// CGEvent-based text insertion service
/// Posts keyboard events directly to target app process using postToPid
class TextInsertionService: TextInserting {
    var targetApplication: NSRunningApplication?

    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func insertText(_ text: String) async -> InsertionResult {
        guard checkAccessibilityPermission() else {
            return .failed("需要辅助功能权限才能插入文本")
        }

        let success = await simulateTyping(text)
        return success ? .insertedDirectly : .failed("文本插入失败")
    }

    // MARK: - Private Methods

    private func simulateTyping(_ text: String) async -> Bool {
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        guard let targetApp = targetApplication ?? NSWorkspace.shared.frontmostApplication else {
            return false
        }

        let pid = targetApp.processIdentifier

        // Wait a moment for any click events to complete
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms for click event completion

        // Activate target app to ensure it has keyboard focus
        targetApp.activate(options: [.activateIgnoringOtherApps])
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms for activation (increased from 250ms)

        var successCount = 0
        let chars = Array(text)

        for char in chars {
            let utf16 = Array(String(char).utf16)
            guard !utf16.isEmpty else { continue }

            guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true) else {
                continue
            }

            utf16.withUnsafeBufferPointer { buffer in
                keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: buffer.baseAddress)
            }

            keyDown.postToPid(pid)

            try? await Task.sleep(nanoseconds: 8_000_000)

            guard let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) else {
                continue
            }

            utf16.withUnsafeBufferPointer { buffer in
                keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: buffer.baseAddress)
            }

            keyUp.postToPid(pid)

            successCount += 1
        }

        return successCount == chars.count
    }
}
