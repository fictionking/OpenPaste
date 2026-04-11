import SwiftUI
import AppKit

// MARK: - ClipboardItemView
/// Individual clipboard item cell with support for different content types.
/// Now uses the new Card-based layout with separate header and content areas.
struct ClipboardItemView: View {
    // MARK: - Properties

    /// The clipboard item summary to display
    let item: ClipboardItemSummary

    /// Whether this item matches the current clipboard content
    var isCurrent: Bool = false

    /// Whether the item is currently visible (for lazy loading)
    var isVisible: Bool = true

    /// Action handler for category change
    var onCategoryChange: ((UUID?) -> Void)?

    /// Action handler for delete
    var onDelete: (() -> Void)?

    /// Action handler for title change
    var onTitleChange: ((String) -> Void)?

    /// Action handler for copying item to clipboard
    var onCopy: (() -> Void)?

    // MARK: - Body

    var body: some View {
        ClipboardItemCard(
            item: item,
            isCurrent: isCurrent,
            onCategoryChange: onCategoryChange,
            onDelete: onDelete,
            onTitleChange: onTitleChange,
            onCopy: onCopy
        )
    }
}

// MARK: - Preview

#Preview("Text Item") {
    VStack(spacing: 8) {
        ClipboardItemView(
            item: ClipboardItemSummary(
                id: UUID(),
                content: "Example clipboard text content that spans multiple lines",
                contentType: "public.utf8-plain-text",
                sourceApp: "Safari",
                capturedAt: Date().addingTimeInterval(-300),
                isPinned: false,
                categoryId: nil,
                title: nil
            )
        )

        ClipboardItemView(
            item: ClipboardItemSummary(
                id: UUID(),
                content: "Pinned item",
                contentType: "public.utf8-plain-text",
                sourceApp: "Finder",
                capturedAt: Date(),
                isPinned: true,
                categoryId: nil,
                title: nil
            )
        )
    }
    .padding()
    .frame(width: 300)
}

#Preview("Image Item") {
    ClipboardItemView(
        item: ClipboardItemSummary(
            id: UUID(),
            content: "Image data",
            contentType: "public.image",
            sourceApp: "Photos",
            capturedAt: Date().addingTimeInterval(-600),
            isPinned: false,
            categoryId: nil,
            title: nil
        )
    )
    .padding()
    .frame(width: 300)
}

#Preview("File Item") {
    ClipboardItemView(
        item: ClipboardItemSummary(
            id: UUID(),
            content: "[\"file:///Users/example/Documents/report.pdf\"]",
            contentType: "public.file-url",
            sourceApp: "Finder",
            capturedAt: Date(),
            isPinned: false,
            categoryId: nil,
            title: nil
        )
    )
    .padding()
    .frame(width: 300)
}
