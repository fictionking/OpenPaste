import SwiftUI

// MARK: - ClipboardListView
/// Scrollable list view for displaying clipboard history with lazy loading.
/// Uses LazyVStack instead of List for better performance with large datasets.
struct ClipboardListView: View {
    // MARK: - Properties

    /// Clipboard items to display
    @State private var items: [ClipboardItemSummary] = []

    /// Total number of items in the data store
    @State private var totalCount = 0

    /// Number of items currently loaded
    @State private var loadedCount = 0

    /// Whether more items are being loaded
    @State private var isLoading = false

    /// Fetch batch size (number of items to load per batch)
    private let batchSize = 50

    /// Initial load size
    private let initialLoadSize = 50

    /// Threshold for triggering next batch (distance from bottom)
    private let loadThreshold = 200.0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Total count display
            if totalCount > 0 {
                HStack {
                    Text(countDisplayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Showing \(displayRange) of \(totalCount) clipboard items")

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .accessibilityLabel("Loading more items")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
            }

            Divider()

            // Scrollable list with LazyVStack
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items, id: \.id) { item in
                        ClipboardItemView(item: item)
                            .onAppear {
                                // Trigger next batch when nearing the end
                                if shouldTriggerNextBatch(for: item) {
                                    loadNextBatch()
                                }
                            }
                    }

                    // Loading indicator at bottom
                    if isLoading && !items.isEmpty {
                        ProgressView()
                            .padding()
                            .accessibilityLabel("Loading more items")
                    }
                }
            }
        }
        .onAppear {
            loadInitialItems()
        }
    }

    // MARK: - Computed Properties

    /// Human-readable text showing current range and total count
    private var countDisplayText: String {
        if items.isEmpty {
            return "No items"
        }
        return "Showing \(displayRange) of \(totalCount) items"
    }

    /// Current display range (e.g., "1-50" or "1-12" for partial last page)
    private var displayRange: String {
        guard !items.isEmpty else {
            return "0-0"
        }

        let start = 1
        let end = min(loadedCount, totalCount)
        return "\(start)-\(end)"
    }

    // MARK: - Logic

    /// Check if the next batch should be triggered for this item
    /// - Parameter item: The item that just appeared
    /// - Returns: True if near the end of loaded items
    private func shouldTriggerNextBatch(for item: ClipboardItemSummary) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return false
        }

        // Trigger when within loadThreshold items of the end
        let remainingItems = items.count - index
        return remainingItems <= Int(loadThreshold / 20) // Approximate item height threshold
    }

    /// Load initial batch of clipboard items
    private func loadInitialItems() {
        guard !isLoading else { return }

        isLoading = true

        // Simulate async data fetch
        // In production, this would call ClipboardRepository
        DispatchQueue.global(qos: .userInitiated).async {
            // Mock data for now
            let mockItems = self.generateMockItems(count: self.initialLoadSize)

            DispatchQueue.main.async {
                self.items = mockItems
                self.loadedCount = mockItems.count
                self.totalCount = 100 // Mock total
                self.isLoading = false
            }
        }
    }

    /// Load next batch of items (fetch-ahead pattern)
    private func loadNextBatch() {
        guard !isLoading, loadedCount < totalCount else {
            return
        }

        isLoading = true

        // Simulate async data fetch
        DispatchQueue.global(qos: .userInitiated).async {
            let nextBatch = self.generateMockItems(
                count: self.batchSize,
                offset: self.loadedCount
            )

            DispatchQueue.main.async {
                self.items.append(contentsOf: nextBatch)
                self.loadedCount = self.items.count
                self.isLoading = false
            }
        }
    }

    /// Generate mock clipboard items for testing
    /// - Parameters:
    ///   - count: Number of items to generate
    ///   - offset: Starting index for item IDs
    /// - Returns: Array of mock ClipboardItemData
    private func generateMockItems(count: Int, offset: Int = 0) -> [ClipboardItemSummary] {
        (0..<count).map { index in
            ClipboardItemSummary(
                id: UUID(),
                content: "Clipboard item \(offset + index + 1)",
                contentType: "public.utf8-plain-text",
                sourceApp: "TestApp",
                capturedAt: Date(),
                isPinned: offset + index < 3, // Pin first 3 items
                categoryId: nil,
                title: nil
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ClipboardListView()
}
