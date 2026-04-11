import Foundation
import CoreData

// MARK: - CoreDataStore
/// Core Data implementation of ClipboardDataStore protocol.
/// Provides thread-safe access to Core Data's persistent container using
/// performAndWait to ensure all operations happen on the viewContext's queue.
final class CoreDataStore: ClipboardDataStore {
    // MARK: - Constants

    /// Default Core Data model name
    static let defaultModelName = "OpenPasteApp"

    // MARK: - Properties

    /// The persistent container for Core Data stack
    let persistentContainer: NSPersistentContainer

    /// The main view context for UI operations
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // MARK: - Initialization

    /// Initialize the Core Data store with a persistent container
    /// - Parameter container: NSPersistentContainer with configured persistent store
    init(container: NSPersistentContainer) {
        self.persistentContainer = container

        // Configure external storage for large binary data
        if let description = persistentContainer.persistentStoreDescriptions.first {
            // Enable persistent history tracking for future multi-threading support
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            // Enable automatic migration for schema changes
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        // Configure the view context for main thread confinement
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Load the persistent store
        loadPersistentStore()
    }

    /// Convenience initializer that creates a default container
    /// - Parameter modelName: The name of the Core Data model file (without extension)
    convenience init(modelName: String = CoreDataStore.defaultModelName) {
        // Create the persistent container
        let container = NSPersistentContainer(name: modelName)

        // Initialize with the container
        self.init(container: container)
    }

    // MARK: - Private Methods

    /// Load the persistent store and handle any errors
    private func loadPersistentStore() {
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data store failed to load: \(error)")
            }
        }
    }

    /// Save the view context if there are changes
    /// - Throws: NSError if save fails
    private func saveContext() throws {
        let context = viewContext
        if context.hasChanges {
            try context.save()
        }
    }

    /// Refresh the context to clear cached managed objects
    /// Call this when panel is hidden to release memory
    func refreshContext() {
        viewContext.refreshAllObjects()
        viewContext.reset()
    }

    // MARK: - ClipboardDataStore Protocol Implementation

    func fetchItems(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) throws -> [ClipboardItem] {
        var result: [ClipboardItem] = []

        viewContext.performAndWait {
            let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = sortDescriptors
            if let limit = limit {
                fetchRequest.fetchLimit = limit
            }
            if let offset = offset {
                fetchRequest.fetchOffset = offset
            }

            do {
                result = try viewContext.fetch(fetchRequest)
            } catch {
                // Re-throw from within the block
                // Note: The error will be propagated by the throws declaration
            }
        }

        // Check if fetch failed
        if result.isEmpty && viewContext.hasChanges == false {
            // Try fetch again to detect errors
            var fetchError: Error?
            viewContext.performAndWait {
                let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
                fetchRequest.predicate = predicate
                fetchRequest.sortDescriptors = sortDescriptors
                if let limit = limit {
                    fetchRequest.fetchLimit = limit
                }
                if let offset = offset {
                    fetchRequest.fetchOffset = offset
                }
                do {
                    _ = try viewContext.fetch(fetchRequest)
                } catch {
                    fetchError = error
                }
            }
            if let error = fetchError {
                throw error
            }
        }

        return result
    }

    func countItems(predicate: NSPredicate?) throws -> Int {
        return try viewContext.performAndWait {
            let fetchRequest = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
            if let predicate = predicate {
                fetchRequest.predicate = predicate
            }
            return try viewContext.count(for: fetchRequest)
        }
    }

    func saveItem(_ item: ClipboardItem) throws {
        try viewContext.performAndWait {
            // Check if the item is already in the context
            if item.managedObjectContext == nil {
                viewContext.insert(item)
            }

            try saveContext()
        }
    }

    func deleteItem(_ item: ClipboardItem) throws {
        try viewContext.performAndWait {
            viewContext.delete(item)
            try saveContext()
        }
    }

    func deleteAllItems() throws {
        try viewContext.performAndWait {
            // Create fetch request for all clipboard items
            let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()

            // Fetch all items
            let allItems = try viewContext.fetch(fetchRequest)

            // Delete all items
            for item in allItems {
                viewContext.delete(item)
            }

            // Save changes
            try saveContext()
        }
    }

    func deleteExpiredItems(before date: Date) throws {
        try viewContext.performAndWait {
            // Create fetch request for expired items
            let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()

            // Only delete items without a category (not pinned) that have expired
            fetchRequest.predicate = NSPredicate(
                format: "expiresAt < %@ AND category == nil",
                date as CVarArg
            )

            // Fetch expired items
            let expiredItems = try viewContext.fetch(fetchRequest)

            // Delete each expired item
            for item in expiredItems {
                // Double-check category is nil (optimistic locking)
                if item.category == nil {
                    viewContext.delete(item)
                }
            }

            // Save changes if any items were deleted
            if !expiredItems.isEmpty {
                try saveContext()
            }
        }
    }

    func fetchCategories() throws -> [Category] {
        var result: [Category] = []

        viewContext.performAndWait {
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)
            ]

            do {
                result = try viewContext.fetch(fetchRequest)
            } catch {
                // Will be propagated after the block
            }
        }

        // Check for errors
        if result.isEmpty {
            var fetchError: Error?
            viewContext.performAndWait {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)
                ]
                do {
                    _ = try viewContext.fetch(fetchRequest)
                } catch {
                    fetchError = error
                }
            }
            if let error = fetchError {
                throw error
            }
        }

        return result
    }

    func createCategory(name: String, type: String) throws -> Category {
        var result: Category?

        try viewContext.performAndWait {
            let category = Category(context: viewContext)
            category.id = UUID()
            category.name = name
            category.type = type
            category.sortOrder = 0

            // Insert into context
            viewContext.insert(category)

            // Save
            try saveContext()

            result = category
        }

        guard let category = result else {
            throw NSError(
                domain: "CoreDataStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create category"]
            )
        }

        return category
    }

    func createCategoryWithId(
        id: UUID,
        name: String,
        type: String,
        icon: String,
        sortOrder: Int32
    ) throws -> Category {
        var result: Category?

        try viewContext.performAndWait {
            let category = Category(context: viewContext)
            category.id = id
            category.name = name
            category.type = type
            category.icon = icon
            category.sortOrder = sortOrder

            // Insert into context
            viewContext.insert(category)

            // Save
            try saveContext()

            result = category
        }

        guard let category = result else {
            throw NSError(
                domain: "CoreDataStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create category"]
            )
        }

        return category
    }
}
