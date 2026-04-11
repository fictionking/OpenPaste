import Foundation
import CoreData

// MARK: - ExpiryService
/// Background service for daily cleanup of expired clipboard items.
/// Uses main queue Timer to ensure thread-safe Core Data operations.
final class ExpiryService {
    // MARK: - Properties

    /// Data store for clipboard item operations
    private let dataStore: ClipboardDataStore

    /// Timer for daily cleanup scheduling
    private var cleanupTimer: Timer?

    /// Interval between cleanup runs (24 hours in seconds)
    private let cleanupInterval: TimeInterval = 24 * 60 * 60

    /// Whether the service is currently active
    private(set) var isActive = false

    /// Logging callback for debugging (optional)
    var logger: ((String) -> Void)?

    // MARK: - Initialization

    /// Initialize the expiry service
    /// - Parameters:
    ///   - dataStore: The data store for clipboard operations
    ///   - logger: Optional logging callback for debugging
    init(dataStore: ClipboardDataStore, logger: ((String) -> Void)? = nil) {
        self.dataStore = dataStore
        self.logger = logger
    }

    deinit {
        stopService()
    }

    // MARK: - Public Methods

    /// Start the daily cleanup service
    func startService() {
        guard !isActive else { return }

        isActive = true

        // Run initial cleanup
        _ = performCleanup()

        // Schedule daily cleanup using main queue Timer
        // Main queue ensures Core Data operations are thread-safe
        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: cleanupInterval,
            repeats: true
        ) { [weak self] _ in
            _ = self?.performCleanup()
        }

        log("ExpiryService started - daily cleanup scheduled")
    }

    /// Stop the cleanup service
    func stopService() {
        guard isActive else { return }

        isActive = false
        cleanupTimer?.invalidate()
        cleanupTimer = nil

        log("ExpiryService stopped")
    }

    /// Perform immediate cleanup of expired items
    /// - Returns: The number of items deleted
    @discardableResult
    func performImmediateCleanup() -> Int {
        return performCleanup()
    }

    // MARK: - Private Methods

    /// Perform the cleanup operation
    /// - Returns: The number of items deleted
    private func performCleanup() -> Int {
        do {
            // Get current date for expiry calculation
            let now = Date()

            // Count expired items before deletion (for logging)
            // Items with a category (pinned) are excluded from expiry
            let expiredItems = try dataStore.fetchItems(
                predicate: NSPredicate(format: "expiresAt < %@ AND category == nil", now as CVarArg),
                sortDescriptors: [] as [NSSortDescriptor]?,
                limit: nil as Int?,
                offset: nil
            )

            let expiredCount = expiredItems.count

            // Delete expired items
            // The dataStore.deleteExpiredItems method implements optimistic locking
            // by checking the isPinned flag before each deletion
            try dataStore.deleteExpiredItems(before: now)

            log("Cleanup completed: \(expiredCount) expired items deleted")

            return expiredCount

        } catch {
            log("Cleanup failed: \(error.localizedDescription)")
            return 0
        }
    }

    /// Log a message if logger is configured
    private func log(_ message: String) {
        logger?(message)
    }
}
