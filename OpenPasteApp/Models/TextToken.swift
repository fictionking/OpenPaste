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
    case personalName      // Person names (e.g., "张三")
    case organizationName   // Organizations (e.g., "苹果公司")
    case placeName          // Places (e.g., "北京")
    case phoneNumber       // Phone numbers
    case url                // URLs/Links
    case currency           // Currency amounts
    case date               // Dates
    case address            // Addresses
    case shipmentTrackingNumber // Package tracking numbers
    case flightNumber       // Flight numbers
    case number             // General numbers
    case plain              // Regular words with no entity tag

    /// Display color for this token type
    var color: Color {
        switch self {
        case .personalName:
            return Color(red: 0xFF / 255, green: 0x3B / 255, blue: 0x30 / 255) // Red
        case .organizationName:
            return Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x00 / 255) // Orange
        case .placeName:
            return Color(red: 0xFF / 255, green: 0xFF / 255, blue: 0x00 / 255) // Yellow
        case .phoneNumber:
            return Color(red: 0x00 / 255, green: 0xFF / 255, blue: 0x00 / 255) // Green
        case .url:
            return Color(red: 0x00 / 255, green: 0xFF / 255, blue: 0xFF / 255) // Cyan
        case .currency:
            return Color(red: 0x00 / 255, green: 0x7F / 255, blue: 0xFF / 255) // Sky Blue
        case .date:
            return Color(red: 0xB4 / 255, green: 0x00 / 255, blue: 0xFF / 255) // Bright Purple
        case .address:
            return Color(red: 0xFF / 255, green: 0x00 / 255, blue: 0xFF / 255) // Magenta
        case .shipmentTrackingNumber:
            return Color(red: 0xFF / 255, green: 0x00 / 255, blue: 0x7F / 255) // Pink
        case .flightNumber:
            return Color(red: 0xFF / 255, green: 0x00 / 255, blue: 0xFF / 255) // Bright Pink
        case .number:
            return Color(red: 0x80 / 255, green: 0x80 / 255, blue: 0x80 / 255) // Gray
        case .plain:
            return Color(red: 0x60 / 255, green: 0x60 / 255, blue: 0x60 / 255) // Dark Gray
        }
    }

    /// Localized display name
    var displayName: String {
        return "*"
    }

    /// SF Symbol icon name for this token type
    var iconName: String {
        switch self {
        case .personalName: return "person.fill"
        case .organizationName: return "building.2.fill"
        case .placeName: return "location.fill"
        case .phoneNumber: return "phone.fill"
        case .url: return "link"
        case .currency: return "dollarsign.circle"  // Use non-fill version
        case .date: return "calendar"
        case .address: return "house.fill"
        case .shipmentTrackingNumber: return "truck.box.fill"
        case .flightNumber: return "airplane.departure"
        case .number: return "number"
        case .plain: return "asterisk"
        }
    }
}
