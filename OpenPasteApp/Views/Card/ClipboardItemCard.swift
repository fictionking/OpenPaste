import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Complete clipboard item card combining header and content
struct ClipboardItemCard: View {
    let item: ClipboardItemSummary
    var isCurrent: Bool = false
    var onCategoryChange: ((UUID?) -> Void)?
    var onDelete: (() -> Void)?
    var onTitleChange: ((String) -> Void)?
    var onCopy: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(
                contentType: item.contentType,
                sourceApp: item.sourceApp,
                capturedAt: item.capturedAt,
                categoryId: item.categoryId,
                title: item.title,
                onCategorySelect: onCategoryChange,
                onTitleChange: onTitleChange,
                onDelete: onDelete
            )

            CardContent(item: item)
                .onTapGesture {
                    onCopy?()
                }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .blue.opacity(0.6), radius: isCurrent ? 15 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isCurrent ? 3 : 0
                )
        )
    }

    // MARK: - Card Background

    @ViewBuilder
    private var cardBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                )
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - Preview

#Preview("Text Card") {
    ClipboardItemCard(
        item: ClipboardItemSummary(
            id: UUID(),
            content: "Example clipboard text content that spans multiple lines",
            contentType: "public.utf8-plain-text",
            sourceApp: "Safari",
            capturedAt: Date().addingTimeInterval(-300),
            isPinned: false,
            categoryId: nil,
            title: nil
        ),
        onCopy: { print("Copy triggered") }
    )
    .frame(width: 300)
    .padding()
}

#Preview("Pinned Card") {
    ClipboardItemCard(
        item: ClipboardItemSummary(
            id: UUID(),
            content: "Pinned item with important content",
            contentType: "public.utf8-plain-text",
            sourceApp: "Finder",
            capturedAt: Date(),
            isPinned: true,
            categoryId: nil,
            title: nil
        ),
        onCopy: { print("Copy triggered") }
    )
    .frame(width: 300)
    .padding()
}

#Preview("Image Card") {
    ClipboardItemCard(
        item: ClipboardItemSummary(
            id: UUID(),
            content: "Image data",
            contentType: "public.image",
            sourceApp: "Photos",
            capturedAt: Date().addingTimeInterval(-600),
            isPinned: false,
            categoryId: nil,
            title: nil
        ),
        onCopy: { print("Copy triggered") }
    )
    .frame(width: 300)
    .padding()
}
