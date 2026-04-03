import Foundation
import SwiftUI
import Combine

@MainActor
class TextExplosionViewModel: ObservableObject {
    // MARK: - Properties
    private let tokenizer: TextTokenizing
    private let inserter: TextInserting

    @Published var tokens: [TextToken] = []
    @Published var selectedTokens: Set<UUID> = []
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var insertionResult: InsertionResult?

    // Filtering
    @Published var filterType: TokenType?

    var filteredTokens: [TextToken] {
        guard let filter = filterType else {
            return tokens
        }
        return tokens.filter { $0.entityType == filter }
    }

    var selectedCount: Int {
        selectedTokens.count
    }

    // MARK: - Initialization
    init(tokenizer: TextTokenizing, inserter: TextInserting) {
        self.tokenizer = tokenizer
        self.inserter = inserter
    }

    // MARK: - Public Methods

    /// Load and tokenize clipboard content
    func loadFromClipboard() async {
        isProcessing = true
        errorMessage = nil
        tokens = []
        selectedTokens = []
        insertionResult = nil

        await MainActor.run {
            guard let clipboardText = NSPasteboard.general.string(forType: .string),
                  !clipboardText.isEmpty else {
                NSLog("❌ [TextExplosion] Clipboard is empty")
                errorMessage = "剪贴板中没有文本内容"
                isProcessing = false
                return
            }

            NSLog("✅ [TextExplosion] Clipboard text: \(clipboardText.prefix(100))...")
            NSLog("📏 [TextExplosion] Text length: \(clipboardText.count) characters")

            let tokenized = tokenizer.tokenize(clipboardText)
            NSLog("🔢 [TextExplosion] Tokenized count: \(tokenized.count)")

            if tokenized.isEmpty {
                NSLog("⚠️ [TextExplosion] No tokens generated!")
            } else {
                for (index, token) in tokenized.prefix(10).enumerated() {
                    NSLog("   [\(index)] \(token.text) -> \(token.entityType)")
                }
            }

            tokens = tokenized
            isProcessing = false
        }
    }

    /// Toggle selection state for a token
    func toggleSelection(_ tokenId: UUID) {
        if selectedTokens.contains(tokenId) {
            selectedTokens.remove(tokenId)
        } else {
            selectedTokens.insert(tokenId)
        }

        if let index = tokens.firstIndex(where: { $0.id == tokenId }) {
            tokens[index].isSelected = selectedTokens.contains(tokenId)
        }
    }

    /// Insert a single token directly
    func insertToken(_ token: TextToken) async {
        NSLog("📋 [TextExplosion] insertToken called for: \(token.text)")
        await insert(token.text)
    }

    /// Select all tokens of a specific type
    func selectByType(_ type: TokenType) {
        for token in tokens where token.entityType == type {
            selectedTokens.insert(token.id)
            if let index = tokens.firstIndex(where: { $0.id == token.id }) {
                tokens[index].isSelected = true
            }
        }
    }

    /// Clear all selections
    func clearSelection() {
        for index in tokens.indices {
            tokens[index].isSelected = false
        }
        selectedTokens.removeAll()
    }

    /// Insert selected tokens (joined by spaces)
    func insertSelected() async {
        NSLog("📋 [TextExplosion] insertSelected called, selectedCount: \(selectedTokens.count)")
        guard !selectedTokens.isEmpty else {
            NSLog("⚠️ [TextExplosion] No tokens selected, skipping insertion")
            return
        }

        let selectedTokenTexts = tokens
            .filter { selectedTokens.contains($0.id) }
            .map { $0.text }
            .joined(separator: " ")

        NSLog("✅ [TextExplosion] Inserting text: \(selectedTokenTexts)")
        await insert(selectedTokenTexts)
    }

    /// Insert all tokens (full original text)
    func insertAll() async {
        NSLog("📋 [TextExplosion] insertAll called")
        let fullText = tokens.map { $0.text }.joined(separator: "")
        NSLog("✅ [TextExplosion] Inserting full text: \(fullText)")
        await insert(fullText)
    }

    // MARK: - Private Methods

    private func insert(_ text: String) async {
        NSLog("🔄 [TextExplosion] Starting insertion for: \(text)")
        errorMessage = nil

        let result = await inserter.insertText(text)
        insertionResult = result

        NSLog("📤 [TextExplosion] Insertion result: \(result)")
    }
}
