import Foundation
import SwiftUI
import Combine
import CoreData
import CryptoKit

@MainActor
class TextExplosionViewModel: ObservableObject {
    // MARK: - Properties
    private let tokenizer: TextTokenizing
    private let inserter: TextInserting
    private let dataStore: CoreDataStore

    @Published var tokens: [TextToken] = []
    @Published var selectedTokens: Set<UUID> = []
    @Published var isProcessing: Bool = false
    @Published var isProcessingOCR: Bool = false
    @Published var ocrProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var insertionResult: InsertionResult?

    private var ocrService: OCRService?

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
    init(tokenizer: TextTokenizing, inserter: TextInserting, dataStore: CoreDataStore? = nil) {
        self.tokenizer = tokenizer
        self.inserter = inserter
        self.dataStore = dataStore ?? CoreDataStore(modelName: CoreDataStore.defaultModelName)
    }

    // MARK: - Public Methods

    /// Load and tokenize clipboard content (supports both text and images)
    func loadFromClipboard() async {
        isProcessing = true
        errorMessage = nil
        tokens = []
        selectedTokens = []
        insertionResult = nil

        // 检查文本内容（优先）
        if let clipboardText = NSPasteboard.general.string(forType: .string), !clipboardText.isEmpty {
            NSLog("✅ [TextExplosion] Text detected")
            await tokenizeText(clipboardText)
            isProcessing = false
            return
        }

        // 检查图片内容 - 支持多种方式
        var clipboardImage: NSImage?
        var imageData: Data?

        // 方式1: 直接从NSImage初始化（适用于直接截图）
        if let image = NSImage(pasteboard: NSPasteboard.general) {
            clipboardImage = image
            imageData = image.tiffRepresentation
            NSLog("🖼️ [TextExplosion] Image detected via NSImage(pasteboard:)")
        }
        // 方式2: 从TIFF数据创建（适用于file URL）
        else if let tiffData = NSPasteboard.general.data(forType: .tiff) {
            imageData = tiffData
            clipboardImage = NSImage(data: tiffData)
            NSLog("🖼️ [TextExplosion] Image detected via TIFF data")
        }
        // 方式3: 从PNG数据创建
        else if let pngData = NSPasteboard.general.data(forType: .png) {
            imageData = pngData
            clipboardImage = NSImage(data: pngData)
            NSLog("🖼️ [TextExplosion] Image detected via PNG data")
        }

        // 如果找到了图片
        if let image = clipboardImage, let data = imageData {
            // 计算SHA256哈希
            let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            NSLog("🔑 [TextExplosion] Image hash: \(hash.prefix(16))...")

            await processImage(image, hash: hash)
            return
        }

        // 既没有文本也没有图片
        NSLog("❌ [TextExplosion] Clipboard is empty or unsupported content")
        errorMessage = "剪贴板中没有文本或图片"
        isProcessing = false
    }

    /// 处理图片OCR
    func processImage(_ image: NSImage, hash: String) async {
        // 1. 检查数据库中是否已有OCR结果
        let context = dataStore.viewContext
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.fetchLimit = 1

        do {
            let items = try context.fetch(request)
            if let item = items.first,
               let ocrText = item.ocrText, !ocrText.isEmpty {
                NSLog("✅ [TextExplosion] Using cached OCR result from database")
                await tokenizeText(ocrText)
                isProcessing = false
                return
            }
        } catch {
            NSLog("⚠️ [TextExplosion] Database fetch error: \(error.localizedDescription)")
        }

        // 2. 执行OCR
        isProcessingOCR = true
        ocrProgress = 0.0

        // 初始化OCR服务
        if ocrService == nil {
            ocrService = OCRService()
        }

        guard let service = ocrService else {
            errorMessage = "OCR服务初始化失败"
            isProcessingOCR = false
            isProcessing = false
            return
        }

        do {
            let result = try await service.extractText(from: image) { [self] progress in
                self.ocrProgress = progress
            }

            NSLog("✅ [TextExplosion] OCR completed, text length: \(result.text.count)")

            // 3. 保存到数据库
            let saveRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            saveRequest.predicate = NSPredicate(format: "contentHash == %@", hash)
            saveRequest.fetchLimit = 1

            do {
                let items = try context.fetch(saveRequest)
                if let item = items.first {
                    item.ocrText = result.text
                    item.ocrLanguage = result.language
                    item.ocrRecognizedAt = Date()
                    try context.save()
                    NSLog("✅ [TextExplosion] OCR result saved to database")
                } else {
                    NSLog("⚠️ [TextExplosion] No clipboard item found for hash, OCR result not saved")
                }
            } catch {
                NSLog("❌ [TextExplosion] Failed to save OCR result: \(error.localizedDescription)")
            }

            // 4. 分词
            await tokenizeText(result.text)

        } catch {
            NSLog("❌ [TextExplosion] OCR failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isProcessingOCR = false
        ocrProgress = 0.0
        isProcessing = false
    }

    /// 分词文本
    private func tokenizeText(_ text: String) async {
        NSLog("✅ [TextExplosion] Tokenizing text: \(text.prefix(100))...")
        NSLog("📏 [TextExplosion] Text length: \(text.count) characters")

        let tokenized = tokenizer.tokenize(text)
        NSLog("🔢 [TextExplosion] Tokenized count: \(tokenized.count)")

        if tokenized.isEmpty {
            NSLog("⚠️ [TextExplosion] No tokens generated!")
        } else {
            for (index, token) in tokenized.prefix(10).enumerated() {
                NSLog("   [\(index)] \(token.text) -> \(token.entityType)")
            }
        }

        tokens = tokenized
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
