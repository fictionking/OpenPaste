import Foundation
import CoreData
import Combine

// MARK: - ClipboardRepository
/// Repository with CRUD operations and complex queries using ClipboardDataStore protocol.
/// Implements memory optimization by clearing content cache when panel is not visible.
final class ClipboardRepository {
    // MARK: - Properties

    /// Data store for clipboard operations (protocol abstraction)
    private let dataStore: ClipboardDataStore

    /// In-memory cache for clipboard item content
    private var contentCache: [UUID: Data] = [:]

    /// Whether the floating panel is currently visible
    private var isPanelVisible = false

    /// Subject for broadcasting item updates
    private let itemsSubject = PassthroughSubject<[ClipboardItem], Never>()

    /// Publisher for item updates
    var itemsPublisher: AnyPublisher<[ClipboardItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    /// Initialize the repository with a data store
    /// - Parameter dataStore: Data store conforming to ClipboardDataStore protocol
    init(dataStore: ClipboardDataStore) {
        self.dataStore = dataStore
    }

    /// Convenience initializer with default Core Data store
    convenience init() {
        let coreDataStore = CoreDataStore(modelName: CoreDataStore.defaultModelName)
        self.init(dataStore: coreDataStore)
    }

    // MARK: - CRUD Operations

    /// Create a new clipboard item
    /// - Parameters:
    ///   - content: Binary content data
    ///   - contentType: UTI string representing content type
    ///   - sourceApp: Optional source application name
    ///   - expiresAt: Optional expiry date (nil = calculate from retention policy)
    /// - Returns: The created ClipboardItem
    /// - Throws: Error if creation fails
    func createItem(
        content: Data,
        contentType: String,
        sourceApp: String?,
        expiresAt: Date? = nil
    ) throws -> ClipboardItem {
        // Create new managed object
        let newItem = ClipboardItem(context: dataStore.viewContext)
        newItem.id = UUID()
        newItem.content = content
        newItem.contentType = contentType
        newItem.sourceApp = sourceApp
        newItem.capturedAt = Date()
        newItem.isPinned = false

        // Calculate expiry date if not provided
        if let expiresAt = expiresAt {
            newItem.expiresAt = expiresAt
        } else {
            // Use retention days from settings
            let retentionDays = AppSettings.shared.retentionDays
            newItem.expiresAt = Calendar.current.date(
                byAdding: .day,
                value: retentionDays,
                to: Date()
            ) ?? Date()
        }

        // Save to data store
        try dataStore.saveItem(newItem)

        // Cache content if panel is visible (id is non-optional, set above)
        if isPanelVisible {
            contentCache[newItem.id] = content
        }

        // Broadcast update
        broadcastItems()

        return newItem
    }

    /// Read/fetch clipboard items with optional filtering
    /// - Parameters:
    ///   - predicate: Optional NSPredicate for filtering
    ///   - sortDescriptors: Optional sort descriptors
    ///   - limit: Optional maximum number of items to return
    /// - Returns: Array of ClipboardItem objects
    /// - Throws: Error if fetch fails
    func readItems(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        limit: Int? = nil
    ) throws -> [ClipboardItem] {
        let items = try dataStore.fetchItems(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: limit,
            offset: nil
        )

        // Load content into cache if panel is visible (id and content are non-optional)
        if isPanelVisible {
            for item in items {
                contentCache[item.id] = item.content
            }
        }

        return items
    }

    /// Update an existing clipboard item
    /// - Parameter item: The item to update (must exist in data store)
    /// - Throws: Error if update fails
    func updateItem(_ item: ClipboardItem) throws {
        // Save changes to data store
        try dataStore.saveItem(item)

        // Update cache if panel is visible (id and content are non-optional)
        if isPanelVisible {
            contentCache[item.id] = item.content
        }

        // Broadcast update
        broadcastItems()
    }

    /// Delete a clipboard item
    /// - Parameter item: The item to delete
    /// - Throws: Error if deletion fails
    func deleteItem(_ item: ClipboardItem) throws {
        // Remove from cache
        contentCache.removeValue(forKey: item.id)

        // Delete from data store
        try dataStore.deleteItem(item)

        // Broadcast update
        broadcastItems()
    }

    // MARK: - Search Query

    /// Search clipboard items with multi-dimensional filter predicate
    /// - Parameters:
    ///   - searchText: Text to search for in content (case-insensitive)
    ///   - contentType: Optional content type filter
    ///   - dateRange: Optional date range filter
    ///   - sourceApp: Optional source app filter
    ///   - limit: Optional maximum number of results
    /// - Returns: Array of matching ClipboardItem objects
    /// - Throws: Error if search fails
    func searchItems(
        searchText: String = "",
        contentType: String? = nil,
        dateRange: DateRange? = nil,
        sourceApp: String? = nil,
        limit: Int? = nil
    ) throws -> [ClipboardItem] {
        let predicate = SearchPredicateBuilder.buildPredicate(
            searchText: searchText,
            contentType: contentType,
            dateRange: dateRange,
            sourceApp: sourceApp
        )

        let sortDescriptors = [
            NSSortDescriptor(key: "capturedAt", ascending: false)
        ]

        return try dataStore.fetchItems(
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: limit,
            offset: nil
        )
    }

    // MARK: - Memory Optimization

    /// Set panel visibility for memory optimization
    /// - Parameter isVisible: Whether the floating panel is visible
    func setPanelVisibility(_ isVisible: Bool) {
        isPanelVisible = isVisible

        if !isVisible {
            // Clear content cache when panel is hidden to free memory
            clearContentCache()
        }
    }

    /// Clear the in-memory content cache
    private func clearContentCache() {
        contentCache.removeAll()
    }

    /// Get cached content for an item (if available)
    /// - Parameter itemId: UUID of the item
    /// - Returns: Cached content data, or nil if not in cache
    func getCachedContent(for itemId: UUID) -> Data? {
        return contentCache[itemId]
    }

    // MARK: - Category Management

    /// Fetch all categories
    /// - Returns: Array of Category objects
    /// - Throws: Error if fetch fails
    func fetchCategories() throws -> [Category] {
        return try dataStore.fetchCategories()
    }

    /// Create a new category
    /// - Parameters:
    ///   - name: Category name
    ///   - type: Category type ("auto" or "manual")
    /// - Returns: The created Category object
    /// - Throws: Error if creation fails
    func createCategory(name: String, type: String) throws -> Category {
        return try dataStore.createCategory(name: name, type: type)
    }

    /// Get or create auto-category for a source app
    /// - Parameter sourceApp: Source application name
    /// - Returns: Category object for the source app
    /// - Throws: Error if fetch or creation fails
    func getOrCreateCategory(forSourceApp sourceApp: String) throws -> Category {
        // Try to find existing auto-category for this source app
        let predicate = NSPredicate(format: "name == %@ AND type == %@", sourceApp, "auto")
        let existing = try dataStore.fetchCategories().filter { category in
            predicate.evaluate(with: category)
        }

        if let found = existing.first {
            return found
        }

        // Create new auto-category
        return try dataStore.createCategory(name: sourceApp, type: "auto")
    }

    // MARK: - Private Methods

    /// Broadcast items update to subscribers
    private func broadcastItems() {
        do {
            let items = try readItems()
            itemsSubject.send(items)
        } catch {
            // Log error but don't crash
            // Error broadcasting items
        }
    }
}

// MARK: - SearchPredicateBuilder (Reused from SearchBarView)

/// Builds NSPredicate for multi-dimensional search filtering
struct SearchPredicateBuilder {
    /// Build a compound predicate from search criteria
    /// - Parameters:
    ///   - searchText: Text to search for in content
    ///   - contentType: Optional content type filter
    ///   - dateRange: Optional date range filter
    ///   - sourceApp: Optional source app filter
    /// - Returns: NSPredicate for Core Data filtering
    static func buildPredicate(
        searchText: String,
        contentType: String?,
        dateRange: DateRange?,
        sourceApp: String?
    ) -> NSPredicate? {
        var predicates: [NSPredicate] = []

        // Content text search (case-insensitive)
        if !searchText.isEmpty {
            let contentPredicate = NSPredicate(
                format: "content CONTAINS[cd] %@",
                searchText
            )
            predicates.append(contentPredicate)
        }

        // Content type filter
        if let contentType = contentType {
            let typePredicate = NSPredicate(
                format: "contentType == %@",
                contentType
            )
            predicates.append(typePredicate)
        }

        // Date range filter
        if let dateRangePredicate = dateRange?.predicate {
            predicates.append(dateRangePredicate)
        }

        // Source app filter
        if let sourceApp = sourceApp {
            let appPredicate = NSPredicate(
                format: "sourceApp == %@",
                sourceApp
            )
            predicates.append(appPredicate)
        }

        // Combine all predicates with AND
        if predicates.isEmpty {
            return nil // No filters
        } else if predicates.count == 1 {
            return predicates.first
        } else {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
}
