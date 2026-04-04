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
        // Let NLTagger auto-detect language instead of hardcoding Chinese
        // localTagger.setLanguage(.simplifiedChinese, range: processedText.startIndex..<processedText.endIndex)

        // Pre-process: detect URLs
        var urlRanges: [Range<String.Index>] = []
        if let detector = try? NSDataDetector(types: UInt64(NSTextCheckingResult.CheckingType.link.rawValue)) {
            let matches = detector.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    urlRanges.append(range)
                    NSLog("   🔗 URL detected: \(processedText[range])")
                }
            }
        }

        // Pre-process: detect phone numbers (before word tokenization)
        // Supports: +1-415-555-2671, 03-1234-5678, +49-30-12345678, etc.
        var phoneRanges: [Range<String.Index>] = []
        let phonePattern = #"(\+?\d{1,3}[-\s]?)?\(?\d{2,4}\)?[-\s]?\d{2,4}[-\s]?\d{2,4}([-.\s]?\d{2,6})?"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    phoneRanges.append(range)
                    NSLog("   📞 Phone detected: \(processedText[range])")
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
                        NSLog("   💰 Currency detected: \(matchText)")
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
                    NSLog("   ✈️ Flight detected: \(processedText[range])")
                }
            }
        }

        // Pre-process: detect tracking numbers (2 letters + 8+ digits)
        var trackingRanges: [Range<String.Index>] = []
        let trackingPattern = #"\b[A-Z]{2}\d{8,}\b"#
        if let regex = try? NSRegularExpression(pattern: trackingPattern) {
            let matches = regex.matches(in: processedText, range: NSRange(location: 0, length: processedText.utf16.count))
            for match in matches {
                if let range = getRange(from: match.range, in: processedText) {
                    let matchText = String(processedText[range])
                    // Check if it looks like a tracking number (contains letters and numbers)
                    let hasLetter = matchText.range(of: "[A-Z]", options: .regularExpression) != nil
                    let hasNumber = matchText.range(of: "[0-9]", options: .regularExpression) != nil
                    if hasLetter && hasNumber {
                        trackingRanges.append(range)
                        NSLog("   📦 Tracking detected: \(matchText)")
                    }
                }
            }
        }

        // Main tokenization: use NLTagger word segmentation
        var wordRanges: [(Range<String.Index>, TokenType)] = []
        NSLog("   🔤 Starting word enumeration for text length: \(processedText.count)")

        // Collect all special detection ranges for skipping
        var skipRanges: [Range<String.Index>] = []
        skipRanges.append(contentsOf: urlRanges)
        skipRanges.append(contentsOf: phoneRanges)
        skipRanges.append(contentsOf: currencyRanges)
        skipRanges.append(contentsOf: flightRanges)
        skipRanges.append(contentsOf: trackingRanges)
        NSLog("   🔧 Will skip \(skipRanges.count) special ranges during word enumeration")

        localTagger.enumerateTags(in: processedText.startIndex..<processedText.endIndex, unit: .word, scheme: .nameType) { tag, range in
            // Skip if this word is within any special detection range
            for skipRange in skipRanges {
                if skipRange.contains(range) {
                    return true
                }
            }

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

            // Skip whitespace-only tokens
            if word.allSatisfy({ $0.isWhitespace }) {
                return true
            }

            // Add all words (overlaps will be handled later)
            if !word.isEmpty {
                wordRanges.append((range, tokenType))
                NSLog("   📝 Word: \(word) -> \(tokenType)")
            }
            return true
        }

        // Post-process: enhance detection for languages that NLTagger doesn't handle well
        wordRanges = enhanceLanguageSpecificDetection(wordRanges, in: processedText)

        // Build final tokens: special types first, then words
        var allRanges: [(Range<String.Index>, TokenType)] = []
        allRanges.append(contentsOf: urlRanges.map { ($0, .url) })
        allRanges.append(contentsOf: phoneRanges.map { ($0, .phoneNumber) })
        allRanges.append(contentsOf: currencyRanges.map { ($0, .currency) })
        allRanges.append(contentsOf: flightRanges.map { ($0, .flightNumber) })
        allRanges.append(contentsOf: trackingRanges.map { ($0, .shipmentTrackingNumber) })
        allRanges.append(contentsOf: wordRanges)

        NSLog("   🔀 Before removeOverlaps: \(allRanges.count) ranges")
        NSLog("      Special: \(urlRanges.count + phoneRanges.count + currencyRanges.count + flightRanges.count + trackingRanges.count)")
        NSLog("      Words: \(wordRanges.count)")

        // Remove overlaps and sort by position
        allRanges = removeOverlaps(allRanges, in: processedText)

        NSLog("   🔀 After removeOverlaps: \(allRanges.count) ranges")

        // Post-process: detect flight numbers and tracking numbers from word tokens
        allRanges = detectFlightAndTrackingFromTokens(allRanges, in: processedText)

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
        return !text.isEmpty && text.allSatisfy { $0.isPunctuation }
    }

    // Helper: Detect flight numbers and tracking numbers from word tokens
    private func detectFlightAndTrackingFromTokens(_ ranges: [(Range<String.Index>, TokenType)], in text: String) -> [(Range<String.Index>, TokenType)] {
        var result: [(Range<String.Index>, TokenType)] = []
        var index = 0

        while index < ranges.count {
            let (currentRange, currentType) = ranges[index]

            // Check if current token is a candidate for flight/tracking
            if currentType == .plain || currentType == .number {
                let currentText = String(text[currentRange])

                // Flight pattern: 2 letters + 3-4 digits (e.g., CA1587)
                if currentText.count == 2 && currentText.allSatisfy({ $0.isLetter }),
                   index + 1 < ranges.count {
                    let (nextRange, nextType) = ranges[index + 1]
                    let nextText = String(text[nextRange])
                    if nextType == .number || nextType == .plain,
                       nextText.allSatisfy({ $0.isNumber || $0.isWholeNumber }),
                       nextText.count >= 3 && nextText.count <= 4 {
                        // Merge into flight number
                        let combinedRange = currentRange.lowerBound..<nextRange.upperBound
                        result.append((combinedRange, .flightNumber))
                        index += 2
                        continue
                    }
                }

                // Tracking pattern: 2 letters + 8+ digits (e.g., SF1234567890)
                if currentText.count == 2 && currentText.allSatisfy({ $0.isLetter }),
                   index + 1 < ranges.count {
                    let (nextRange, nextType) = ranges[index + 1]
                    let nextText = String(text[nextRange])
                    if nextType == .number || nextType == .plain,
                       nextText.allSatisfy({ $0.isNumber || $0.isWholeNumber }),
                       nextText.count >= 8 {
                        // Check if it looks like a tracking (has letters and numbers in full string)
                        let combined = currentText + nextText
                        let hasLetter = combined.range(of: "[A-Z]", options: .regularExpression) != nil
                        let hasNumber = combined.range(of: "[0-9]", options: .regularExpression) != nil
                        if hasLetter && hasNumber {
                            let combinedRange = currentRange.lowerBound..<nextRange.upperBound
                            result.append((combinedRange, .shipmentTrackingNumber))
                            index += 2
                            continue
                        }
                    }
                }
            }

            // No merge, add as-is
            result.append((currentRange, currentType))
            index += 1
        }

        let mergedCount = ranges.count - result.count
        if mergedCount > 0 {
            NSLog("   🔀 Merged \(mergedCount) tokens into flight/tracking numbers")
        }

        return result
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
                NSLog("   🇯🇵 JP Place: \(word)")
                continue
            }

            // Korean places
            if koreanPlaces.contains(word) || word.contains("서울") || word.contains("강남") {
                result[i] = (range, .placeName)
                NSLog("   🇰🇷 KR Place: \(word)")
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
                    NSLog("   🇯🇵 JP Place: \(combined)")
                    continue
                }
            }

            // Japanese surnames (check if NOT already merged as full name)
            if japaneseSurnames.contains(word) && !indicesToRemove.contains(i) {
                result[i] = (range, .personalName)
                NSLog("   🇯🇵 JP Surname: \(word)")
                continue
            }

            // Korean names: check if word contains a surname (like 김철수님)
            for surname in koreanSurnames {
                if word.hasPrefix(surname) && word.count >= 3 {
                    // Extract the name part (remove honorifics like 님, 씨)
                    let namePart = word.replacingOccurrences(of: "님", with: "").replacingOccurrences(of: "씨", with: "")
                    if namePart.count >= 2 && namePart.count <= 4 {
                        result[i] = (range, .personalName)
                        NSLog("   🇰🇷 KR Name: \(word)")
                        break
                    }
                }
                // Single character surname
                if word == surname && word.count <= 2 {
                    result[i] = (range, .personalName)
                    NSLog("   🇰🇷 KR Surname: \(word)")
                    break
                }
            }

            // Russian names (Cyrillic only, 2-15 chars, starts with uppercase)
            if let regex = try? NSRegularExpression(pattern: russianNamePattern),
               regex.firstMatch(in: word, range: NSRange(location: 0, length: word.utf16.count)) != nil,
               word.count >= 2 && word.count <= 15 {
                if word.first?.isUppercase == true {
                    result[i] = (range, .personalName)
                    NSLog("   🇷🇺 RU Name: \(word)")
                    continue
                }
            }

            // Arabic names (only common given names, not all Arabic words)
            if arabicGivenNames.contains(word) {
                result[i] = (range, .personalName)
                NSLog("   🇸🇦 AR Name: \(word)")
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
                    NSLog("   🇪🇺 Honorific+Name: \(combined)")
                    continue
                }
            }

            // German surnames
            if germanSurnames.contains(word) {
                result[i] = (range, .personalName)
                NSLog("   🇩🇪 DE Surname: \(word)")
                continue
            }

            // French surnames
            if frenchSurnames.contains(word) {
                result[i] = (range, .personalName)
                NSLog("   🇫🇷 FR Surname: \(word)")
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
                    NSLog("   🇯🇵 JP Full Name: \(word)\(nextWord)")
                }
            }
        }

        // Remove indices marked for deletion
        result = result.enumerated().filter { !indicesToRemove.contains($0.offset) }.map { $0.element }

        return result
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

    // Helper: Remove overlapping ranges, prioritizing special detections
    private func removeOverlaps(_ ranges: [(Range<String.Index>, TokenType)], in text: String) -> [(Range<String.Index>, TokenType)] {
        // Separate special detections from plain words
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

        NSLog("   🔀 Special ranges: \(specialRanges.count)")
        for (i, (range, type)) in specialRanges.enumerated() {
            NSLog("      [\(i)] \(type): '\(text[range])'")
        }

        var result: [(Range<String.Index>, TokenType)] = []

        // Add all special ranges first
        for (range, type) in specialRanges.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
            result.append((range, type))
        }

        // Add word ranges only if they don't overlap with any special range
        var filteredCount = 0
        for (range, type) in wordRanges {
            var overlaps = false
            for (specialRange, specialType) in specialRanges {
                if range.overlaps(specialRange) {
                    overlaps = true
                    filteredCount += 1
                    // Debug: log filtered words
                    // NSLog("      Filtering '\(text[range])' - overlaps with \(specialType)")
                    break
                }
            }
            if !overlaps {
                result.append((range, type))
            }
        }

        NSLog("   🔀 Filtered \(filteredCount) word ranges that overlapped with specials")

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
        // Chinese address keywords
        let chineseKeywords = ["省", "市", "区", "街", "路", "号", "栋", "室", "层", "巷", "弄"]
        // Western address keywords
        let westernKeywords = ["Street", "Road", "Avenue", "Boulevard", "Lane", "Drive", "Court", "Plaza", "Square", "Building", "Floor", "Suite", "Room", "Apartment", "St", "Rd", "Ave", "Blvd", "Dr", "Ct", "Pl", "Sq", "Bldg", "Fl", "Ste", "Rm", "Apt"]

        // Check for multiple address indicators
        let chineseCount = chineseKeywords.filter { text.contains($0) }.count
        let westernCount = westernKeywords.filter { text.contains($0) }.count

        // Need at least 2 address indicators (either Chinese or Western)
        return (chineseCount >= 2) || (westernCount >= 2)
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
