import SwiftUI
import AppKit

/// Utility for extracting dominant colors from application icons
actor AppIconColorExtractor {
    /// Shared singleton instance
    static let shared = AppIconColorExtractor()

    /// Cache for extracted colors
    private var colorCache: [String: Color] = [:]

    private init() {}

    /// Extract dominant color for an app by name or bundle identifier
    /// - Parameter appName: App name or bundle identifier
    /// - Returns: Dominant color, or default gray if extraction fails
    func extractColor(for appName: String) -> Color {
        // Check cache first
        if let cached = colorCache[appName] {
            return cached
        }

        // Try to get app icon and extract color
        if let color = extractColorFromIcon(for: appName) {
            colorCache[appName] = color
            return color
        }

        // Fallback to a neutral gray
        let defaultColor = Color(red: 0.5, green: 0.5, blue: 0.5)
        colorCache[appName] = defaultColor
        return defaultColor
    }

    /// Extract dominant color directly from an NSImage
    /// - Parameter image: The image to extract color from
    /// - Returns: Dominant color, or default gray if extraction fails
    func extractColor(from image: NSImage) -> Color {
        if let color = extractDominantColor(from: image) {
            return color
        }
        return Color(red: 0.5, green: 0.5, blue: 0.5)
    }

    /// Extract dominant color from app icon
    private func extractColorFromIcon(for appName: String) -> Color? {
        // Try to get app URL by bundle identifier first
        var appURL: URL?

        if #available(macOS 13.0, *) {
            // Try as bundle identifier first
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
                appURL = url
            }
        }

        // If not found, try by app name using LSCopyApplicationURLsForBundleIdentifier
        if appURL == nil {
            if let appUrls = LSCopyApplicationURLsForBundleIdentifier(appName as CFString, nil)?.takeRetainedValue() as? [URL],
               let url = appUrls.first {
                appURL = url
            }
        }

        guard let url = appURL else {
            return nil
        }

        // Get app icon
        let icon = NSWorkspace.shared.icon(forFile: url.path)

        // Extract dominant color from image
        return extractDominantColor(from: icon)
    }

    /// Extract dominant color from an NSImage using bucket-based color frequency
    private func extractDominantColor(from image: NSImage) -> Color? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // Bucket counter: bucket key -> (sum R, sum G, sum B, count)
        var colorBuckets: [String: (r: Int, g: Int, b: Int, count: Int)] = [:]

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        // Uniform grid sampling across entire image
        // Calculate stride to get ~1000 samples
        let targetSamples = 1000
        let sampleStride = max(4, Int(sqrt(Double(width * height) / Double(targetSamples))))

        for y in stride(from: 0, to: height, by: sampleStride) {
            for x in stride(from: 0, to: width, by: sampleStride) {
                guard let color = bitmap.colorAt(x: x, y: y),
                      let rgb = color.usingColorSpace(.deviceRGB) else {
                    continue
                }

                let r = Int(rgb.redComponent * 255)
                let g = Int(rgb.greenComponent * 255)
                let b = Int(rgb.blueComponent * 255)

                // Skip extreme black/white
                if (r == 0 && g == 0 && b == 0) || (r == 255 && g == 255 && b == 255) {
                    continue
                }

                // Skip grayscale colors (R ≈ G ≈ B)
                let maxVal = max(r, g, b)
                let minVal = min(r, g, b)
                if maxVal - minVal < 15 {  // If difference is less than 15, it's grayscale
                    continue
                }

                // Moderate bucket size for accuracy
                let bucketSize = 16
                let bucketR = r / bucketSize
                let bucketG = g / bucketSize
                let bucketB = b / bucketSize

                let key = "\(bucketR),\(bucketG),\(bucketB)"

                if let existing = colorBuckets[key] {
                    colorBuckets[key] = (
                        r: existing.r + r,
                        g: existing.g + g,
                        b: existing.b + b,
                        count: existing.count + 1
                    )
                } else {
                    colorBuckets[key] = (r: r, g: g, b: b, count: 1)
                }
            }
        }

        guard !colorBuckets.isEmpty else {
            return nil
        }

        // Find bucket with highest frequency
        let mostFrequent = colorBuckets.max { $0.value.count < $1.value.count }!
        let bucket = mostFrequent.value

        // Calculate average color in that bucket
        return Color(
            red: Double(bucket.r) / Double(bucket.count) / 255.0,
            green: Double(bucket.g) / Double(bucket.count) / 255.0,
            blue: Double(bucket.b) / Double(bucket.count) / 255.0
        )
    }

    /// Clear the color cache (useful for testing or theme changes)
    func clearCache() {
        colorCache.removeAll()
    }
}
