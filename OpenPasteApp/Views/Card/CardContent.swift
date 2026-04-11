import SwiftUI

/// Card content router that displays appropriate content view based on content type
struct CardContent: View {
    let item: ClipboardItemSummary

    private let fixedHeight: CGFloat = 108

    /// Calculate appropriate height based on content type
    private var contentHeight: CGFloat {
        switch item.contentType {
        case "public.color-code":
            return 140  // Extra space for format selector buttons
        default:
            return fixedHeight
        }
    }

    var body: some View {
        Group {
            switch item.contentType {
            case "public.utf8-plain-text", "public.text":
                TextView(content: item.content)
            case "public.image", "public.tiff", "public.png":
                ImageView(content: item.content)
            case "public.folder":
                FolderView(content: item.content)
            case "public.file-url":
                FileView(content: item.content)
            case "public.url":
                URLView(content: item.content)
            case "public.email":
                TextView(content: item.content)
            case "public.phone-number":
                TextView(content: item.content)
            case "public.color-code":
                ColorCodeView(content: item.content)
            default:
                DefaultView(content: item.content, contentType: item.contentType)
            }
        }
        .frame(height: contentHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(contentBackground)
    }

    // MARK: - Background

    @ViewBuilder
    private var contentBackground: some View {
        Color.white
    }
}

// MARK: - Preview

#Preview("Text Content") {
    CardContent(item: ClipboardItemSummary(
        id: UUID(),
        content: "Example clipboard text content that spans multiple lines and should be displayed properly",
        contentType: "public.utf8-plain-text",
        sourceApp: "Safari",
        capturedAt: Date(),
        isPinned: false,
        categoryId: nil,
        title: nil
    ))
    .frame(width: 300)
}

#Preview("Image Content") {
    CardContent(item: ClipboardItemSummary(
        id: UUID(),
        content: "[]",
        contentType: "public.image",
        sourceApp: "Photos",
        capturedAt: Date(),
        isPinned: false,
        categoryId: nil,
        title: nil
    ))
    .frame(width: 300)
}

#Preview("File Content") {
    CardContent(item: ClipboardItemSummary(
        id: UUID(),
        content: "[\"file:///Users/example/Documents/report.pdf\"]",
        contentType: "public.file-url",
        sourceApp: "Finder",
        capturedAt: Date(),
        isPinned: false,
        categoryId: nil,
        title: nil
    ))
    .frame(width: 300)
}
