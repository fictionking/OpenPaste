import Foundation
import NaturalLanguage

/// Protocol for text tokenization services
protocol TextTokenizing {
    func tokenize(_ text: String) -> [TextToken]
}

/// NLP service that tokenizes text using Apple's Natural Language framework
class TextExplosionService: TextTokenizing {
    private let tagger: NLTagger

    init() {
        // Initialize NLTagger for named entity recognition
        self.tagger = NLTagger(tagSchemes: [.nameType])
    }

    func tokenize(_ text: String) -> [TextToken] {
        guard !text.isEmpty else { return [] }

        NSLog("🔍 [TextExplosionService] Starting tokenization...")

        // Pre-process: Replace newlines and tabs with spaces (affects word boundaries)
        let processedText = replaceLineBreaksWithSpaces(in: text)

        var tokens: [TextToken] = []

        // Create a new tagger for this text to avoid state issues
        let localTagger = NLTagger(tagSchemes: [.nameType])
        localTagger.string = processedText
        localTagger.setLanguage(.simplifiedChinese, range: processedText.startIndex..<processedText.endIndex)

        // Pre-process: detect URLs with strict boundaries
        var urlRanges: [Range<String.Index>] = []
        if let detector = try? NSDataDetector(types: UInt64(NSTextCheckingResult.CheckingType.link.rawValue)) {
            let matches = detector.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                let nsRange = match.range
                let startOffset = nsRange.location
                let endOffset = nsRange.location + nsRange.length

                if startOffset <= processedText.utf16.count && endOffset <= processedText.utf16.count {
                    let start = processedText.index(processedText.startIndex, offsetBy: startOffset)
                    let end = processedText.index(processedText.startIndex, offsetBy: endOffset)

                    // Trim trailing non-URL characters (Chinese, spaces, etc.)
                    var trimmedEnd = end
                    while trimmedEnd > start {
                        let char = processedText[processedText.index(before: trimmedEnd)]
                        if char.isWhitespace || char.isPunctuation || char.isChineseCharacter {
                            trimmedEnd = processedText.index(before: trimmedEnd)
                        } else {
                            break
                        }
                    }

                    if trimmedEnd > start {
                        urlRanges.append(start..<trimmedEnd)
                        NSLog("   🔗 URL detected: \(processedText[start..<trimmedEnd])")
                    }
                }
            }
        }

