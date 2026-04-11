import Foundation
import SwiftUI

/// Preset category types for sidebar navigation
/// Represents built-in categories and 4 fixed favorite categories
enum PresetCategory: String, CaseIterable {
    // Sort order 1: Recent items (all items, sorted by date)
    case recent

    // Sort order 2: Text content (plain + rich text combined)
    case text

    // Sort order 3: Code snippets
    case code

    // Sort order 4: Images
    case image

    // Sort order 6: Files
    case file

    // Sort order 7: Links/URLs
    case link

    // Sort order 8: Email addresses
    case email

    // Sort order 9: Phone numbers
    case phoneNumber

    // Sort order 10: Color codes (hex, rgb, etc.)
    case colorCode

    // Sort order 11-14: Fixed favorite categories
    case favorite1
    case favorite2
    case favorite3
    case favorite4

    // MARK: - Properties

    /// Localized display name for the category
    var localizedName: String {
        switch self {
        case .recent: return L10n.Category.recent
        case .text: return L10n.Category.text
        case .code: return L10n.Category.code
        case .image: return L10n.Category.image
        case .file: return L10n.Category.file
        case .link: return L10n.Category.link
        case .email: return L10n.Category.email
        case .phoneNumber: return L10n.Category.phone
        case .colorCode: return L10n.Category.color
        case .favorite1: return L10n.Category.favorite1
        case .favorite2: return L10n.Category.favorite2
        case .favorite3: return L10n.Category.favorite3
        case .favorite4: return L10n.Category.favorite4
        }
    }

    /// Display name for the category (with custom name fallback)
    var displayName: String {
        return customDisplayName ?? localizedName
    }

    /// SF Symbol icon for the category
    var icon: String {
        switch self {
        case .recent:
            return "clock.arrow.circlepath"
        case .text:
            return "doc.text"
        case .code:
            return "curlybraces"
        case .image:
            return "photo"
        case .file:
            return "doc"
        case .link:
            return "link"
        case .email:
            return "envelope"
        case .phoneNumber:
            return "phone"
        case .colorCode:
            return "paintpalette"
        case .favorite1:
            return "pin.fill"
        case .favorite2:
            return "pin.fill"
        case .favorite3:
            return "pin.fill"
        case .favorite4:
            return "pin.fill"
        }
    }

    /// Icon color for favorite categories
    var iconColor: Color? {
        switch self {
        case .favorite1:
            return .red
        case .favorite2:
            return .orange
        case .favorite3:
            return .yellow
        case .favorite4:
            return .green
        default:
            return nil
        }
    }

    /// Sort order in sidebar
    var sortOrder: Int {
        switch self {
        case .recent: return 1
        case .text: return 2
        case .code: return 3
        case .image: return 4
        case .file: return 5
        case .link: return 6
        case .email: return 7
        case .phoneNumber: return 8
        case .colorCode: return 9
        case .favorite1: return 10
        case .favorite2: return 11
        case .favorite3: return 12
        case .favorite4: return 13
        }
    }

    /// Custom display name (can be modified in settings)
    var customDisplayName: String? {
        return UserDefaults.standard.string(forKey: "preset_\(self.rawValue)_name")
    }

    /// Update custom display name
    func setCustomDisplayName(_ name: String) {
        UserDefaults.standard.set(name, forKey: "preset_\(self.rawValue)_name")
    }

    // MARK: - Content Matching

    /// Check if a clipboard item matches this preset category
    /// - Parameter item: The clipboard item data to check
    /// - Returns: True if the item belongs to this category
    func matches(_ item: ClipboardItemSummary) -> Bool {
        switch self {
        case .recent:
            // Recent shows everything
            return true

        case .text:
            // Text content types
            return isTextContentType(item.contentType)

        case .code:
            // Code file extensions or syntax
            return isCodeContentType(item.contentType) || item.content.contains("func ") || item.content.contains("var ")

        case .image:
            // Image content types
            return isImageContentType(item.contentType)

        case .file:
            // File attachments (not text, image, or code)
            return isFileContentType(item.contentType)

        case .link:
            // URLs or links — only pure link type, not text containing URLs
            return item.contentType == "public.url"

        case .email:
            // Email addresses
            return item.contentType == "public.email"

        case .phoneNumber:
            // Phone numbers (international, with parentheses, mobile, etc.)
            return item.contentType == "public.phone-number"

        case .colorCode:
            // Hex color codes (3-digit, 6-digit, and 8-digit with alpha)
            return item.contentType == "public.color-code"

        case .favorite1, .favorite2, .favorite3, .favorite4:
            // Favorites only show manually assigned items
            // Check if item's categoryId matches this favorite's UUID
            return item.categoryId == favoriteUUID
        }
    }

