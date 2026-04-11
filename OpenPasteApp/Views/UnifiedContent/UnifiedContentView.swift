import SwiftUI

/// Scroll direction for bidirectional loading
enum ScrollDirection {
    case none
    case up    // User is scrolling up (loading older items)
    case down  // User is scrolling down (loading newer items)
}

/// Unified content view that displays filtered clipboard items based on selected category
/// Replaces separate tab views with a single list that filters by category selection
struct UnifiedContentView: View {
    @Binding var selectedCategory: CategorySelector
    @ObservedObject var viewModel: ClipboardViewModel
    let copyHandler: (UUID) -> Void

    @State private var selectedIndex: Int? = nil

    /// Track the last visible item index for scroll direction detection
    @State private var lastVisibleIndex: Int? = nil

    /// Track scroll direction
    @State private var scrollDirection: ScrollDirection = .none

    var body: some View {
        Group {
            if selectedCategory.isSettings {
                // Show settings view
                SettingsView(viewModel: viewModel)
            } else if selectedCategory == .search {
                // Show search view
                SearchView(
                    viewModel: viewModel,
                    copyHandler: copyHandler
                )
            } else {
                // Show filtered content list
                contentView
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        if filteredItems.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemView(
                            item: item,
                            isCurrent: item.id == viewModel.currentClipboardItemId,
                            onCategoryChange: { categoryId in
                                Task {
                                    if let categoryId = categoryId {
                                        await viewModel.assignItem(item, toCategory: categoryId)
                                    } else {
                                        await viewModel.removeFromCategory(item)
                                    }
                                }
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteItem(item.id)
                                }
                            },
                            onTitleChange: { newTitle in
                                Task {
                                    await viewModel.updateTitle(for: item, to: newTitle)
                                }
                            },
                            onCopy: {
                                copyHandler(item.id)
                            }
                        )
                        .onAppear {
                            // Don't trigger if already loading (prevent duplicate triggers from re-renders)
                            guard !viewModel.isLoading else { return }

                            // Detect scroll direction
                            if let lastIndex = lastVisibleIndex {
                                if index > lastIndex {
                                    // Scrolling down (newer items)
                                    scrollDirection = .down
                                } else if index < lastIndex {
                                    // Scrolling up (older items)
                                    scrollDirection = .up
                                }
                            }
                            lastVisibleIndex = index

                            // Trigger loading based on scroll direction and position
                            // Only trigger when scroll direction is明确 set (not .none for initial render)
                            if scrollDirection != .none && shouldTriggerLoad(for: index) {
                                Task {
                                    if scrollDirection == .up {
                                        // Near top: load older items
                                        if viewModel.hasMoreOldItems {
                                            await viewModel.loadOldItems()
                                        }
                                    } else if scrollDirection == .down {
                                        // Near bottom: load newer items
                                        if viewModel.hasMoreItems {
                                            await viewModel.loadMoreItems()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Loading indicator at bottom
                    if viewModel.isLoading && !filteredItems.isEmpty {
                        ProgressView()
                            .padding()
                            .accessibilityLabel("Loading more items")
                    }
                }
                .padding()
            }
        }
    }

    /// Check if we should trigger next batch load
    /// Check if we should trigger next batch load based on position and direction
    private func shouldTriggerLoad(for index: Int) -> Bool {
        // Load more when within 5 items of either end
        let itemsFromTop = index
        let itemsFromBottom = filteredItems.count - index

        // Near bottom: load newer items
        if itemsFromBottom <= 5 {
            return true
        }

        // Near top: load older items
        if itemsFromTop <= 5 {
            return true
        }

        return false
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.white)
                .shadow(radius: 2)

            Text(emptyStateTitle)
                .font(.title3)
                .foregroundColor(.white)
                .shadow(radius: 2)

            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.white)
                .shadow(radius: 2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var filteredItems: [ClipboardItemSummary] {
        switch selectedCategory {
        case .preset(let preset):
            // Filter by preset category
            return viewModel.items.filter { preset.matches($0) }

        case .custom(let categoryId):
            // Filter by custom category
            return viewModel.items.filter { $0.categoryId == categoryId }

        case .search:
            // Search handled in SearchView
            return []

        case .settings:
            // Settings handled in body
            return []
        }
    }

    private var emptyStateIcon: String {
        switch selectedCategory {
        case .preset(let preset):
            switch preset {
            case .recent: return "doc.on.clipboard"
            case .text: return "doc.text"
            case .code: return "curlybraces"
            case .image: return "photo"
            case .file: return "doc"
            case .link: return "link"
            case .email: return "envelope"
            case .phoneNumber: return "phone"
            case .colorCode: return "paintpalette"
            case .favorite1, .favorite2, .favorite3, .favorite4: return "pin.fill"
            }
        case .custom:
            return "folder"
        case .search:
            return "magnifyingglass"
        case .settings:
            return "gearshape"
        }
    }

    private var emptyStateTitle: String {
        switch selectedCategory {
        case .preset(let preset):
            return L10n.EmptyState.noItems(in: preset.displayName)
        case .custom:
            return L10n.EmptyState.noItemsInCategory
        case .search:
            return L10n.Common.search
        case .settings:
            return L10n.Common.settings
        }
    }

    private var emptyStateMessage: String {
        switch selectedCategory {
        case .preset(let preset):
            switch preset {
            case .recent:
                return L10n.EmptyState.copyToGetStarted
            default:
                return L10n.EmptyState.noItemsMatchCategory
            }
        case .custom:
            return L10n.EmptyState.dragItemsHint
        case .search:
            return ""
        case .settings:
            return ""
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func categoryMenuContent(for item: ClipboardItemSummary) -> some View {
        if !viewModel.categories.isEmpty {
            Menu(L10n.Category.addTo) {
                ForEach(viewModel.categories) { category in
                    Button(category.name) {
                        Task {
                            await viewModel.assignItem(item, toCategory: category.id)
                        }
                    }
                }
            }

            Divider()

            Button(L10n.Category.removeFrom, role: .destructive) {
                Task {
                    await viewModel.removeFromCategory(item)
                }
            }
        } else {
            Button(L10n.Category.none) {
                // TODO: Navigate to categories
            }
            .disabled(true)
        }
    }
}

// MARK: - Preview

#Preview {
    UnifiedContentView(
        selectedCategory: .constant(.preset(.recent)),
        viewModel: previewViewModel(),
        copyHandler: { _ in }
    )
}

// MARK: - Preview Helpers

@MainActor
private func previewViewModel() -> ClipboardViewModel {
    let dataStore = CoreDataStore(modelName: CoreDataStore.defaultModelName)
    let monitor = ClipboardMonitor(onChange: { _, _, _, _, _ in })
    let expiryService = ExpiryService(dataStore: dataStore)
    return ClipboardViewModel(
        dataStore: dataStore,
        monitor: monitor,
        expiryService: expiryService
    )
}