        // Pre-process: detect phone numbers (before word tokenization)
        var phoneRanges: [Range<String.Index>] = []
        let phonePattern = #"(?:\+?\d{1,3}[\s-]?)?\(?\d{3,4}\)?[\s-]?\d{3,4}[\s-]?\d{3,4}(?!\d)"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    let matchText = String(processedText[range])
                    // Filter out sequences that look like IDs/postal codes (must have proper separators)
                    if matchText.contains("-") || matchText.contains(" ") || matchText.contains("(") {
                        phoneRanges.append(range)
                        NSLog("   📞 Phone detected: \(matchText)")
                    }
                }
            }
        }

        // Pre-process: detect currency amounts
        var currencyRanges: [Range<String.Index>] = []
        let currencyPattern = #"[¥$€£¢₽₩₪]\s*\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*(?:元|美元|欧元|英镑|日元|港币)"#
        if let regex = try? NSRegularExpression(pattern: currencyPattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    let matchText = String(processedText[range])
                    // Must have currency symbol at start or currency word at end
                    if matchText.hasPrefix("¥") || matchText.hasPrefix("$") || matchText.hasPrefix("€") ||
                       matchText.hasPrefix("£") || matchText.hasSuffix("元") || matchText.hasSuffix("美元") ||
                       matchText.hasSuffix("欧元") || matchText.hasSuffix("英镑") || matchText.hasSuffix("日元") ||
                       matchText.hasSuffix("港币") {
                        currencyRanges.append(range)
                        NSLog("   💰 Currency detected: \(matchText)")
                    }
                }
            }
        }

        // Pre-process: detect flight numbers (CA/MU/CZ etc + 3-4 digits)
        var flightRanges: [Range<String.Index>] = []
        let flightPattern = #"\\b(CA|MU|CZ|HU|FM|3U|8L|ZH|HO|JD|9C)\d{3,4}\\b"#
        if let regex = try? NSRegularExpression(pattern: flightPattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    flightRanges.append(range)
                    NSLog("   ✈️ Flight detected: \(processedText[range])")
                }
            }
        }

        // Pre-process: detect tracking numbers (SF, JD, YTO, STO etc. + 10+ digits)
        var trackingRanges: [Range<String.Index>] = []
        let trackingPattern = #"\\b(?:SF|JD|YTO|STO|YD|ZTO|TNT|DHL|UPS|FEDEX|EMS)[A-Z0-9]{6,12}\\b"#
        if let regex = try? NSRegularExpression(pattern: trackingPattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    trackingRanges.append(range)
                    NSLog("   📦 Tracking detected: \(processedText[range])")
                }
            }
        }

        // Main tokenization: use NLTagger word segmentation
        var wordRanges: [(Range<String.Index>, TokenType)] = []
        NSLog("   🔤 Starting word enumeration for text length: \(processedText.count)")

        localTagger.enumerateTags(in: processedText.startIndex..<processedText.endIndex, unit: .word, scheme: .nameType) { tag, range in
            let word = String(processedText[range])
            NSLog("   🔤 Enumerated word: '\(word)' tag: \(tag?.rawValue ?? "nil")")

            // Check named entity tags
            var tokenType: TokenType = .plain
            if let tag = tag {
                switch tag {
                case .personalName:
                    tokenType = .personalName
                case .organizationName:
                    tokenType = .organizationName
                case .placeName:
                    tokenType = .placeName
                default:
                    break
                }
            }

            // Additional pattern matching for plain tokens
            if tokenType == .plain {
                if detectNumber(in: word) {
                    tokenType = .number
                }
            }

            // Add all words (overlaps will be handled later)
            if !word.isEmpty {
                wordRanges.append((range, tokenType))
                NSLog("   📝 Word: \(word) -> \(tokenType)")
            }
            return true
        }

        // Build final tokens: special types first, then words
        var allRanges: [(Range<String.Index>, TokenType)] = []
        allRanges.append(contentsOf: urlRanges.map { ($0, .url) })
        allRanges.append(contentsOf: phoneRanges.map { ($0, .phoneNumber) })
        allRanges.append(contentsOf: currencyRanges.map { ($0, .currency) })
        allRanges.append(contentsOf: flightRanges.map { ($0, .flightNumber) })
        allRanges.append(contentsOf: trackingRanges.map { ($0, .shipmentTrackingNumber) })
        allRanges.append(contentsOf: wordRanges)

        // Remove overlaps and sort by position
        allRanges = removeOverlaps(allRanges, in: processedText)

        // Convert ranges to tokens
        for (range, type) in allRanges {
            let tokenText = String(processedText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip empty tokens and pure punctuation tokens (commas, periods, etc.)
            if !tokenText.isEmpty && !isPunctuationOnly(tokenText) {
                tokens.append(TextToken(text: tokenText, entityType: type))
            }
        }

        NSLog("✅ [TextExplosionService] Generated \(tokens.count) tokens")
        return tokens
    }

    // Helper: Replace line breaks and tabs with spaces (affects word boundaries)
    private func replaceLineBreaksWithSpaces(in text: String) -> String {
        return text.replacingOccurrences(of: "\n", with: " ")
                   .replacingOccurrences(of: "\r", with: " ")
                   .replacingOccurrences(of: "\t", with: " ")
    }

    // Helper: Check if text is only punctuation (commas, periods, etc.)
    private func isPunctuationOnly(_ text: String) -> Bool {
        return text.allSatisfy { $0.isPunctuation }
    }

    // Helper: Convert NSRange to Range<String.Index>
    private func getRange(from nsRange: NSRange, in text: String) -> Range<String.Index>? {
        let startOffset = nsRange.location
        let endOffset = nsRange.location + nsRange.length

        guard startOffset <= text.utf16.count && endOffset <= text.utf16.count else {
            return nil
        }

        let start = text.index(text.startIndex, offsetBy: startOffset)
        let end = text.index(text.startIndex, offsetBy: endOffset)
        return start..<end
    }

    // Helper: Remove overlapping ranges, keeping longer/earlier ones
    private func removeOverlaps(_ ranges: [(Range<String.Index>, TokenType)], in text: String) -> [(Range<String.Index>, TokenType)] {
        let sorted = ranges.sorted(by: { (a, b) -> Bool in
            if a.0.lowerBound != b.0.lowerBound {
                return a.0.lowerBound < b.0.lowerBound
            }
            // At same position, prefer longer range (special detections)
            let aLen = text.distance(from: a.0.lowerBound, to: a.0.upperBound)
            let bLen = text.distance(from: b.0.lowerBound, to: b.0.upperBound)
            return aLen > bLen
        })

        var result: [(Range<String.Index>, TokenType)] = []
        for (range, type) in sorted {
            var overlaps = false
            for (existing, _) in result {
                if range.overlaps(existing) || existing.overlaps(range) {
                    overlaps = true
                    break
                }
            }
            if !overlaps {
                result.append((range, type))
            }
        }

        return result.sorted { $0.0.lowerBound < $1.0.lowerBound }
    }

    // MARK: - Post-processing

    private func postProcessURLs(tokens: [TextToken], urlRanges: [Range<String.Index>], text: String) -> [TextToken] {
        var processedTokens: [TextToken] = []
        var skipIndices = Set<Int>()

        for (index, token) in tokens.enumerated() {
            if skipIndices.contains(index) {
                continue
            }

            // Check if this token is part of a URL
            guard let tokenRange = text.range(of: token.text) else {
                processedTokens.append(token)
                continue
            }

            var isURLPart = false
            var fullURL = token.text

            for urlRange in urlRanges {
                if tokenRange.overlaps(urlRange) {
                    isURLPart = true
                    // Use the full URL text
                    fullURL = String(text[urlRange])

                    // Mark all tokens covered by this URL as skipped
                    for (idx, t) in tokens.enumerated() {
                        if let tRange = text.range(of: t.text), tRange.overlaps(urlRange) {
                            skipIndices.insert(idx)
                        }
                    }
                    processedTokens.append(TextToken(text: fullURL, entityType: .url))
                    break
                }
            }

            if !isURLPart {
                processedTokens.append(token)
            }
        }

        return processedTokens.isEmpty ? tokens : processedTokens
    }

    // MARK: - Helper Methods

    private func createToken(from tokenText: String, entityRanges: [(Range<String.Index>, TokenType)], urlRanges: [Range<String.Index>], text: String) -> TextToken {
        // Find the range of this token in the original text
        let tokenRange = text.range(of: tokenText) ?? text.startIndex..<text.startIndex

        // Check if this token overlaps with any detected URL
        for urlRange in urlRanges {
            if tokenRange.overlaps(urlRange) {
                // This token is part of a URL, skip it (will be handled separately)
                return TextToken(text: tokenText, entityType: .plain)
            }
        }

        // Check if this word overlaps with any detected entity
        var entityType: TokenType = .plain
        for (entityRange, type) in entityRanges {
            if tokenRange.overlaps(entityRange) {
                entityType = type
                break
            }
        }

        // Additional detection for other entity types
        if entityType == .plain {
            if detectPhoneNumber(in: tokenText) {
                entityType = .phoneNumber
            } else if detectCurrency(in: tokenText) {
                entityType = .currency
            } else if detectDate(in: tokenText) {
                entityType = .date
            } else if detectAddress(in: tokenText) {
                entityType = .address
            } else if detectTrackingNumber(in: tokenText) {
                entityType = .shipmentTrackingNumber
            } else if detectFlightNumber(in: tokenText) {
                entityType = .flightNumber
            } else if detectNumber(in: tokenText) {
                entityType = .number
            }
        }

        NSLog("   📝 Token: \(tokenText) -> \(entityType)")
        return TextToken(text: tokenText, entityType: entityType)
    }

    // MARK: - Detection Helpers

    private func detectURL(in text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: UInt64(NSTextCheckingResult.CheckingType.link.rawValue)) else {
            return false
        }
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
        return !matches.isEmpty
    }

    private func detectPhoneNumber(in text: String) -> Bool {
        // Phone number pattern: starts with digit, contains digits and common separators
        let phonePattern = "^\\d+[\\-\\s]?\\d+[\\-\\s]?\\d+"
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            return regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) != nil
        }
        return false
    }

    private func detectCurrency(in text: String) -> Bool {
        // Currency pattern: ¥, $, €, etc. followed by digits
        let currencyPattern = "^[¥$€£¢₽₩₪]\\s*\\d+(\\.\\d+)?"
        if let regex = try? NSRegularExpression(pattern: currencyPattern) {
            return regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) != nil
        }
        return false
    }

    private func detectDate(in text: String) -> Bool {
        // Try parsing as date
        guard let detector = try? NSDataDetector(types: UInt64(NSTextCheckingResult.CheckingType.date.rawValue)) else {
            return false
        }
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
        return !matches.isEmpty
    }

    private func detectAddress(in text: String) -> Bool {
        // Address detection requires multiple address keywords to avoid false positives
        let primaryKeywords = ["省", "市", "区"]
        let secondaryKeywords = ["街", "路", "号", "栋", "室", "层", "巷", "弄"]

        let hasPrimary = primaryKeywords.contains { text.contains($0) }
        let hasSecondary = secondaryKeywords.contains { text.contains($0) }

        // Need both primary and secondary, or at least 2 address keywords
        return hasPrimary && hasSecondary
    }

    private func detectTrackingNumber(in text: String) -> Bool {
        // Tracking number pattern: letters and numbers, typically 10-20 chars
        let trackingPattern = "^[A-Z0-9]{10,20}$"
        if let regex = try? NSRegularExpression(pattern: trackingPattern) {
            let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count))
            if match != nil {
                // Check if it looks like a tracking number (contains letters and numbers)
                let hasLetter = text.range(of: "[A-Z]", options: .regularExpression) != nil
                let hasNumber = text.range(of: "[0-9]", options: .regularExpression) != nil
                return hasLetter && hasNumber
            }
        }
        return false
    }

    private func detectFlightNumber(in text: String) -> Bool {
        // Flight number pattern: airline code (2-3 letters) + flight number (3-4 digits)
        let flightPattern = "^[A-Z]{2,3}\\d{3,4}$"
        if let regex = try? NSRegularExpression(pattern: flightPattern) {
            return regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) != nil
        }
        return false
    }

    private func detectNumber(in text: String) -> Bool {
        // Use NumberFormatter to detect if text is a number
        let formatter = NumberFormatter()
        return formatter.number(from: text) != nil || formatter.number(from: text.replacingOccurrences(of: ",", with: "")) != nil
    }
}

