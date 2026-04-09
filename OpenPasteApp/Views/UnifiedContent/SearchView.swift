import SwiftUI

/// Search view with empty state and bottom search bar
/// Displays filtered clipboard items based on search text
struct SearchView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    let copyHandler: (ClipboardItemData) -> Void

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            if viewModel.searchText.isEmpty {
                emptyStateView
            } else if viewModel.filteredSearchItems.isEmpty {
                noResultsView
            } else {
                resultsList
            }

            // Search bar at bottom
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white)
                .shadow(radius: 2)

            Text(L10n.Search.emptyTitle)
                .font(.title3)
                .foregroundColor(.white)
                .shadow(radius: 2)

            Text(L10n.Search.emptyMessage)
                .font(.body)
                .foregroundColor(.white)
                .shadow(radius: 2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results View

    @ViewBuilder
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))

            Text(L10n.Search.noResults)
                .font(.title3)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)

            Text(L10n.Search.tryDifferent)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results List

    @ViewBuilder
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Result count
            Text(L10n.Search.resultsCount.localized(with: viewModel.filteredSearchItems.count))
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 1)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(viewModel.filteredSearchItems.enumerated()), id: \.element.id) { index, item in
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
                                    await viewModel.deleteItem(item)
                                }
                            },
                            onTitleChange: { newTitle in
                                Task {
                                    await viewModel.updateTitle(for: item, to: newTitle)
                                }
                            },
                            onCopy: {
                                copyHandler(item)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(L10n.Search.placeholder, text: $viewModel.searchText)
                .focused($isSearchFieldFocused)
                .textFieldStyle(.plain)
                .onAppear {
                    isSearchFieldFocused = true
                }

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    SearchView(
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
