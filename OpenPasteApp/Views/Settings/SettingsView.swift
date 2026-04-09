import SwiftUI
import AppKit
import Carbon

// MARK: - SettingsView
/// Settings screen for hotkey, retention period, history size, and theme preferences.
/// All settings persist via UserDefaults and survive app restarts.
struct SettingsView: View {
    // MARK: - Properties

    /// App settings model
    @StateObject private var settings = AppSettings.shared

    /// Showing hotkey customization alert
    @State private var showingHotkeyAlert = false

    /// Which hotkey is being recorded (nil = clipboard hotkey, true = explosion hotkey)
    @State private var recordingExplosionHotkey: Bool = false

    /// Currently recorded key combo during recording
    @State private var recordingKeyCombo: KeyCombo?

    /// Event monitor for hotkey recording
    @State private var eventMonitor: Any?

    /// ViewModel for clearing data
    var viewModel: ClipboardViewModel?

    // MARK: - Actions

    /// Quit the application
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Computed Properties


    /// Progressive glass background for settings sections
    @ViewBuilder
    private var sectionBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .background(Color.black.opacity(0.5))
    }

    // MARK: - Section Views

    /// Keyboard shortcut section
    private var keyboardShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Settings.keyboard)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 4)

            // Clipboard history hotkey
            HStack {
                Text(L10n.Settings.clipboardHistory)
                    .foregroundColor(.white)
                    .accessibilityLabel("Global keyboard shortcut for clipboard history")

                Spacer()

                Button(action: { startRecording(explosionHotkey: false) }) {
                    Text(settings.hotkeyDescription)
                        .font(.body.monospaced())
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .accessibilityLabel("Change keyboard shortcut")
                .accessibilityHint("Current shortcut is \(settings.hotkeyDescription)")
            }

            Divider()

            // Text explosion hotkey
            HStack {
                Text(L10n.Settings.textExplosion)
                    .foregroundColor(.white)
                    .accessibilityLabel("Global keyboard shortcut for text explosion")

                Spacer()

                Button(action: { startRecording(explosionHotkey: true) }) {
                    Text(settings.explosionHotkeyDescription)
                        .font(.body.monospaced())
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .accessibilityLabel("Change text explosion shortcut")
                .accessibilityHint("Current shortcut is \(settings.explosionHotkeyDescription)")
            }
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    /// Data management section
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Settings.dataManagement)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.Settings.retentionPeriod)
                        .foregroundColor(.white)
                        .accessibilityLabel("Clipboard item retention period")

                    Spacer()

                    Text(L10n.Settings.retentionDays.localized(with: settings.retentionDays))
                        .foregroundColor(.white.opacity(0.7))
                        .accessibilityLabel(L10n.Settings.retentionDays.localized(with: settings.retentionDays))
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Slider(
                    value: Binding(
                        get: { Double(settings.retentionDays) },
                        set: { settings.retentionDays = Int($0) }
                    ),
                    in: 7...90,
                    step: 1
                )
                .accessibilityValue(L10n.Settings.retentionDays.localized(with: settings.retentionDays))
                .labelsHidden()

                Text(L10n.Settings.retentionHint)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

            Divider()

            SlideToConfirmView(
                title: L10n.SlideAction.slideToClearAll,
                themeColor: .red,
                onConfirm: {
                    Task {
                        await viewModel?.clearAllData()
                    }
                }
            )
            .accessibilityLabel("Clear all clipboard data")
            .accessibilityHint("Slide the slider to the right to confirm clearing all data")
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    /// History section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Settings.history)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.Settings.maximumHistory)
                        .foregroundColor(.white)
                        .accessibilityLabel("Maximum clipboard history size")

                    Spacer()

                    Text(L10n.Settings.maximumHistoryItems.localized(with: settings.maxHistorySize.formatted()))
                        .foregroundColor(.white.opacity(0.7))
                        .accessibilityLabel(L10n.Settings.maximumHistoryItems.localized(with: settings.maxHistorySize.formatted()))
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Slider(
                    value: Binding(
                        get: { Double(settings.maxHistorySize) },
                        set: { settings.maxHistorySize = Int($0) }
                    ),
                    in: 1_000...50_000,
                    step: 1_000
                )
                .accessibilityValue(L10n.Settings.maximumHistoryItems.localized(with: settings.maxHistorySize.formatted()))
                .labelsHidden()

                Text(L10n.Settings.historyHint)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    /// About section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Settings.about)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 4)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenPaste")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(L10n.Settings.version.localized(with: settings.appVersion))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Link(L10n.Settings.viewLicense, destination: URL(string: "https://opensource.org/licenses/MIT")!)
                    .font(.caption)
                    .foregroundColor(.white)
            }

            Divider()

            Button(action: quitApp) {
                Text(L10n.Settings.quitApp)
                    .foregroundColor(.red)
            }
            .background(Color.black.opacity(0.5))
            .cornerRadius(6)
            .accessibilityLabel("Quit OpenPaste application")
        }
        .padding()
        .background(sectionBackground)
        .cornerRadius(10)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                keyboardShortcutSection
                dataManagementSection
                historySection
                aboutSection
            }
            .padding()
        }
        .navigationTitle(L10n.Settings.settings)
        .sheet(isPresented: $showingHotkeyAlert) {
            hotkeyRecordingSheet
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Hotkey Recording Sheet

    private var hotkeyRecordingSheet: some View {
        VStack(spacing: 20) {
            Text(recordingExplosionHotkey ? L10n.Settings.recordExplosionHotkey : L10n.Settings.recordClipboardHotkey)
                .font(.headline)
                .foregroundColor(.white)

            Text(L10n.Settings.pressKeyCombo)
                .font(.body)
                .foregroundColor(.white.opacity(0.7))

            // Display current recording
            if let combo = recordingKeyCombo {
                HStack(spacing: 8) {
                    ForEach(modifiersSymbols(for: combo), id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .cornerRadius(6)
                    }
                    if let key = combo.key {
                        Text(key.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .cornerRadius(6)
                    }
                }
                .padding()
            } else {
                Text(L10n.Settings.recording)
                    .font(.body.monospaced())
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            }

            HStack(spacing: 12) {
                Button(L10n.Settings.cancel) {
                    stopRecording()
                    showingHotkeyAlert = false
                }
                .keyboardShortcut(.escape)

                Button(L10n.Settings.save) {
                    saveHotkey()
                    showingHotkeyAlert = false
                }
                .keyboardShortcut(.return)
                .disabled(recordingKeyCombo == nil)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 400, height: 250)
        .onAppear {
            startRecordingMonitor()
        }
    }

    // MARK: - Hotkey Recording

    private func startRecording(explosionHotkey: Bool) {
        recordingExplosionHotkey = explosionHotkey
        recordingKeyCombo = nil
        showingHotkeyAlert = true
    }

    private func startRecordingMonitor() {
        // Remove any existing monitor
        stopRecording()

        // Track current modifiers
        var currentModifiers: NSEvent.ModifierFlags = []

        // Monitor for key down events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [self] event in
            switch event.type {
            case .flagsChanged:
                // Track modifier keys
                currentModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

            case .keyDown:
                // Check if we have a valid key with modifiers
                let keyCode = UInt32(event.keyCode)
                guard let key = Key(carbonKeyCode: keyCode),
                      key != .command,
                      key != .shift,
                      key != .option,
                      key != .control,
                      key != .function else {
                    return event
                }

                // Require at least one modifier (safety check to prevent conflicts)
                let modifiers = currentModifiers
                guard !modifiers.isEmpty else {
                    return event
                }

                // Create the key combo
                recordingKeyCombo = KeyCombo(key: key, modifiers: modifiers)

                // Don't process the event further
                return nil

            default:
                break
            }

            return event
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func saveHotkey() {
        guard let combo = recordingKeyCombo else { return }

        if recordingExplosionHotkey {
            settings.explosionHotkeyCode = combo.carbonKeyCode
            settings.explosionHotkeyModifiers = combo.carbonModifiers
        } else {
            settings.hotkeyCode = combo.carbonKeyCode
            settings.hotkeyModifiers = combo.carbonModifiers
        }

        stopRecording()

        // Post notification to reload hotkeys
        NotificationCenter.default.post(name: NSNotification.Name("ReloadHotkeys"), object: nil)
    }

    // MARK: - Key Combo Display Helpers

    private func modifiersSymbols(for keyCombo: KeyCombo) -> [String] {
        var symbols: [String] = []
        if keyCombo.modifiers.contains(.command) { symbols.append("⌘") }
        if keyCombo.modifiers.contains(.shift) { symbols.append("⇧") }
        if keyCombo.modifiers.contains(.option) { symbols.append("⌥") }
        if keyCombo.modifiers.contains(.control) { symbols.append("⌃") }
        return symbols
    }
}

// MARK: - AppSettings

/// App settings model with UserDefaults persistence
final class AppSettings: ObservableObject {
    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - Published Properties

    /// Keyboard shortcut modifiers (bitmask) for clipboard history
    @Published var hotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers)
        }
    }

    /// Keyboard shortcut key code for clipboard history
    @Published var hotkeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyCode, forKey: Keys.hotkeyCode)
        }
    }

    /// Keyboard shortcut modifiers (bitmask) for text explosion
    @Published var explosionHotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(explosionHotkeyModifiers, forKey: Keys.explosionHotkeyModifiers)
        }
    }

    /// Keyboard shortcut key code for text explosion
    @Published var explosionHotkeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(explosionHotkeyCode, forKey: Keys.explosionHotkeyCode)
        }
    }

    /// Retention period in days (7-90)
    @Published var retentionDays: Int {
        didSet {
            UserDefaults.standard.set(retentionDays, forKey: Keys.retentionDays)
        }
    }

    /// Maximum history size (1,000-50,000)
    @Published var maxHistorySize: Int {
        didSet {
            UserDefaults.standard.set(maxHistorySize, forKey: Keys.maxHistorySize)
        }
    }

    /// Theme preference
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
        }
    }

    /// App version
    let appVersion: String

    // MARK: - Computed Properties

    /// Human-readable hotkey description (e.g., "⌘⇧V")
    var hotkeyDescription: String {
        var parts: [String] = []
        if hotkeyModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if hotkeyModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if hotkeyModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if hotkeyModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if let key = Key(carbonKeyCode: hotkeyCode) {
            parts.append(key.description)
        } else {
            parts.append("V")
        }
        return parts.joined()
    }

    /// Human-readable explosion hotkey description (e.g., "⌘⇧B")
    var explosionHotkeyDescription: String {
        var parts: [String] = []
        if explosionHotkeyModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if explosionHotkeyModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if explosionHotkeyModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if explosionHotkeyModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if let key = Key(carbonKeyCode: explosionHotkeyCode) {
            parts.append(key.description)
        } else {
            parts.append("B")
        }
        return parts.joined()
    }

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults into local variables first to avoid
        // accessing self before all stored properties are initialized
        let modifiers = UInt32(UserDefaults.standard.integer(forKey: Keys.hotkeyModifiers))
        self.hotkeyModifiers = modifiers == 0 ? UInt32(cmdKey) | UInt32(shiftKey) : modifiers

        let code = UInt32(UserDefaults.standard.integer(forKey: Keys.hotkeyCode))
        self.hotkeyCode = code == 0 ? UInt32(kVK_ANSI_V) : code

        let explosionModifiers = UInt32(UserDefaults.standard.integer(forKey: Keys.explosionHotkeyModifiers))
        self.explosionHotkeyModifiers = explosionModifiers == 0 ? UInt32(cmdKey) | UInt32(shiftKey) : explosionModifiers

        let explosionCode = UInt32(UserDefaults.standard.integer(forKey: Keys.explosionHotkeyCode))
        self.explosionHotkeyCode = explosionCode == 0 ? UInt32(kVK_ANSI_B) : explosionCode

        let retention = UserDefaults.standard.integer(forKey: Keys.retentionDays)
        self.retentionDays = retention == 0 ? 30 : retention

        let maxHistory = UserDefaults.standard.integer(forKey: Keys.maxHistorySize)
        self.maxHistorySize = maxHistory == 0 ? 10_000 : maxHistory

        if let themeRaw = UserDefaults.standard.string(forKey: Keys.theme),
           let loadedTheme = AppTheme(rawValue: themeRaw) {
            self.theme = loadedTheme
        } else {
            self.theme = .auto
        }

        // App version from Info.plist
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Keys

    enum Keys {
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyCode = "hotkeyCode"
        static let explosionHotkeyModifiers = "explosionHotkeyModifiers"
        static let explosionHotkeyCode = "explosionHotkeyCode"
        static let retentionDays = "retentionDays"
        static let maxHistorySize = "maxHistorySize"
        static let theme = "theme"
    }
}

// MARK: - AppTheme

/// App theme options
enum AppTheme: String {
    case light
    case dark
    case auto

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

import Carbon

// MARK: - Preview

#Preview {
    NavigationView {
        SettingsView()
    }
}
