import Foundation
import CoreData

// MARK: - ClipboardDataStore Protocol
/// Persistence abstraction layer for clipboard data storage.
/// This protocol allows for different storage backends (Core Data, in-memory, etc.)
/// and enables testing with mock implementations.
protocol ClipboardDataStore {
    /// Fetch clipboard items with optional filtering and sorting
    /// - Parameters:
    ///   - predicate: Optional NSPredicate for filtering
    ///   - sortDescriptors: Optional sort descriptors for ordering
    ///   - limit: Optional maximum number of items to return
    ///   - offset: Optional offset for pagination (default: 0)
    /// - Returns: Array of ClipboardItem objects
    /// - Throws: NSError if fetch fails
    func fetchItems(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?,
        limit: Int?,
        offset: Int?
    ) throws -> [ClipboardItem]

    /// Save a clipboard item to the data store
    /// - Parameter item: The ClipboardItem to save
    /// - Throws: NSError if save fails
    func saveItem(_ item: ClipboardItem) throws

    /// Delete a clipboard item from the data store
    /// - Parameter item: The ClipboardItem to delete
    /// - Throws: NSError if deletion fails
    func deleteItem(_ item: ClipboardItem) throws

    /// Delete all clipboard items from the data store
    /// - Throws: NSError if deletion fails
    func deleteAllItems() throws

    /// Delete expired clipboard items before a given date
    /// - Parameter date: The cutoff date; items with expiresAt before this date will be deleted
    /// - Throws: NSError if deletion fails
    func deleteExpiredItems(before date: Date) throws

    /// Fetch all categories
    /// - Returns: Array of Category objects
    /// - Throws: NSError if fetch fails
    func fetchCategories() throws -> [Category]

    /// Create a new category
    /// - Parameters:
    ///   - name: The category name
    ///   - type: The category type (e.g., "auto" or "manual")
    /// - Returns: The newly created Category object
    /// - Throws: NSError if creation fails
    func createCategory(name: String, type: String) throws -> Category

    /// Create a new category with a specific ID
    /// - Parameters:
    ///   - id: The UUID to use for the category
    ///   - name: The category name
    ///   - type: The category type
    ///   - icon: The SF Symbol icon name
    ///   - sortOrder: The sort order for display
    /// - Returns: The newly created Category object
    /// - Throws: NSError if creation fails
    func createCategoryWithId(
        id: UUID,
        name: String,
        type: String,
        icon: String,
        sortOrder: Int32
    ) throws -> Category

    /// The managed object context for creating new objects
    var viewContext: NSManagedObjectContext { get }
}
