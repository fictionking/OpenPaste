import Foundation

/// Lightweight summary for list display, filtering, and counting.
/// Includes `content` because CardContent.swift reads `item.content` directly for every card.
/// Excludes only the heaviest fields (allPasteboardData, allPasteboardTypes) that are loaded on demand.
struct ClipboardItemSummary: Identifiable, Equatable {
    let id: UUID
    let content: String              // REQUIRED: CardContent.swift reads item.content for display
    let contentType: String          // needed by updateAvailableFilters()
    let sourceApp: String?           // needed by updateAvailableFilters()
    let capturedAt: Date             // needed by updateRecentItemCount()
    let isPinned: Bool               // needed for pin-based sorting
    let categoryId: UUID?            // needed for category filtering
    let title: String?               // needed by filteredSearchItems for title search

    /// Equatable comparison
    static func == (lhs: ClipboardItemSummary, rhs: ClipboardItemSummary) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.contentType == rhs.contentType &&
        lhs.sourceApp == rhs.sourceApp &&
        lhs.capturedAt == rhs.capturedAt &&
        lhs.isPinned == rhs.isPinned &&
        lhs.categoryId == rhs.categoryId &&
        lhs.title == rhs.title
    }

    /// Convert summary to full ClipboardItemData (for Preview compatibility)
    /// Note: allPasteboardData and allPasteboardTypes will be nil
    func toItemData() -> ClipboardItemData {
        return ClipboardItemData(
            id: id,
            content: content,
            contentType: contentType,
            sourceApp: sourceApp,
            capturedAt: capturedAt,
            isPinned: isPinned,
            categoryId: categoryId,
            title: title,
            allPasteboardData: nil,
            allPasteboardTypes: nil
        )
    }
}

/// Data model for clipboard item display (value type for UI layer)
struct ClipboardItemData: Identifiable, Equatable {
    let id: UUID
    let content: String
    let contentType: String
    let sourceApp: String?
    let capturedAt: Date
    let isPinned: Bool
    let categoryId: UUID?  // Category assignment for filtering
    let title: String?  // Rich link title or additional metadata
    let allPasteboardData: Data?  // Complete pasteboard data for restoration
    let allPasteboardTypes: String?  // JSON string of all pasteboard types

    /// Equatable comparison - ignore pasteboard data for equality checks
    static func == (lhs: ClipboardItemData, rhs: ClipboardItemData) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.contentType == rhs.contentType &&
        lhs.sourceApp == rhs.sourceApp &&
        lhs.capturedAt == rhs.capturedAt &&
        lhs.isPinned == rhs.isPinned &&
        lhs.categoryId == rhs.categoryId &&
        lhs.title == rhs.title
    }
}
