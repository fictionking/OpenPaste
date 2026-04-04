#!/usr/bin/env swift

import Foundation
import NaturalLanguage

// Copy the essential models and service for testing

enum TokenType: String, CaseIterable {
    case personalName, organizationName, placeName
    case phoneNumber, url, currency, date, address
    case shipmentTrackingNumber, flightNumber, number, plain
}

struct TextToken {
    let text: String
    let entityType: TokenType
}

// Simplified TextExplosionService for testing
class TextExplosionServiceTester {
    func tokenize(_ text: String) -> [TextToken] {
        guard !text.isEmpty else { return [] }

        print("🔍 Starting tokenization...")
        print("📝 Input text: \(text)")

        // Pre-process: Replace newlines and tabs with spaces
        let processedText = replaceLineBreaksWithSpaces(in: text)

        var tokens: [TextToken] = []

        // Create a new tagger
        let localTagger = NLTagger(tagSchemes: [.nameType])
        localTagger.string = processedText

        // Pre-process: detect URLs
        var urlRanges: [Range<String.Index>] = []
        if let detector = try? NSDataDetector(types: UInt64(NSTextCheckingResult.CheckingType.link.rawValue)) {
            let matches = detector.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    urlRanges.append(range)
                    print("   🔗 URL detected: '\(processedText[range])'")
                }
            }
        }

        // Pre-process: detect phone numbers
        // Supports: +1-415-555-2671, 03-1234-5678, +49-30-12345678, +20-2-1234-5678, etc.
        var phoneRanges: [Range<String.Index>] = []
        let phonePattern = #"(\+?\d{1,3}[-\s]?)?\(?\d{2,4}\)?[-\s]?\d{2,4}[-\s]?\d{2,4}([-.\s]?\d{2,6})?"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    let matchText = String(processedText[range])
                    if matchText.contains("-") || matchText.contains(" ") || matchText.contains("(") {
                        phoneRanges.append(range)
                        print("   📞 Phone detected: '\(matchText)'")
                    }
                }
            }
        }

        // Pre-process: detect currency amounts
        // Supports: $50, €50, ¥50, 50€, 50₽, $50.99, 50元, etc.
        var currencyRanges: [Range<String.Index>] = []
        let currencyPattern = #"[¥$€£¢₽₩₪]\s*\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*(?:元|美元|欧元|英镑|日元|港币|€|₽|£|¥|$|¢)"#
        if let regex = try? NSRegularExpression(pattern: currencyPattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    let matchText = String(processedText[range])
                    // Must have currency symbol at start OR currency word/symbol at end
                    let hasPrefixSymbol = matchText.hasPrefix("¥") || matchText.hasPrefix("$") || matchText.hasPrefix("€") ||
                                         matchText.hasPrefix("£") || matchText.hasPrefix("¢") || matchText.hasPrefix("₽") ||
                                         matchText.hasPrefix("₩") || matchText.hasPrefix("₪")
                    let hasSuffix = matchText.hasSuffix("元") || matchText.hasSuffix("美元") ||
                                   matchText.hasSuffix("欧元") || matchText.hasSuffix("英镑") ||
                                   matchText.hasSuffix("日元") || matchText.hasSuffix("港币") ||
                                   matchText.hasSuffix("€") || matchText.hasSuffix("₽") ||
                                   matchText.hasSuffix("£") || matchText.hasSuffix("¥") ||
                                   matchText.hasSuffix("$") || matchText.hasSuffix("¢")
                    if hasPrefixSymbol || hasSuffix {
                        currencyRanges.append(range)
                        print("   💰 Currency detected: '\(matchText)'")
                    }
                }
            }
        }

        // Pre-process: detect flight numbers (2 letters + 3-4 digits)
        // Pattern: [A-Z]{2} followed by 3-4 digits, not followed by more digits (to avoid tracking numbers)
        var flightRanges: [Range<String.Index>] = []
        let flightPattern = #"([A-Z]{2}\d{3,4})(?!\d)"#  // 2 letters + 3-4 digits, NOT followed by another digit
        if let regex = try? NSRegularExpression(pattern: flightPattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    flightRanges.append(range)
                    print("   ✈️ Flight detected: '\(processedText[range])'")
                }
            }
        }

        // Pre-process: detect tracking numbers
        var trackingRanges: [Range<String.Index>] = []
        let trackingPattern = #"\b[A-Z]{2}\d{8,}\b"#
        if let regex = try? NSRegularExpression(pattern: trackingPattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    let matchText = String(processedText[range])
                    let hasLetter = matchText.range(of: "[A-Z]", options: .regularExpression) != nil
                    let hasNumber = matchText.range(of: "[0-9]", options: .regularExpression) != nil
                    if hasLetter && hasNumber {
                        trackingRanges.append(range)
                        print("   📦 Tracking detected: '\(matchText)'")
                    }
                }
            }
        }

        // Word enumeration
        var wordRanges: [(Range<String.Index>, TokenType)] = []
        print("   🔤 Starting word enumeration...")

        var skipRanges: [Range<String.Index>] = []
        skipRanges.append(contentsOf: urlRanges)
        skipRanges.append(contentsOf: phoneRanges)
        skipRanges.append(contentsOf: currencyRanges)
        skipRanges.append(contentsOf: flightRanges)
        skipRanges.append(contentsOf: trackingRanges)
        print("   🔧 Will skip \(skipRanges.count) special ranges")

        localTagger.enumerateTags(in: processedText.startIndex..<processedText.endIndex, unit: .word, scheme: .nameType) { tag, range in
            // Skip if within special ranges
            for skipRange in skipRanges {
                if skipRange.contains(range) {
                    return true
                }
            }

            let word = String(processedText[range])

            var tokenType: TokenType = .plain
            if let tag = tag {
                switch tag {
                case .personalName: tokenType = .personalName
                case .organizationName: tokenType = .organizationName
                case .placeName: tokenType = .placeName
                default: break
                }
            }

            if tokenType == .plain {
                if detectNumber(in: word) {
                    tokenType = .number
                }
            }

            if !word.isEmpty && !word.allSatisfy({ $0.isWhitespace }) {
                wordRanges.append((range, tokenType))
                print("   📝 Word: '\(word)' -> \(tokenType)")
            }
            return true
        }

        // Post-process: enhance detection for languages that NLTagger doesn't handle well
        wordRanges = enhanceLanguageSpecificDetection(wordRanges, in: processedText)

        // Build final tokens
        var allRanges: [(Range<String.Index>, TokenType)] = []
        allRanges.append(contentsOf: urlRanges.map { ($0, .url) })
        allRanges.append(contentsOf: phoneRanges.map { ($0, .phoneNumber) })
        allRanges.append(contentsOf: currencyRanges.map { ($0, .currency) })
        allRanges.append(contentsOf: flightRanges.map { ($0, .flightNumber) })
        allRanges.append(contentsOf: trackingRanges.map { ($0, .shipmentTrackingNumber) })
        allRanges.append(contentsOf: wordRanges)

        print("   🔀 Total ranges before cleanup: \(allRanges.count)")

        // Remove overlaps
        allRanges = removeOverlaps(allRanges, in: processedText)
        print("   🔀 After removeOverlaps: \(allRanges.count)")

        // Convert to tokens
        for (range, type) in allRanges {
            let tokenText = String(processedText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tokenText.isEmpty && !isPunctuationOnly(tokenText) {
                tokens.append(TextToken(text: tokenText, entityType: type))
            }
        }

        print("✅ Generated \(tokens.count) tokens")
        return tokens
    }

    private func replaceLineBreaksWithSpaces(in text: String) -> String {
        return text.replacingOccurrences(of: "\n", with: " ")
                   .replacingOccurrences(of: "\r", with: " ")
                   .replacingOccurrences(of: "\t", with: " ")
    }

    private func isPunctuationOnly(_ text: String) -> Bool {
        return !text.isEmpty && text.allSatisfy { $0.isPunctuation }
    }

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

    private func removeOverlaps(_ ranges: [(Range<String.Index>, TokenType)], in text: String) -> [(Range<String.Index>, TokenType)] {
        let specialTypes: Set<TokenType> = [.url, .phoneNumber, .currency, .flightNumber, .shipmentTrackingNumber, .personalName, .organizationName, .placeName]

        var specialRanges: [(Range<String.Index>, TokenType)] = []
        var wordRanges: [(Range<String.Index>, TokenType)] = []

        for (range, type) in ranges {
            if specialTypes.contains(type) {
                specialRanges.append((range, type))
            } else {
                wordRanges.append((range, type))
            }
        }

        var result: [(Range<String.Index>, TokenType)] = []

        // Add all special ranges first
        for (range, type) in specialRanges.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
            result.append((range, type))
        }

        // Add word ranges only if they don't overlap
        for (range, type) in wordRanges {
            var overlaps = false
            for (specialRange, _) in specialRanges {
                if range.overlaps(specialRange) {
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

    // Helper: Enhance detection for languages that NLTagger doesn't handle well
    private func enhanceLanguageSpecificDetection(_ ranges: [(Range<String.Index>, TokenType)], in text: String) -> [(Range<String.Index>, TokenType)] {
        var result = ranges
        var indicesToRemove = Set<Int>()

        // Japanese surname patterns (common surnames)
        let japaneseSurnames = Set([
            "佐藤", "鈴木", "高橋", "田中", "伊藤", "渡辺", "山本", "中村", "小林", "加藤",
            "吉田", "山田", "佐々木", "山口", "松本", "井上", "木村", "林", "斎藤", "清水",
            "山本", "谷口", "近藤", "坂本"
        ])

        // Japanese place names (major cities and common place words)
        let japanesePlaces = Set([
            "東京", "京都", "大阪", "名古屋", "札幌", "福岡", "横浜", "神戸", "渋谷", "新宿",
            "池袋", "銀座", "秋葉原", "上野", "品川", "新橋", "六本木", "渋谷区", "東京都",
            "渋谷区", "新宿区", "港区", "世田谷区"
        ])

        // Korean surname patterns (including within longer words like 김철수님)
        let koreanSurnames = ["김", "이", "박", "최", "정", "강", "조", "윤", "장", "임", "한", "오", "서", "신"]

        // Korean place names
        let koreanPlaces = Set([
            "서울", "부산", "대구", "인천", "광주", "대전", "울산", "세종",
            "서울특별시", "부산광역시", "강남구", "마포구", "서초구", "송파구"
        ])

        // Russian name patterns (Cyrillic)
        let russianNamePattern = #"^[А-Яа-яЁё]+$"#

        // Common Arabic given names (not all Arabic words!)
        let arabicGivenNames = Set([
            "محمد", "أحمد", "علي", "فاطمة", "مريم", "عائشة", "خديجة", "فاطمة",
            "يوسف", "إبراهيم", "موسى", "عيسى", "داود", "سليمان", "حسن", "حسين",
            "عمر", "عثمان", "خالد", "سعد", "عبدالله", "عبدالرحمن", "أبو", "ابن"
        ])

        // German/French honorifics
        let honorifics = Set(["Herr", "Frau", "Monsieur", "Madame", "M.", "Mme", "Dr.", "Prof."])

        // German surnames (common patterns)
        let germanSurnames = Set([
            "Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner",
            "Becker", "Schulz", "Hoffmann", "Koch", "Richter", "Klein", "Wolf",
            "Schröder", "Neumann", "Schwarz", "Braun", "Zimmermann", "Krüger"
        ])

        // French surnames
        let frenchSurnames = Set([
            "Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit",
            "Durand", "Leroy", "Moreau", "Simon", "Laurent", "Lefebvre", "Michel",
            "Garcia", "David", "Bertrand", "Roux", "Vincent", "Fournier", "Morel"
        ])

        // First pass: detect individual patterns
        for i in 0..<result.count {
            // Skip if this index was already marked for removal
            guard !indicesToRemove.contains(i) else { continue }

            let (range, type) = result[i]
            let word = String(text[range])

            // Only enhance plain tokens
            guard type == .plain else { continue }

            // Japanese places (exact match first)
            if japanesePlaces.contains(word) {
                result[i] = (range, .placeName)
                print("   🇯🇵 JP Place: \(word)")
                continue
            }

            // Korean places
            if koreanPlaces.contains(word) || word.contains("서울") || word.contains("강남") {
                result[i] = (range, .placeName)
                print("   🇰🇷 KR Place: \(word)")
                continue
            }

            // Japanese places with suffix (東京+都, 渋谷+区 - merge with next token)
            if i + 1 < result.count {
                let (nextRange, nextType) = result[i + 1]
                let nextWord = String(text[nextRange])
                let suffixes = ["都", "道", "府", "県", "市", "区", "町", "村"]
                if suffixes.contains(nextWord) && !indicesToRemove.contains(i + 1) {
                    let combined = word + nextWord
                    result[i] = (range.lowerBound..<nextRange.upperBound, .placeName)
                    indicesToRemove.insert(i + 1)
                    print("   🇯🇵 JP Place: \(combined)")
                    continue
                }
            }

            // Japanese surnames (check if NOT already merged as full name)
            if japaneseSurnames.contains(word) && !indicesToRemove.contains(i) {
                result[i] = (range, .personalName)
                print("   🇯🇵 JP Surname: \(word)")
                continue
            }

            // Korean names: check if word contains a surname (like 김철수님)
            for surname in koreanSurnames {
                if word.hasPrefix(surname) && word.count >= 3 {
                    // Extract the name part (remove honorifics like 님, 씨)
                    let namePart = word.replacingOccurrences(of: "님", with: "").replacingOccurrences(of: "씨", with: "")
                    if namePart.count >= 2 && namePart.count <= 4 {
                        result[i] = (range, .personalName)
                        print("   🇰🇷 KR Name: \(word)")
                        break
                    }
                }
                // Single character surname
                if word == surname && word.count <= 2 {
                    result[i] = (range, .personalName)
                    print("   🇰🇷 KR Surname: \(word)")
                    break
                }
            }

            // Russian names (Cyrillic only, 2-15 chars, starts with uppercase)
            if let regex = try? NSRegularExpression(pattern: russianNamePattern),
               regex.firstMatch(in: word, range: NSRange(location: 0, length: word.utf16.count)) != nil,
               word.count >= 2 && word.count <= 15 {
                if word.first?.isUppercase == true {
                    result[i] = (range, .personalName)
                    print("   🇷🇺 RU Name: \(word)")
                    continue
                }
            }

            // Arabic names (only common given names, not all Arabic words)
            if arabicGivenNames.contains(word) {
                result[i] = (range, .personalName)
                print("   🇸🇦 AR Name: \(word)")
                continue
            }

            // German/French honorifics
            if honorifics.contains(word) && i + 1 < result.count {
                let (nextRange, nextType) = result[i + 1]
                guard !indicesToRemove.contains(i + 1) else { continue }
                let nextWord = String(text[nextRange])
                // Next token should be the name
                if nextType == .plain || nextType == .personalName {
                    let combined = word + " " + nextWord
                    result[i] = (range.lowerBound..<nextRange.upperBound, .personalName)
                    indicesToRemove.insert(i + 1)
                    print("   🇪🇺 Honorific+Name: \(combined)")
                    continue
                }
            }

            // German surnames
            if germanSurnames.contains(word) {
                result[i] = (range, .personalName)
                print("   🇩🇪 DE Surname: \(word)")
                continue
            }

            // French surnames
            if frenchSurnames.contains(word) {
                result[i] = (range, .personalName)
                print("   🇫🇷 FR Surname: \(word)")
                continue
            }
        }

        // Second pass: merge full names
        for i in 0..<result.count {
            guard !indicesToRemove.contains(i) else { continue }
            let (range, type) = result[i]
            let word = String(text[range])

            // Japanese full name: surname + given name (1-2 chars)
            if type == .personalName && japaneseSurnames.contains(word) && i + 1 < result.count {
                let (nextRange, nextType) = result[i + 1]
                guard !indicesToRemove.contains(i + 1) else { continue }
                let nextWord = String(text[nextRange])
                if nextType == .plain && nextWord.count >= 1 && nextWord.count <= 2 {
                    let combinedRange = range.lowerBound..<nextRange.upperBound
                    result[i] = (combinedRange, .personalName)
                    indicesToRemove.insert(i + 1)
                    print("   🇯🇵 JP Full Name: \(word)\(nextWord)")
                }
            }
        }

        // Remove indices marked for deletion
        result = result.enumerated().filter { !indicesToRemove.contains($0.offset) }.map { $0.element }

        return result
    }

    private func detectNumber(in text: String) -> Bool {
        let formatter = NumberFormatter()
        return formatter.number(from: text) != nil || formatter.number(from: text.replacingOccurrences(of: ",", with: "")) != nil
    }
}

// Helper function to repeat strings
func * (string: String, count: Int) -> String {
    return String(repeating: string, count: count)
}

// Run tests
print("=" * 60)
print("TextExplosion Service - Standalone Test")
print("=" * 60)

let service = TextExplosionServiceTester()

// Test 1: Chinese text with flights and tracking
print("\n【Test 1】中文文本（航班号 + 运单号）")
print("-" * 40)
let test1 = "会议信息：国航CA1587航班从北京飞往上海，东航MU5123航班从广州到深圳。快递单号：SF1234567890 顺丰速运，YT9876543210 圆通快递。"
let tokens1 = service.tokenize(test1)
print("\n结果:")
for token in tokens1 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 2: English text
print("\n【Test 2】English text")
print("-" * 40)
let test2 = "Flight UA1234 from New York to Chicago. Call +1-415-555-2671 for details. Visit https://example.com"
let tokens2 = service.tokenize(test2)
print("\n结果:")
for token in tokens2 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 3: Mixed content
print("\n【Test 3】Mixed content")
print("-" * 40)
let test3 = "张三购买了 $50 商品，运单号 FX1234567890，航班 CA1587"
let tokens3 = service.tokenize(test3)
print("\n结果:")
for token in tokens3 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 4: Japanese
print("\n【Test 4】Japanese (日本語)")
print("-" * 40)
let test4 = "佐藤太郎は電話番号03-1234-5678で、山田花子に連絡しました。住所は東京都渋谷区です。"
let tokens4 = service.tokenize(test4)
print("\n結果:")
for token in tokens4 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 5: Korean
print("\n【Test 5】Korean (한국어)")
print("-" * 40)
let test5 = "김철수님, 서울특별시 강남구로 배송해주세요. 연락처는 02-1234-5678입니다."
let tokens5 = service.tokenize(test5)
print("\n결과:")
for token in tokens5 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 6: German
print("\n【Test 6】German (Deutsch)")
print("-" * 40)
let test6 = "Herr Müller aus Berlin hat €50 bezahlt. Tel: +49-30-12345678. Website: https://beispiel.de"
let tokens6 = service.tokenize(test6)
print("\nErgebnis:")
for token in tokens6 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 7: French
print("\n【Test 7】French (Français)")
print("-" * 40)
let test7 = "Monsieur Dupont de Paris a payé 50€. Téléphone: +33-1-23-45-67-89. Site: https://exemple.fr"
let tokens7 = service.tokenize(test7)
print("\nRésultat:")
for token in tokens7 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 8: Spanish
print("\n【Test 8】Spanish (Español)")
print("-" * 40)
let test8 = "El señor García de Madrid pagó $50. Teléfono: +34-91-123-45-67. Sitio web: https://ejemplo.es"
let tokens8 = service.tokenize(test8)
print("\nResultado:")
for token in tokens8 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 9: Russian
print("\n【Test 9】Russian (Русский)")
print("-" * 40)
let test9 = "Иван Иванов из Москвы заплатил 5000₽. Тел: +7-495-123-45-67. Сайт: https://primer.ru"
let tokens9 = service.tokenize(test9)
print("\nРезультат:")
for token in tokens9 {
    print("  [\(token.entityType)] \(token.text)")
}

// Test 10: Arabic
print("\n【Test 10】Arabic (العربية)")
print("-" * 40)
let test10 = "محمد أحمد من القاهرة دفع 50 دولار. هاتف: +20-2-1234-5678. موقع: https://mithal.com"
let tokens10 = service.tokenize(test10)
print("\nالنتيجة:")
for token in tokens10 {
    print("  [\(token.entityType)] \(token.text)")
}

print("\n" + "=" * 60)
print("Test complete!")
print("=" * 60)
