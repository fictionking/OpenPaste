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

    /// Total count of items in database
    private var totalItemCount: Int = 0

    /// Number of items to load per batch (pagination)
    private let pageSize: Int = 10

    /// Maximum items to keep in memory (hard limit)
    private let maxItemsInMemory: Int = 100

    /// Current window position (center of the window)
    private var windowCenterIndex: Int? = nil

    /// Whether there are more older items to load (scroll up)
    @Published var hasMoreOldItems: Bool = false

    /// Whether there are more newer items to load (scroll down)
    @Published var hasMoreNewItems: Bool = false

    /// Whether there are more items to load
    @Published var hasMoreItems: Bool = true

    /// Time boundary: oldest capturedAt among currently loaded items
    /// Used for loading even older items (scrolling down)
    private var oldestCapturedAt: Date? = nil

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
            // Get total count WITHOUT loading all items
            totalItemCount = try dataStore.countItems(predicate: nil)
            NSLog("📊 Total items in database: \(totalItemCount)")

            // Load first batch
            let fetchedItems = try dataStore.fetchItems(
                predicate: nil,
                sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                limit: pageSize,
                offset: nil
            )

            allItemSummaries = fetchedItems.map { $0.toSummary() }
            currentLoadedCount = allItemSummaries.count

            // Debug: log the time range of loaded items
            if let first = allItemSummaries.first, let last = allItemSummaries.last {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                NSLog("📅 Loaded items from \(formatter.string(from: last.capturedAt)) to \(formatter.string(from: first.capturedAt))")
            }

            // Initialize time boundary from first batch (oldest time for loading more older items)
            if let last = allItemSummaries.last {
                oldestCapturedAt = last.capturedAt
            }

            // Initialize sliding window state
            windowCenterIndex = currentLoadedCount / 2
            hasMoreItems = currentLoadedCount < totalItemCount
            hasMoreNewItems = false  // Started with newest items, nothing newer
            hasMoreOldItems = currentLoadedCount < totalItemCount  // May have older items

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
    /// Load older items (scroll down) - items with capturedAt older than current oldest
    func loadMoreItems() async {
        guard !isLoading, hasMoreItems, let oldestTime = oldestCapturedAt else { return }

        // Don't load if we're already at the hard limit
        guard allItemSummaries.count < maxItemsInMemory else {
            NSLog("⚠️ Reached memory limit of \(maxItemsInMemory) items")
            return
        }

        isLoading = true

        do {
            // Load items older than the oldest currently loaded item
            let predicate = NSPredicate(format: "capturedAt < %@", oldestTime as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                limit: pageSize,
                offset: nil
            )

            if !fetchedItems.isEmpty {
                // Append older items to the end
                let newSummaries = fetchedItems.map { $0.toSummary() }
                allItemSummaries.append(contentsOf: newSummaries)
                currentLoadedCount = allItemSummaries.count

                // Update oldest time boundary
                if let last = newSummaries.last {
                    oldestCapturedAt = last.capturedAt
                }

                // Enforce hard limit by removing newest items if needed
                enforceMemoryLimit()

                hasMoreItems = fetchedItems.count == pageSize
                NSLog("📜 Loaded \(newSummaries.count) older items, total: \(currentLoadedCount)")
            } else {
                hasMoreItems = false
                NSLog("📭 No more older items available")
            }

            applyFilters()

        } catch {
            showError("Failed to load more items: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Load newer items (scroll up) - items with capturedAt newer than current newest in loaded array
    func loadOldItems() async {
        guard !isLoading, hasMoreOldItems else { return }

        // Don't load if we're already at the hard limit
        guard allItemSummaries.count < maxItemsInMemory else {
            NSLog("⚠️ Reached memory limit of \(maxItemsInMemory) items")
            return
        }

        isLoading = true

        do {
            // Get the newest time from currently loaded array (first item = newest)
            let currentNewestTime = allItemSummaries.first?.capturedAt

            // Load items newer than the newest currently loaded item
            let predicate = NSPredicate(format: "capturedAt > %@", currentNewestTime! as CVarArg)
            let fetchedItems = try dataStore.fetchItems(
                predicate: predicate,
                sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                limit: pageSize,
                offset: nil
            )

            if !fetchedItems.isEmpty {
                // Prepend newer items to the beginning
                let newSummaries = fetchedItems.map { $0.toSummary() }
                allItemSummaries.insert(contentsOf: newSummaries, at: 0)
                currentLoadedCount += newSummaries.count

                // Enforce hard limit by removing oldest items if needed
                enforceMemoryLimit()

                NSLog("📜 Loaded \(newSummaries.count) newer items, total: \(currentLoadedCount)")
            } else {
                hasMoreOldItems = false
                NSLog("📭 No more newer items available")
            }

            hasMoreOldItems = !fetchedItems.isEmpty && fetchedItems.count == pageSize
            applyFilters()

        } catch {
            showError("Failed to load old items: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Enforce the hard memory limit by removing items from the appropriate end
    private func enforceMemoryLimit() {
        let totalCount = allItemSummaries.count
        guard totalCount > maxItemsInMemory else { return }

        let itemsToRemove = totalCount - maxItemsInMemory

        // Remove oldest items (from end of array)
        allItemSummaries.removeLast(itemsToRemove)
        currentLoadedCount = allItemSummaries.count

        // Update oldestCapturedAt since we removed from end
        if let newOldest = allItemSummaries.last {
            oldestCapturedAt = newOldest.capturedAt
        }

        NSLog("🗑️ Removed \(itemsToRemove) oldest items to enforce memory limit (\(maxItemsInMemory))")
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

    private func applyFilters() {
        isLoading = true

        Task {
            // Filter the already-loaded allItemSummaries in memory
            var filtered = allItemSummaries

            // Filter by content type
            if let contentType = selectedContentType {
                filtered = filtered.filter { $0.contentType == contentType }
            }

            // Filter by source app
            if let sourceApp = selectedSourceApp {
                filtered = filtered.filter { $0.sourceApp == sourceApp }
            }

            // Filter by date range
            if let dateRange = selectedDateRange {
                let now = Date()
                let startDate: Date
                switch dateRange {
                case .today:
                    startDate = Calendar.current.startOfDay(for: now)
                case .yesterday:
                    startDate = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: now)) ?? now
                case .pastWeek:
                    startDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
                case .pastMonth:
                    startDate = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
                case .allTime:
                    startDate = Date.distantPast
                }
                filtered = filtered.filter { $0.capturedAt >= startDate }
            }

            // Filter by search query
            if !searchQuery.isEmpty {
                filtered = filtered.filter { item in
                    item.title?.localizedCaseInsensitiveContains(searchQuery) == true ||
                    item.content.localizedCaseInsensitiveContains(searchQuery)
                }
            }

            // Sort by capturedAt (descending) to ensure correct order
            filtered.sort { $0.capturedAt > $1.capturedAt }

            // Display all filtered items (sliding window is managed during loading)
            items = filtered
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
        // Force memory release by creating new empty arrays instead of removeAll
        allItemSummaries = []
        items = []

        // Clear all @Published properties to release their memory
        searchQuery = ""
        searchText = ""
        selectedContentType = nil
        selectedDateRange = nil
        selectedSourceApp = nil
        isLoading = false
        errorMessage = nil
        showingError = false
        availableContentTypes = []
        availableSourceApps = []
        recentItemCount = 0
        categories = []
        currentClipboardItemId = nil
        hasMoreOldItems = false
        hasMoreNewItems = false
        hasMoreItems = true
        windowCenterIndex = nil
        oldestCapturedAt = nil
        currentLoadedCount = 0
        totalItemCount = 0

        // Refresh Core Data context to release cached managed objects
        if let coreDataStore = dataStore as? CoreDataStore {
            coreDataStore.refreshContext()
        }

        // Force autoreleasepool drain to release memory immediately
        autoreleasepool {
            NSLog("🧹 Cleared all item data from memory")
        }
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
