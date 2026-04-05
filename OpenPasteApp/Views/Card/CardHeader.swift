import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Card header displaying app icon, type title, timestamp, and category button
struct CardHeader: View {
    let contentType: String
    let sourceApp: String?
    let capturedAt: Date
    let categoryId: UUID?
    let title: String?
    var onCategorySelect: ((UUID?) -> Void)?
    var onTitleChange: ((String) -> Void)?
    var onDelete: (() -> Void)?

    @State private var appIcon: NSImage?
    @State private var dominantColor: Color = .clear
    @State private var fallbackAppIcon: NSImage?
    @State private var showingCategoryMenu = false
    @State private var isEditingTitle = false
    @State private var editingTitle = ""

    @State private var availableCategories: [CategoryData] = []

    /// Special identifier for iCloud synced content
    private let iCloudSyncIdentifier = "com.apple.icloud.clipboard"

    /// Whether this content appears to be from iCloud sync
    private var isICloudSynced: Bool {
        sourceApp == iCloudSyncIdentifier
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left side: App icon (overflowing left only)
            appIconView

            // Middle: Title + timestamp (with double-tap gesture)
            VStack(alignment: .leading, spacing: 2) {
                if isEditingTitle {
                    TextField("", text: $editingTitle)
                        .font(.system(size: 15, weight: .bold))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .onSubmit {
                            onTitleChange?(editingTitle)
                            isEditingTitle = false
                        }
                        .onAppear {
                            editingTitle = title ?? typeTitle
                        }
                } else {
                    Text(title ?? typeTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .contentShape(Rectangle())
                        .allowsHitTesting(true)
                }

                // Timestamp (below title, smaller)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.white)
                    Text(capturedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded { _ in
                        editingTitle = title ?? typeTitle
                        isEditingTitle = true
                    }
            )

            Spacer()

            // Right side: Pin indicator
            Image(systemName: categoryId != nil ? "pin.fill" : "pin")
                .font(.system(size: 16))
                .foregroundColor(categoryTintColor)
        }
        .frame(height: 40)  // Fixed height for header area
        .padding(.horizontal, 12)
        .allowsHitTesting(true)  // Explicitly allow interaction
        .background(dominantColor)
        .contextMenu {
            categoryMenuContent
        }
        .onAppear {
            // Load fallback app icon (our own app's icon)
            loadFallbackAppIcon()

            if let sourceApp = sourceApp {
                loadAppIcon(for: sourceApp)
                loadDominantColor(for: sourceApp)
            }
        }
        .clipped()  // Clip vertical overflow (applied last)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var categoryMenuContent: some View {
        // Four colored pin options using colored images
        Button {
            onCategorySelect?(PresetCategory.favorite1.favoriteUUID)
        } label: {
            coloredPinImage(hue: 0)    // Red
        }

        Button {
            onCategorySelect?(PresetCategory.favorite2.favoriteUUID)
        } label: {
            coloredPinImage(hue: 30)   // Orange
        }

        Button {
            onCategorySelect?(PresetCategory.favorite3.favoriteUUID)
        } label: {
            coloredPinImage(hue: 60)   // Yellow
        }

        Button {
            onCategorySelect?(PresetCategory.favorite4.favoriteUUID)
        } label: {
            coloredPinImage(hue: 120)  // Green
        }

        // Unpin option (show only if currently pinned)
        if categoryId != nil {
            Button(role: .none) {
                onCategorySelect?(nil)
            } label: {
                Image(systemName: "pin.slash")
                    .frame(width: 20, height: 20)
            }
        }

        Divider()

        // Delete option
        Button(role: .destructive) {
            onDelete?()
        } label: {
            Image(systemName: "trash")
                .frame(width: 20, height: 20)
        }
    }

    /// Create a colored pin image by applying hue rotation to the base pin image
    private func coloredPinImage(hue: Double) -> some View {
        Image(nsImage: generateColoredPinImage(hue: hue))
            .frame(width: 20, height: 20)
    }

    /// Generate an NSImage with the pin icon in a specific hue
    private func generateColoredPinImage(hue: Double) -> NSImage {
        // Create a red SwiftUI image of the pin as base
        let pinImage = Image(systemName: "pin.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.red)
            .frame(width: 20, height: 20)

        // Render to NSImage
        let renderer = ImageRenderer(content: pinImage)
        renderer.scale = 2.0  // Retina support
        guard let baseImage = renderer.nsImage else {
            return NSImage(size: NSSize(width: 20, height: 20))
        }

        // Get CGImage from NSImage
        guard let imageData = baseImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let cgImage = bitmap.cgImage else {
            return baseImage
        }

        // Apply hue filter
        guard let filter = CIFilter(name: "CIHueAdjust") else {
            return baseImage
        }

        filter.setValue(CIImage(cgImage: cgImage), forKey: kCIInputImageKey)
        filter.setValue(hue * .pi / 180, forKey: kCIInputAngleKey)

        guard let outputImage = filter.outputImage,
              let outputCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return baseImage
        }

        return NSImage(cgImage: outputCGImage, size: NSSize(width: 20, height: 20))
    }

    /// Get the actual color for a favorite category (non-optional)
    private func getColorForFavorite(_ favorite: PresetCategory) -> Color {
        switch favorite {
        case .favorite1: return .red
        case .favorite2: return .orange
        case .favorite3: return .yellow
        case .favorite4: return .green
        default: return .accentColor
        }
    }

    // MARK: - App Icon View

    private var appIconView: some View {
        Group {
            if isICloudSynced {
                // Show iCloud sync icon using image resource
                Image("ICloudIcon")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .offset(x: -20, y: 0)
                    .allowsHitTesting(false)
            } else if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .offset(x: -20, y: 0)
                    .allowsHitTesting(false)
            } else {
                // Show unified cloud icon for no app icon
                Image(systemName: "icloud")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .offset(x: -20, y: 0)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var iconBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Type Title

    private var typeTitle: String {
        switch contentType {
        case "public.utf8-plain-text", "public.text":
            return L10n.ContentType.text
        case "public.image", "public.tiff", "public.png":
            return L10n.ContentType.image
        case "public.folder":
            return L10n.ContentType.folder
        case "public.file-url":
            return L10n.ContentType.file
        case "public.url":
            return L10n.ContentType.link
        case "public.email":
            return L10n.ContentType.email
        case "public.phone-number":
            return L10n.ContentType.phone
        case "public.color-code":
            return L10n.ContentType.color
        default:
            return L10n.ContentType.content
        }
    }

    private var categoryTintColor: Color {
        guard let categoryId = categoryId else {
            return .white.opacity(0.6)
        }

        // Check if it's a preset favorite category
        if let preset = PresetCategory.allCases.first(where: { $0.favoriteUUID == categoryId }) {
            return preset.iconColor ?? .accentColor
        }

        // For custom categories, find their color
        if let category = availableCategories.first(where: { $0.id == categoryId }) {
            return colorForCategory(category)
        }

        return .accentColor
    }

    private func colorForCategory(_ category: CategoryData) -> Color {
        // Generate color based on category name hash for consistency
        let hash = category.name.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }

    // MARK: - Helper Methods

    private func loadAppIcon(for appName: String) {
        // Try bundle identifier first
        if #available(macOS 13.0, *) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
                appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                return
            }
        }

        // Try by app name using LSCopyApplicationURLsForBundleIdentifier
        if let appUrls = LSCopyApplicationURLsForBundleIdentifier(appName as CFString, nil)?.takeRetainedValue() as? [URL],
           let url = appUrls.first {
            appIcon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }

    private func loadFallbackAppIcon() {
        // Try to load our app's icon as fallback
        if let appIcon = NSImage(named: "AppIcon") {
            fallbackAppIcon = appIcon
        }
    }

    private func loadDominantColor(for appName: String) {
        Task { @MainActor in
            // Use iCloud brand color for synced content or when no app icon
            if appName == iCloudSyncIdentifier || appIcon == nil {
                dominantColor = Color.blue.opacity(0.15)
                return
            }

            let extractedColor = await AppIconColorExtractor.shared.extractColor(for: appName)
            // Adjust brightness if too high (for white text readability)
            dominantColor = adjustBrightnessIfNeeded(extractedColor)
        }
    }

    /// Adjust color brightness if it's too high for white text readability
    private func adjustBrightnessIfNeeded(_ color: Color) -> Color {
        // Extract RGB components from SwiftUI Color
        #if os(macOS)
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else {
            return color
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // If brightness is too high (>0.7), darken it and increase saturation
        if brightness > 0.7 {
            brightness = 0.55  // Reduce to 55%
            saturation = min(saturation * 1.3, 1.0)  // Increase saturation by 30%
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }

        return color
        #else
        return color
        #endif
    }

}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        CardHeader(
            contentType: "public.utf8-plain-text",
            sourceApp: "Safari",
            capturedAt: Date().addingTimeInterval(-300),
            categoryId: nil,
            title: nil,
            onTitleChange: { _ in }
        )

        CardHeader(
            contentType: "public.image",
            sourceApp: "Photos",
            capturedAt: Date().addingTimeInterval(-600),
            categoryId: UUID(),
            title: "我的照片",
            onTitleChange: { _ in }
        )
    }
    .frame(width: 300)
}
