import Foundation

/// Category selector for unified sidebar navigation
/// Represents either a preset category, custom category, or settings
enum CategorySelector: Equatable {
    case preset(PresetCategory)
    case custom(UUID)
    case search
    case settings

    // MARK: - Computed Properties

    /// Unique identifier for the selection
    var id: String {
        switch self {
        case .preset(let preset):
            return "preset_\(preset.rawValue)"
        case .custom(let uuid):
            return "custom_\(uuid.uuidString)"
        case .search:
            return "search"
        case .settings:
            return "settings"
        }
    }

    /// Display name for the selection
    var displayName: String {
        switch self {
        case .preset(let preset):
            return preset.displayName
        case .custom:
            return L10n.Category.custom
        case .search:
            return L10n.Common.search
        case .settings:
            return L10n.Common.settings
        }
    }

    /// SF Symbol icon for the selection
    var icon: String {
        switch self {
        case .preset(let preset):
            return preset.icon
        case .custom:
            return "folder"
        case .search:
            return "magnifyingglass"
        case .settings:
            return "gearshape"
        }
    }

    /// Whether this selection points to settings
    var isSettings: Bool {
        if case .settings = self {
            return true
        }
        return false
    }
}
