import Foundation
import SwiftUI
import Combine
import CoreData
import CryptoKit
import CryptoKit

// MARK: - ClipboardViewModel
/// View model that bridges UI and services with reactive state management.
/// Implements loading states, error handling, and uses ClipboardDataStore protocol.
@MainActor
final class ClipboardViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Clipboard items displayed in the UI (lightweight summaries)
    @Published var items: [ClipboardItemSummary] = []

    /// Current search query text
    @Published var searchQuery: String = "" {
        didSet {
            applyFilters()
        }
    }

    /// Search text for the dedicated search view
    @Published var searchText: String = ""

    /// Selected content type filter
    @Published var selectedContentType: String? = nil {
        didSet {
            applyFilters()
        }
    }

    /// Selected date range filter
    @Published var selectedDateRange: DateRange? = nil {
        didSet {
            applyFilters()
        }
    }

    /// Selected source app filter
    @Published var selectedSourceApp: String? = nil {
        didSet {
            applyFilters()
        }
    }

    /// Loading state for async operations
    @Published var isLoading: Bool = false

    /// Error message for display in alerts
    @Published var errorMessage: String? = nil

    /// Whether error alert is showing
    @Published var showingError: Bool = false

    /// Available content types for filter dropdown
    @Published var availableContentTypes: [String] = []

    /// Available source apps for filter dropdown
    @Published var availableSourceApps: [String] = []

    /// Number of items from last 24 hours (for Dock badge)
    @Published var recentItemCount: Int = 0

    /// Available categories for categorizing items
    @Published var categories: [CategoryData] = []

    /// Current clipboard item ID (for highlighting the active item)
    @Published var currentClipboardItemId: UUID? = nil

    // MARK: - Properties

    /// Data store for clipboard operations
    private let dataStore: ClipboardDataStore

    /// Clipboard monitor for capturing new items
    private let monitor: ClipboardMonitor

    /// Expiry service for cleanup
    private let expiryService: ExpiryService

    /// All item summaries (unfiltered) for filtering - lightweight data structure
    private var allItemSummaries: [ClipboardItemSummary] = []

    /// Number of items currently loaded in memory
    private var currentLoadedCount: Int = 0

    /// Number of items to load per batch (pagination)
    private let pageSize: Int = 50

    /// Whether there are more items to load
    @Published var hasMoreItems: Bool = true

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initialize the view model with required services
    /// - Parameters:
    ///   - dataStore: Data store for clipboard operations
    ///   - monitor: Clipboard monitor for capturing new items
    ///   - expiryService: Expiry service for cleanup
    init(
        dataStore: ClipboardDataStore,
        monitor: ClipboardMonitor,
        expiryService: ExpiryService
    ) {
        self.dataStore = dataStore
        self.monitor = monitor
        self.expiryService = expiryService

        // Setup clipboard monitoring
        setupMonitoring()

        // Load initial data
        Task {
            await ensurePresetCategoriesExist()
            await loadInitialData()
            await loadCategories()
        }
    }

    // MARK: - Public Methods

    /// Set the current clipboard item ID (when user clicks to restore)
    /// - Parameter itemId: The ID of the item that was just copied to clipboard
    func setCurrentClipboardItem(_ itemId: UUID) {
        currentClipboardItemId = itemId
    }

    /// Refresh the clipboard items list (loads first batch only)
    func refresh() async {
        isLoading = true

        do {
            // Load only the first batch
            let fetchedItems = try dataStore.fetchItems(
                predicate: nil,
                sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                limit: pageSize,
                offset: nil
            )

            allItemSummaries = fetchedItems.map { $0.toSummary() }
            currentLoadedCount = allItemSummaries.count
            hasMoreItems = fetchedItems.count == pageSize

            applyFilters()
            updateAvailableFilters()

            // Update recent item count for Dock badge
            updateRecentItemCount()

        } catch {
            showError("Failed to load clipboard items: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Load more items (pagination)
    func loadMoreItems() async {
        guard !isLoading, hasMoreItems else { return }

        isLoading = true

        do {
            let fetchedItems = try dataStore.fetchItems(
                predicate: nil,
                sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                limit: pageSize,
                offset: currentLoadedCount
            )

            // Append new items to existing summaries
            let newSummaries = fetchedItems.map { $0.toSummary() }
            allItemSummaries.append(contentsOf: newSummaries)
            currentLoadedCount = allItemSummaries.count
            hasMoreItems = fetchedItems.count == pageSize

            applyFilters()

        } catch {
            showError("Failed to load more items: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Delete an item from clipboard history
    /// - Parameter itemId: The ID of the item to delete
    func deleteItem(_ itemId: UUID) async {
        isLoading = true

        do {
            // Find the corresponding NSManagedObject
            let predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1,
                offset: nil
            )

            if let nsItem = fetchedItems.first {
                try dataStore.deleteItem(nsItem)

                // Remove from local arrays
                allItemSummaries.removeAll { $0.id == itemId }
                items.removeAll { $0.id == itemId }
                updateRecentItemCount()
            }

        } catch {
            showError("Failed to delete item: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Clear all clipboard data
    func clearAllData() async {
        isLoading = true

        do {
            // Clear cached image files first
            ImageStorageManager.shared.clearAllImages()

            // Then delete Core Data records
            try dataStore.deleteAllItems()

            // Clear local arrays
            allItemSummaries.removeAll()
            items.removeAll()
            updateAvailableFilters()
            updateRecentItemCount()

        } catch {
            showError("Failed to clear all data: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Toggle pin state for an item
    /// - Parameter item: The item to pin/unpin
    func togglePin(for item: ClipboardItemData) async {
        isLoading = true

        do {
            let predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1,
                offset: nil
            )

            if let nsItem = fetchedItems.first {
                nsItem.isPinned = !item.isPinned
                try dataStore.saveItem(nsItem)

                // Update local arrays
                if let index = allItemSummaries.firstIndex(where: { $0.id == item.id }) {
                    allItemSummaries[index] = nsItem.toSummary()
                }
                applyFilters()
            }

        } catch {
            showError("Failed to update item: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Clear error state
    func clearError() {
        errorMessage = nil
        showingError = false
    }

    /// Signal to skip the next clipboard change detection (before writing to pasteboard)
    func skipNextChange() {
        monitor.skipNextChange()
    }

    /// Assign an item to a category
    /// - Parameters:
    ///   - item: The item to categorize
    ///   - categoryId: The category ID to assign
    func assignItem(_ item: ClipboardItemSummary, toCategory categoryId: UUID) async {
        do {
            let predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1,
                offset: nil
            )

            if let nsItem = fetchedItems.first {
                // Find the category entity
                let categories = try dataStore.fetchCategories()
                if let category = categories.first(where: { $0.id == categoryId }) {
                    nsItem.category = category
                    try dataStore.saveItem(nsItem)

                    // Refresh to update local arrays with the new category information
                    await refresh()
                }
            }
        } catch {
            showError("Failed to assign item: \(error.localizedDescription)")
        }
    }

    /// Remove item from its category
    /// - Parameter item: The item to uncategorize
    func removeFromCategory(_ item: ClipboardItemSummary) async {
        do {
            let predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1,
                offset: nil
            )

            if let nsItem = fetchedItems.first {
                nsItem.category = nil
                try dataStore.saveItem(nsItem)

                // Refresh to update local arrays with the new category information
                await refresh()
            }
        } catch {
            showError("Failed to remove from category: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods - Setup

    private func setupMonitoring() {
        monitor.startMonitoring()
        expiryService.startService()
    }

    private func loadInitialData() async {
        // Skip loading on startup - data will be loaded when panel is shown
        // This reduces memory footprint when app is running in background
        isLoading = false
    }

    func loadCategories() async {
        do {
            let fetched = try dataStore.fetchCategories()
            categories = fetched.map { cat in
                CategoryData(
                    id: cat.id,
                    name: cat.name,
                    type: cat.type == "auto" ? .auto : .manual,
                    icon: cat.icon ?? "folder",
                    sortOrder: Int(cat.sortOrder)
                )
            }
        } catch {
            // Silently fail - categories might not exist yet
            categories = []
        }
    }

    /// Ensure preset favorite categories exist in Core Data
    private func ensurePresetCategoriesExist() async {
        let favorites: [(PresetCategory, UUID, String, Color)] = [
            (.favorite1, UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, "收藏1", .red),
            (.favorite2, UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, "收藏2", .orange),
            (.favorite3, UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, "收藏3", .yellow),
            (.favorite4, UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, "收藏4", .green)
        ]

        do {
            let existingCategories = try dataStore.fetchCategories()
            let existingIds = Set(existingCategories.map { $0.id })

            for (preset, uuid, name, _) in favorites where !existingIds.contains(uuid) {
                _ = try dataStore.createCategoryWithId(
                    id: uuid,
                    name: name,
                    type: "preset",
                    icon: "pin.fill",
                    sortOrder: Int32(preset.sortOrder)
                )
            }
        } catch {
            // Silently fail - will retry on next launch
        }
    }

    // MARK: - Private Methods - Data Handling

    func handleNewClipboardItem(content: Data, contentType: String, sourceApp: String?, title: String? = nil, allPasteboardData: PasteboardData? = nil) async {
        // Calculate hash for deduplication based on core content only
        // This ignores metadata that changes on each copy (RTF formatting, timestamps, etc.)
        let hash: String

        // All content types use their core content for hashing
        // - Text: the actual text string
        // - Images: the TIFF/PNG image data
        // - Files: the file path array
        // - URLs: the URL string
        hash = SHA256.hash(data: content).compactMap { String(format: "%02x", $0) }.joined()
        NSLog("🔢 Hash based on \(contentType) content: \(hash.prefix(16))...")

        // Deduplicate: update existing item if same content hash exists
        await MainActor.run {
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

                do {
                    try dataStore.saveItem(existing)
                    // Update current clipboard item ID when existing item is updated
                    currentClipboardItemId = existing.id
                } catch {
                    showError("Failed to update clipboard item: \(error.localizedDescription)")
                }
                return
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

            NSLog("💾 Item title before save: '\(newItem.title ?? "nil")'")
            do {
                try dataStore.saveItem(newItem)
                NSLog("✅ Item saved with title: '\(newItem.title ?? "nil")'")
                // Update current clipboard item ID when new item is created
                currentClipboardItemId = newItem.id
            } catch {
                showError("Failed to save clipboard item: \(error.localizedDescription)")
            }
        }

        await refresh()
    }

    private func applyFilters() {
        isLoading = true

        Task {
            let predicate = SearchPredicateBuilder.buildPredicate(
                searchText: searchQuery,
                contentType: selectedContentType,
                dateRange: selectedDateRange,
                sourceApp: selectedSourceApp
            )

            do {
                let fetchedItems = try dataStore.fetchItems(
                    predicate: predicate,
                    sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                    limit: nil,
                    offset: nil
                )

                items = fetchedItems.map { $0.toSummary() }
            } catch {
                showError("Failed to filter items: \(error.localizedDescription)")
            }

            isLoading = false
        }
    }

    private func updateAvailableFilters() {
        // Extract unique content types
        let contentTypes = Set(allItemSummaries.map { $0.contentType })
        availableContentTypes = contentTypes.sorted()

        // Extract unique source apps
        let apps = Set(allItemSummaries.compactMap { $0.sourceApp })
        availableSourceApps = apps.sorted()
    }

    private func updateRecentItemCount() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        recentItemCount = allItemSummaries.filter { item in
            item.capturedAt > yesterday
        }.count
    }

    // MARK: - Private Methods - Error Handling

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    // MARK: - Private Methods - Title Generation

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

    // MARK: - Public Methods - Title Management

    /// Update the title of a clipboard item
    /// - Parameters:
    ///   - item: The item to update
    ///   - newTitle: The new title to set
    func updateTitle(for item: ClipboardItemSummary, to newTitle: String) async {
        NSLog("📝 Updating title for item \(item.id) to: '\(newTitle)'")
        do {
            let predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1,
                offset: nil
            )

            if let nsItem = fetchedItems.first {
                let finalTitle = newTitle.isEmpty ? nil : newTitle
                NSLog("💾 Setting item title to: '\(finalTitle ?? "nil")'")
                nsItem.title = finalTitle
                try dataStore.saveItem(nsItem)
                NSLog("✅ Title saved successfully")

                // Update local arrays
                if let index = allItemSummaries.firstIndex(where: { $0.id == item.id }) {
                    allItemSummaries[index] = nsItem.toSummary()
                }
                applyFilters()
            }

        } catch {
            NSLog("❌ Failed to update title: \(error.localizedDescription)")
            showError("Failed to update title: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Methods - Category Management

    /// Fetch all categories from the data store
    /// - Returns: Array of category entities
    func fetchCategories() throws -> [Category] {
        return try dataStore.fetchCategories()
    }

    /// Fetch clipboard items with optional filtering
    /// - Parameters:
    ///   - predicate: Optional NSPredicate for filtering
    ///   - sortDescriptors: Optional sort descriptors
    ///   - limit: Optional limit on number of items
    ///   - offset: Optional offset for pagination
    /// - Returns: Array of clipboard item entities
    func fetchItems(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?,
        limit: Int?,
        offset: Int? = nil
    ) throws -> [ClipboardItem] {
        return try dataStore.fetchItems(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: limit,
            offset: offset
        )
    }

    /// Create a new category
    /// - Parameters:
    ///   - name: Category name
    ///   - type: Category type (auto or manual)
    /// - Returns: The created category entity
    func createCategory(name: String, type: String) throws -> Category {
        return try dataStore.createCategory(name: name, type: type)
    }

    /// Save a clipboard item to the data store
    /// - Parameter item: The clipboard item to save
    func saveItem(_ item: ClipboardItem) throws {
        try dataStore.saveItem(item)
    }

    // MARK: - Memory Management

    /// Fetch full item data (including content and pasteboard data) by ID.
    /// Used for lazy-loading heavy fields only when paste is triggered.
    /// - Parameter id: The UUID of the clipboard item
    /// - Returns: Full ClipboardItemData, or nil if not found
    func fetchFullItem(by id: UUID) -> ClipboardItemData? {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            let fetched = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: nil,
                limit: 1,
                offset: nil
            )
            return fetched.first?.toData()
        } catch {
            NSLog("Failed to fetch full item for paste: \(error)")
            return nil
        }
    }

    /// Clear all item data from memory to reduce footprint when panel is hidden.
    /// Called by hideFloatingPanel() in AppDelegate.
    func clearItemMemory() {
        allItemSummaries.removeAll()
        items.removeAll()
    }

    // MARK: - Computed Properties - Search

    /// Filtered items for the search view based on searchText
    /// Searches both title and content fields
    var filteredSearchItems: [ClipboardItemSummary] {
        guard !searchText.isEmpty else {
            return []
        }

        return allItemSummaries.filter { item in
            // Search in title (if exists)
            let titleMatch = item.title != nil &&
                item.title!.localizedCaseInsensitiveContains(searchText)

            // Search in content
            let contentMatch = item.content.localizedCaseInsensitiveContains(searchText)

            return titleMatch || contentMatch
        }
    }
}

// MARK: - ClipboardItem Extension

/// Extension to convert NSManagedObject to ClipboardItemData
extension ClipboardItem {
    func toData() -> ClipboardItemData {
        // Convert content Data to String based on content type
        let contentString: String
        switch contentType {
        case "public.image", "public.tiff", "public.png":
            // For images, content is file path JSON - keep as string
            contentString = String(data: self.content, encoding: .utf8) ?? "[]"
        case "public.file-url":
            // For file URLs, content is already JSON array
            contentString = String(data: self.content, encoding: .utf8) ?? "[]"
        default:
            // For text content, direct conversion
            contentString = String(data: self.content, encoding: .utf8) ?? ""
        }

        return ClipboardItemData(
            id: self.id,
            content: contentString,
            contentType: self.contentType,
            sourceApp: self.sourceApp,
            capturedAt: self.capturedAt,
            isPinned: self.isPinned,
            categoryId: self.category?.id,
            title: self.title,
            allPasteboardData: self.allPasteboardData,
            allPasteboardTypes: self.allPasteboardTypes
        )
    }

    /// Convert to lightweight summary (excludes heavy pasteboard data)
    func toSummary() -> ClipboardItemSummary {
        // Convert content Data to String based on content type
        let contentString: String
        switch contentType {
        case "public.image", "public.tiff", "public.png":
            // For images, content is file path JSON - keep as string
            contentString = String(data: self.content, encoding: .utf8) ?? "[]"
        case "public.file-url":
            // For file URLs, content is already JSON array
            contentString = String(data: self.content, encoding: .utf8) ?? "[]"
        default:
            // For text content, direct conversion
            contentString = String(data: self.content, encoding: .utf8) ?? ""
        }

        return ClipboardItemSummary(
            id: self.id,
            content: contentString,
            contentType: self.contentType,
            sourceApp: self.sourceApp,
            capturedAt: self.capturedAt,
            isPinned: self.isPinned,
            categoryId: self.category?.id,
            title: self.title
        )
    }
}
