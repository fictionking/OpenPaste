import SwiftUI

/// Represents a single token extracted from clipboard text
struct TextToken: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let entityType: TokenType
    var isSelected: Bool = false

    init(text: String, entityType: TokenType) {
        self.text = text
        self.entityType = entityType
    }

    static func == (lhs: TextToken, rhs: TextToken) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.entityType == rhs.entityType &&
        lhs.isSelected == rhs.isSelected
    }
}

/// Entity types detected by Natural Language framework
enum TokenType: String, CaseIterable {
    case personalName     // Person names (e.g., "John Doe")
    case organizationName  // Organizations (e.g., "Apple Inc.")
    case placeName        // Places (e.g., "Cupertino")
    case url              // URLs/Links
    case number           // Numbers/dates
    case plain            // Regular words with no entity tag

    /// Display color for this token type
    var color: Color {
        switch self {
        case .personalName:
            return Color(red: 0x4A / 255, green: 0x90 / 255, blue: 0xD9 / 255) // Blue
        case .organizationName:
            return Color(red: 0x9B / 255, green: 0x59 / 255, blue: 0xB6 / 255) // Purple
        case .placeName:
            return Color(red: 0x27 / 255, green: 0xAE / 255, blue: 0x60 / 255) // Green
        case .url:
            return Color(red: 0xE6 / 255, green: 0x7E / 255, blue: 0x22 / 255) // Orange
        case .number:
            return Color(red: 0xF3 / 255, green: 0x9C / 255, blue: 0x12 / 255) // Yellow
        case .plain:
            return Color.primary.opacity(0.8)
        }
    }

    /// Localized display name
    var displayName: String {
        switch self {
        case .personalName: return "人名"
        case .organizationName: return "组织"
        case .placeName: return "地点"
        case .url: return "链接"
        case .number: return "数字"
        case .plain: return "普通"
        }
    }
}