// MARK: - Character Extensions

extension Character {
    /// Check if character is a Chinese/Japanese/Korean character
    var isChineseCharacter: Bool {
        // CJK Unified Ideographs block: U+4E00–U+9FFF
        // CJK Unified Ideographs Extension A: U+3400–U+4DBF
        // CJK Unified Ideographs Extension B: U+20000–U+2A6DF
        // CJK Unified Ideographs Extension C: U+2A700–U+2B73F
        // CJK Unified Ideographs Extension D: U+2B740–U+2B81F
        // CJK Unified Ideographs Extension E: U+2B820–U+2CEAF
        // CJK Unified Ideographs Extension F: U+2CEB0–U+2EBEF
        // CJK Compatibility Ideographs: U+F900–U+FAFF
        let scalars = unicodeScalars
        guard let scalar = scalars.first else { return false }
        let value = scalar.value

        return (0x4E00...0x9FFF).contains(value) ||
               (0x3400...0x4DBF).contains(value) ||
               (0xF900...0xFAFF).contains(value)
    }

    /// Check if character is whitespace
    var isWhitespace: Bool {
        return self == " " || self == "\t" || self == "\n" || self == "\r"
    }

    /// Check if character is punctuation
    var isPunctuation: Bool {
        let punctuation: Set<Character> = [
            "，", "。", "、", "；", "：", "？", "！", "「", "」", "（", "）",
            ",", ".", ";", ":", "?", "!", "(", ")", "[", "]", "{", "}",
            "-", "_", "+", "=", "*", "/", "\\", "|", "@", "#", "$",
            "%", "^", "&", "~", "`", "'", "\"", "<", ">", ",", "."
        ]
        return punctuation.contains(self)
    }
}
