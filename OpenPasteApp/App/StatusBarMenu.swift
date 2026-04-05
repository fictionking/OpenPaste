//
//  StatusBarMenu.swift
//  OpenPaste
//
//  Created on 2026-03-28.
//

import Foundation
import AppKit
import Carbon

class StatusBarMenu: NSObject {
    private var statusItem: NSStatusItem?
    private var hotkeyRef: EventHotKeyRef?

    override init() {
        super.init()
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "📋"
            button.toolTip = "OpenPaste - ⌘⇧V"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.StatusBar.openHistory, action: #selector(showPanel), keyEquivalent: "v"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.StatusBar.quit, action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu

        // Register global hotkey using Carbon API
        registerHotkey()
    }

    private func registerHotkey() {
        let hotkeyID = EventHotKeyID(signature: OSType(0x4F505354), id: 1)
        let keyCode: UInt32 = 9 // V key
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)

        if status == noErr {
            print("✅ Hotkey registered successfully")
            updateStatusTitle("📋✅")
        } else {
            print("❌ Failed to register hotkey: \(status)")
            updateStatusTitle("📋❌")
        }
    }

    @objc private func showPanel() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowFloatingPanel"), object: nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateStatusTitle(_ title: String) {
        DispatchQueue.main.async {
            self.statusItem?.button?.title = title
        }
    }
}
