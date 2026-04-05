import SwiftUI

/// View for displaying color codes with preview and component values
struct ColorCodeView: View {
    let content: String

    @State private var parsedColor: ParsedColor?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let color = parsedColor {
                // Color bar with overlay text
                Button(action: {
                    copyToClipboard(content)
                }) {
                    GeometryReader { geometry in
                        ZStack {
                            // Checkerboard background for transparency
                            Checkerboard(cornerRadius: 12)
                                .frame(height: 44)

                            // Color preview overlay
                            RoundedRectangle(cornerRadius: 12)
                                .fill(color.swiftColor)
                                .frame(height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )

                            // Color value text with shadow (centered)
                            Text(content.uppercased())
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.9), radius: 1, x: 2, y: 2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
                .help(L10n.Help.clickToCopy)
            } else {
                Text(content)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.black)
            }
        }
        .onAppear {
            parsedColor = ColorParser.parse(content)
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

/// Checkerboard pattern for transparency display
struct Checkerboard: View {
    let cornerRadius: CGFloat
    private let tileSize: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let columns = Int(ceil(geometry.size.width / tileSize))
            let rows = Int(ceil(geometry.size.height / tileSize))

            ZStack {
                ForEach(0..<rows * columns, id: \.self) { index in
                    let row = index / columns
                    let col = index % columns

                    Rectangle()
                        .fill((row + col) % 2 == 0 ? Color.white : Color.gray.opacity(0.3))
                        .frame(
                            width: tileSize,
                            height: tileSize
                        )
                        .position(
                            x: CGFloat(col) * tileSize + tileSize / 2,
                            y: CGFloat(row) * tileSize + tileSize / 2
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

enum ColorFormat {
    case hex, rgb, hsl
}

// MARK: - ParsedColor

struct ParsedColor {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var swiftColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var hasAlpha: Bool {
        alpha < 1.0
    }

    var rgbComponents: [String] {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        if hasAlpha {
            return [String(r), String(g), String(b), String(format: "%.2f", alpha)]
        }
        return [String(r), String(g), String(b)]
    }

    var rgbString: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        if hasAlpha {
            return String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
        }
        return String(format: "rgb(%d, %d, %d)", r, g, b)
    }

    var hslComponents: [String] {
        let (h, s, l) = toHSL()
        if hasAlpha {
            return [String(format: "%.0f°", h), String(format: "%.0f%%", s), String(format: "%.0f%%", l), String(format: "%.2f", alpha)]
        }
        return [String(format: "%.0f°", h), String(format: "%.0f%%", s), String(format: "%.0f%%", l)]
    }

    var hslString: String {
        let (h, s, l) = toHSL()

        if hasAlpha {
            return String(format: "hsla(%.0f, %.0f%%, %.0f%%, %.2f)", h, s, l, alpha)
        }
        return String(format: "hsl(%.0f, %.0f%%, %.0f%%)", h, s, l)
    }

    var cmykComponents: [String] {
        let (c, m, y, k) = toCMYK()
        return [String(format: "%.0f%%", c), String(format: "%.0f%%", m), String(format: "%.0f%%", y), String(format: "%.0f%%", k)]
    }

    var cmykString: String {
        let (c, m, y, k) = toCMYK()
        return String(format: "cmyk(%.0f%%, %.0f%%, %.0f%%, %.0f%%)", c, m, y, k)
    }

    func toHSL() -> (h: Double, s: Double, l: Double) {
        let max = Swift.max(red, green, blue)
        let min = Swift.min(red, green, blue)
        let l = (max + min) / 2.0

        var s: Double = 0
        if l < 0.5 {
            s = (max - min) / (max + min)
        } else {
            s = (max - min) / (2.0 - max - min)
        }

        var h: Double = 0
        if max != min {
            if max == red {
                h = (green - blue) / (max - min)
                if green < blue { h += 6 }
            } else if max == green {
                h = (blue - red) / (max - min) + 2
            } else {
                h = (red - green) / (max - min) + 4
            }
        }
        h *= 60

        return (h, s * 100, l * 100)
    }

    private func toCMYK() -> (c: Double, m: Double, y: Double, k: Double) {
        let r = red
        let g = green
        let b = blue

        let k = 1 - Swift.max(r, g, b)

        if k == 1 {
            return (0, 0, 0, 1)
        }

        let c = (1 - r - k) / (1 - k)
        let m = (1 - g - k) / (1 - k)
        let y = (1 - b - k) / (1 - k)

        return (c * 100, m * 100, y * 100, k * 100)
    }
}

// MARK: - ColorParser

enum ColorParser {
    static func parse(_ string: String) -> ParsedColor? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try hex format
        if let color = parseHex(trimmed) {
            return color
        }

        // Try RGB/RGBA format
        if let color = parseRGB(trimmed) {
            return color
        }

        // Try HSL/HSLA format
        if let color = parseHSL(trimmed) {
            return color
        }

        return nil
    }

    private static func parseHex(_ string: String) -> ParsedColor? {
        guard string.hasPrefix("#") else { return nil }
        let hex = String(string.dropFirst())

        if hex.count == 3 {
            // Expand 3-digit to 6-digit
            let expanded = hex.map { String(repeating: $0, count: 2) }.joined()
            return parseHex6(expanded)
        } else if hex.count == 6 {
            return parseHex6(hex)
        } else if hex.count == 8 {
            return parseHex8(hex)
        }

        return nil
    }

    private static func parseHex6(_ hex: String) -> ParsedColor? {
        let chars = Array(hex)
        guard chars.count == 6 else { return nil }

        guard let r1 = Int(String(chars[0]), radix: 16),
              let g1 = Int(String(chars[1]), radix: 16),
              let b1 = Int(String(chars[2]), radix: 16),
              let r2 = Int(String(chars[3]), radix: 16),
              let g2 = Int(String(chars[4]), radix: 16),
              let b2 = Int(String(chars[5]), radix: 16) else {
            return nil
        }

        let redVal = Double(r1 * 16 + r2) / 255.0
        let greenVal = Double(g1 * 16 + g2) / 255.0
        let blueVal = Double(b1 * 16 + b2) / 255.0
        return ParsedColor(red: redVal, green: greenVal, blue: blueVal, alpha: 1.0)
    }

    private static func parseHex8(_ hex: String) -> ParsedColor? {
        let chars = Array(hex)
        guard chars.count == 8 else { return nil }

        guard let r1 = Int(String(chars[0]), radix: 16),
              let g1 = Int(String(chars[1]), radix: 16),
              let b1 = Int(String(chars[2]), radix: 16),
              let a1 = Int(String(chars[3]), radix: 16),
              let r2 = Int(String(chars[4]), radix: 16),
              let g2 = Int(String(chars[5]), radix: 16),
              let b2 = Int(String(chars[6]), radix: 16),
              let a2 = Int(String(chars[7]), radix: 16) else {
            return nil
        }

        let redVal = Double(r1 * 16 + r2) / 255.0
        let greenVal = Double(g1 * 16 + g2) / 255.0
        let blueVal = Double(b1 * 16 + b2) / 255.0
        let alphaVal = Double(a1 * 16 + a2) / 255.0
        return ParsedColor(red: redVal, green: greenVal, blue: blueVal, alpha: alphaVal)
    }

    private static func parseRGB(_ string: String) -> ParsedColor? {
        let rgbPattern = #"^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$"#
        guard let regex = try? NSRegularExpression(pattern: rgbPattern),
              let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.utf16.count)),
              match.range.length == string.utf16.count else {
            return nil
        }

        // Extract captured groups using NSRange
        let nsString = string as NSString

        guard match.numberOfRanges > 3 else { return nil }

        let rRange = match.range(at: 1)
        let gRange = match.range(at: 2)
        let bRange = match.range(at: 3)

        guard rRange.location != NSNotFound,
              gRange.location != NSNotFound,
              bRange.location != NSNotFound else {
            return nil
        }

        let rStr = nsString.substring(with: rRange)
        let gStr = nsString.substring(with: gRange)
        let bStr = nsString.substring(with: bRange)

        guard let r = Double(rStr),
              let g = Double(gStr),
              let b = Double(bStr) else {
            return nil
        }

        let alpha: Double
        if match.numberOfRanges > 4 {
            let aRange = match.range(at: 4)
            if aRange.location != NSNotFound {
                let aStr = nsString.substring(with: aRange)
                alpha = Double(aStr) ?? 1.0
            } else {
                alpha = 1.0
            }
        } else {
            alpha = 1.0
        }

        return ParsedColor(red: r/255, green: g/255, blue: b/255, alpha: alpha)
    }

    private static func parseHSL(_ string: String) -> ParsedColor? {
        let hslPattern = #"^hsla?\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*(?:,\s*([\d.]+)\s*)?\)$"#
        guard let regex = try? NSRegularExpression(pattern: hslPattern),
              let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.utf16.count)),
              match.range.length == string.utf16.count else {
            return nil
        }

        let nsString = string as NSString

        guard match.numberOfRanges > 3 else { return nil }

        let hRange = match.range(at: 1)
        let sRange = match.range(at: 2)
        let lRange = match.range(at: 3)

        guard hRange.location != NSNotFound,
              sRange.location != NSNotFound,
              lRange.location != NSNotFound else {
            return nil
        }

        let hStr = nsString.substring(with: hRange)
        let sStr = nsString.substring(with: sRange)
        let lStr = nsString.substring(with: lRange)

        guard let h = Double(hStr),
              let s = Double(sStr),
              let l = Double(lStr) else {
            return nil
        }

        let alpha: Double
        if match.numberOfRanges > 4 {
            let aRange = match.range(at: 4)
            if aRange.location != NSNotFound {
                let aStr = nsString.substring(with: aRange)
                alpha = Double(aStr) ?? 1.0
            } else {
                alpha = 1.0
            }
        } else {
            alpha = 1.0
        }

        return ParsedColor(red: 0, green: 0, blue: 0, alpha: alpha).convertFromHSL(h: h/360, s: s/100, l: l/100)
    }
}

extension ParsedColor {
    func convertFromHSL(h: Double, s: Double, l: Double) -> ParsedColor {
        let r: Double, g: Double, b: Double

        if s == 0 {
            r = l
            g = l
            b = l
        } else {
            let q = l < 0.5 ? l * (1 + s) : l + s - l * s
            let p = 2 * l - q

            let hk = h * 6

            func calc(_ t: Double) -> Double {
                if t < 1 { return p + (q - p) * t }
                if t < 3 { return q }
                if t < 4 { return p + (q - p) * (4 - t) }
                return p
            }

            r = calc(hk)
            g = calc(hk + 2)
            b = calc(hk + 4)
        }

        return ParsedColor(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Preview

#Preview("Color Code - Hex") {
    ColorCodeView(content: "#FF5733")
        .frame(width: 300)
        .padding()
}

#Preview("Color Code - RGB") {
    ColorCodeView(content: "rgb(255, 87, 51)")
        .frame(width: 300)
        .padding()
}

#Preview("Color Code - HSL") {
    ColorCodeView(content: "hsl(11, 100%, 60%)")
        .frame(width: 300)
        .padding()
}
