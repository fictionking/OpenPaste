import Foundation
import CoreData
import CryptoKit

// MARK: - ClipboardService
/// Service layer for handling clipboard item business logic.
/// Separates data persistence concerns from UI (ViewModel).
final class ClipboardService {
    // MARK: - Properties

    /// Data store for clipboard operations
    private let dataStore: ClipboardDataStore

    // MARK: - Initialization

    /// Initialize with a data store
    /// - Parameter dataStore: Data store conforming to ClipboardDataStore protocol
    init(dataStore: ClipboardDataStore) {
        self.dataStore = dataStore
    }

    /// Convenience initializer with default Core Data store
    convenience init() {
        let coreDataStore = CoreDataStore(modelName: CoreDataStore.defaultModelName)
        self.init(dataStore: coreDataStore)
    }

    // MARK: - Public Methods

    /// Save or update a clipboard item from monitoring
    /// - Parameters:
    ///   - content: Binary content data
    ///   - contentType: UTI string representing content type
    ///   - sourceApp: Optional source application bundle identifier
    ///   - title: Optional title (e.g., from rich links)
    ///   - allPasteboardData: Complete pasteboard data for restoration
    /// - Returns: The ID of the created or updated item
    func saveNewItem(
        content: Data,
        contentType: String,
        sourceApp: String?,
        title: String? = nil,
        allPasteboardData: PasteboardData? = nil
    ) throws -> UUID {
        // Calculate hash for deduplication based on core content only
        let hash = SHA256.hash(data: content).compactMap { String(format: "%02x", $0) }.joined()
        NSLog("🔢 Hash based on \(contentType) content: \(hash.prefix(16))...")

        let context = dataStore.viewContext
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.sortDescriptors = [NSSortDescriptor(key: "capturedAt", ascending: false)]
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            // Duplicate found — update timestamp only, no new file saved
            existing.capturedAt = Date()
            existing.sourceApp = sourceApp

            // Update title: use provided title (rich link) or set default if existing title is empty
            if let newTitle = title, !newTitle.isEmpty {
                existing.title = newTitle
            } else if existing.title == nil || existing.title!.isEmpty {
                existing.title = defaultTitle(for: contentType)
            }
            existing.expiresAt = Calendar.current.date(byAdding: .day, value: AppSettings.shared.retentionDays, to: Date()) ?? Date()

            // Update complete pasteboard data if provided
            if let pasteboardData = allPasteboardData {
                existing.allPasteboardData = pasteboardData.encode()
                existing.allPasteboardTypes = pasteboardData.encodeTypes()
            }

            try dataStore.saveItem(existing)
            NSLog("♻️ Updated existing item: \(existing.id)")
            return existing.id
        }

        // No duplicate — save image to file only for new items
        var storageContent = content
        if contentType == "public.image",
           let imagePathData = ImageStorageManager.shared.saveImage(content) {
            storageContent = imagePathData
        }

        // Create new item with default title if none provided
        let finalTitle = title ?? defaultTitle(for: contentType)
        NSLog("📝 Creating new item with title: '\(finalTitle)' (from rich link: \(title != nil))")

        let newItem = ClipboardItem(context: context)
        newItem.id = UUID()
        newItem.content = storageContent
        newItem.contentHash = hash
        newItem.contentType = contentType
        newItem.sourceApp = sourceApp
        newItem.title = finalTitle.isEmpty ? nil : finalTitle
        newItem.capturedAt = Date()
        newItem.isPinned = false
        newItem.expiresAt = Calendar.current.date(byAdding: .day, value: AppSettings.shared.retentionDays, to: Date()) ?? Date()

        // Store complete pasteboard data if available
        if let pasteboardData = allPasteboardData {
            newItem.allPasteboardData = pasteboardData.encode()
            newItem.allPasteboardTypes = pasteboardData.encodeTypes()
            NSLog("✅ Stored complete pasteboard data with \(pasteboardData.types.count) types")
        }

        try dataStore.saveItem(newItem)
        NSLog("✅ Saved new item: \(newItem.id) with title: '\(newItem.title ?? "nil")'")
        return newItem.id
    }

    // MARK: - Private Methods

    /// Generate default title based on content type
    private func defaultTitle(for contentType: String) -> String {
        switch contentType {
        case "public.utf8-plain-text", "public.text":
            return L10n.ContentType.text
        case "public.image", "public.tiff", "public.png":
            return L10n.ContentType.image
        case "public.folder":
            return L10n.ContentType.folder
        case "public.file-url":
            return L10n.ContentType.file
        case "public.url", "public.rich-link":
            return L10n.ContentType.link
        case "public.email":
            return L10n.ContentType.email
        case "public.phone-number":
            return L10n.ContentType.phone
        case "public.color-code":
            return L10n.ContentType.color
        case "public.html":
            return "HTML"
        case "public.rtf":
            return L10n.ContentType.richText
        case "com.adobe.pdf":
            return "PDF"
        default:
            return L10n.ContentType.content
        }
    }
}
