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
        var tokens: [TextToken] = []

        // Set language for tagger
        tagger.setLanguage(.simplifiedChinese, range: text.startIndex..<text.endIndex)

        // First pass: detect named entities using NLTagger
        var entityRanges: [(Range<String.Index>, TokenType)] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let tokenType: TokenType?
                switch tag {
                case .personalName:
                    tokenType = .personalName
                case .organizationName:
                    tokenType = .organizationName
                case .placeName:
                    tokenType = .placeName
                default:
                    tokenType = nil
                }
                if let type = tokenType {
                    entityRanges.append((range, type))
                    NSLog("   🏷️ Entity: \(text[range]) -> \(type)")
                }
            }
            return true
        }

        NSLog("   📊 Found \(entityRanges.count) named entities")

        // Second pass: use character-level tokenization for Chinese text
        var currentToken = ""
        var isInChineseSequence = false
        var isInASCIISequence = false

        for (index, char) in text.enumerated() {
            let isChinese = char.isChineseCharacter
            let isWhitespace = char.isWhitespace
            let isPunctuation = char.isPunctuation

            // Skip whitespace and punctuation (unless it's part of a URL/number)
            if isWhitespace || (isPunctuation && currentToken.isEmpty) {
                // Flush current token if any
                if !currentToken.isEmpty {
                    tokens.append(createToken(from: currentToken, entityRanges: entityRanges, text: text))
                    currentToken = ""
                }
                isInChineseSequence = false
                isInASCIISequence = false
                continue
            }

            // Handle punctuation between tokens
            if isPunctuation && !currentToken.isEmpty {
                // Flush current token
                tokens.append(createToken(from: currentToken, entityRanges: entityRanges, text: text))
                currentToken = ""
                isInChineseSequence = false
                isInASCIISequence = false
            }

            // Determine character type
            if isChinese {
                if !isInChineseSequence {
                    // Flush previous ASCII token if any
                    if !currentToken.isEmpty {
                        tokens.append(createToken(from: currentToken, entityRanges: entityRanges, text: text))
                        currentToken = ""
                    }
                    isInChineseSequence = true
                    isInASCIISequence = false
                }
                currentToken.append(char)
            } else {
                if !isInASCIISequence {
                    // Flush previous Chinese token if any
                    if !currentToken.isEmpty {
                        tokens.append(createToken(from: currentToken, entityRanges: entityRanges, text: text))
                        currentToken = ""
                    }
                    isInChineseSequence = false
                    isInASCIISequence = true
                }
                currentToken.append(char)
            }
        }

        // Flush remaining token
        if !currentToken.isEmpty {
            tokens.append(createToken(from: currentToken, entityRanges: entityRanges, text: text))
        }

        NSLog("✅ [TextExplosionService] Generated \(tokens.count) tokens")
        return tokens
    }

    // MARK: - Helper Methods

    private func createToken(from tokenText: String, entityRanges: [(Range<String.Index>, TokenType)], text: String) -> TextToken {
        // Find the range of this token in the original text
        let tokenRange = text.range(of: tokenText) ?? text.startIndex..<text.startIndex

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
            if detectURL(in: tokenText) {
                entityType = .url
            } else if detectPhoneNumber(in: tokenText) {
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
        // Address keywords
        let addressKeywords = ["省", "市", "区", "街", "路", "号", "栋", "室", "层"]
        return addressKeywords.contains { text.contains($0) }
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