    /// Build NSPredicate for database query
    /// - Returns: NSPredicate for filtering clipboard items in Core Data
    func predicate() -> NSPredicate {
        switch self {
        case .recent:
            // Recent shows everything (no filter)
            return NSPredicate(value: true)

        case .text:
            // Text content types
            return NSPredicate(format: "contentType IN %@", [
                "public.utf8-plain-text", "public.rtf", "public.html",
                "com.apple.flat-rtfd", "public.text"
            ])

        case .code:
            // Code content types (simplified - code detection may need content scanning)
            return NSPredicate(format: "contentType IN %@", [
                "public.source-code", "public.script", "public.program"
            ])

        case .image:
            // Image content types
            return NSPredicate(format: "contentType IN %@", [
                "public.image", "public.tiff", "public.png", "public.jpeg"
            ])

        case .file:
            // File attachments
            return NSPredicate(format: "contentType == %@", "public.file-url")

        case .link:
            // URLs
            return NSPredicate(format: "contentType == %@", "public.url")

        case .email:
            // Email addresses
            return NSPredicate(format: "contentType == %@", "public.email")

        case .phoneNumber:
            // Phone numbers
            return NSPredicate(format: "contentType == %@", "public.phone-number")

        case .colorCode:
            // Hex color codes
            return NSPredicate(format: "contentType == %@", "public.color-code")

        case .favorite1, .favorite2, .favorite3, .favorite4:
            // Favorites - match by category ID
            return NSPredicate(format: "category.id == %@", favoriteUUID as CVarArg)
        }
    }

    /// UUID for this favorite category (used for matching)
    var favoriteUUID: UUID {
        // Generate consistent UUID based on raw value
        switch self {
        case .favorite1:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case .favorite2:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        case .favorite3:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        case .favorite4:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        default:
            return UUID()
        }
    }

    // MARK: - Content Type Helpers

    private func isTextContentType(_ contentType: String) -> Bool {
        return contentType == "public.utf8-plain-text" ||
               contentType == "public.rtf" ||
               contentType == "public.html" ||
               contentType == "com.apple.flat-rtfd" ||
               contentType.hasPrefix("public.text")
    }

    private func isCodeContentType(_ contentType: String) -> Bool {
        let codeExtensions = [
            "public.swift-source",
            "public.objective-c-source",
            "public.c-source",
            "public.c-plus-plus-source",
            "com.sun.java-source",
            "com.microsoft.java-source",
            "public.python-script",
            "com.netscape.javascript-source",
            "com.adobe.javascript-source",
            "public.xml",
            "com.apple.property-list",
            "public.json",
            "com.apple.swift-syntaxhighlight"
        ]
        return codeExtensions.contains(contentType) || contentType.hasPrefix("public.source-code")
    }

    private func isImageContentType(_ contentType: String) -> Bool {
        return contentType.hasPrefix("public.image") ||
               contentType == "com.adobe.pdf" ||
               contentType.hasSuffix(".png") ||
               contentType.hasSuffix(".jpg") ||
               contentType.hasSuffix(".jpeg") ||
               contentType.hasSuffix(".gif") ||
               contentType.hasSuffix(".webp")
    }

    private func isFileContentType(_ contentType: String) -> Bool {
        // Only match specific file and folder types
        let fileTypes = [
            "public.file-url",      // Files
            "public.folder",         // Folders
            "public.data",
            "public.content",
            "com.adobe.pdf",
            "public.archive",
            "public.zip-archive",
            "com.apple.disk-image"
        ]
        return fileTypes.contains(contentType)
    }
}
