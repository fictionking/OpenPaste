import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - CategoryManagementView
/// Category management UI with auto-categorization and manual folder creation.
/// Supports drag-and-drop to organize clipboard items into categories.
struct CategoryManagementView: View {
    // MARK: - Properties

    /// View model for clipboard operations
    @ObservedObject var viewModel: ClipboardViewModel

    /// Handler for copying content to clipboard
    var copyHandler: (UUID) -> Void = { _ in }

    /// Available categories
    @State private var categories: [CategoryData] = []

    /// Currently selected category
    @State private var selectedCategory: CategoryData?

    /// Showing new category sheet
    @State private var showingNewCategorySheet = false

    /// New category name input
    @State private var newCategoryName = ""

    /// New category type selection
    @State private var newCategoryType: CategoryType = .manual

    /// Clipboard items filtered by selected category
    @State private var filteredItems: [ClipboardItemData] = []

    /// Error message
    @State private var errorMessage: String?

    // MARK: - Computed Properties

    /// Progressive glass background for sidebar header
    @ViewBuilder
    private var sidebarHeaderBackground: some View {
        Rectangle().fill(.thinMaterial)
    }

    /// Progressive glass background for sidebar
    @ViewBuilder
    private var sidebarBackground: some View {
        Rectangle().fill(.ultraThinMaterial)
    }

    // MARK: - Body

    var body: some View {
        HSplitView {
            // Category sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Categories")
                        .font(.headline)
                        .accessibilityLabel("Categories list")

                    Spacer()

                    Button(action: { showingNewCategorySheet = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create new category")
                }
                .padding()
                .background(sidebarHeaderBackground)

                Divider()

                // Category list
                List(categories, selection: $selectedCategory) { category in
                    CategoryRow(
                        category: category,
                        itemCount: itemCount(for: category)
                    )
                    .tag(category)
                    .contextMenu {
                        Button(category.type == .manual ? "Edit" : "View") {
                            // Edit/view category
                        }

                        if category.type == .manual {
                            Button("Delete", role: .destructive) {
                                deleteCategory(category)
                            }
                        }
                    }
                    .onDrop(
                        of: [.text],
                        delegate: CategoryDropDelegate(
                            category: category,
                          onItemsDropped: { items in
                                moveItemsToCategory(items, category: category)
                            }
                        )
                    )
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, maxWidth: 300)
            .background(sidebarBackground)

            // Items in selected category
            VStack(spacing: 0) {
                if let selected = selectedCategory {
                    // Category header
                    HStack {
                        Text(selected.name)
                            .font(.headline)

                        if selected.type == .auto {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(itemCount(for: selected)) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    Divider()

                    // Items list
                    if filteredItems.isEmpty {
                        emptyStateView(for: selected)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                    ClipboardItemView(
                                        item: item,
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
                                        }
                                    )
                                    .draggable(item.id.uuidString)
                                }
                            }
                        }
                    }
                } else {
                    // No category selected
                    VStack(spacing: 16) {
                        Spacer()

                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Select a category to view items")
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            loadCategories()
        }
        .sheet(isPresented: $showingNewCategorySheet) {
            newCategorySheet
        }
    }

    // MARK: - Sheet Views

    private var newCategorySheet: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)

                Picker("Type", selection: $newCategoryType) {
                    Text("Manual").tag(CategoryType.manual)
                    Text("Auto").tag(CategoryType.auto)
                }
                .pickerStyle(.segmented)

                Text("Manual categories are created by you. Auto categories are automatically created based on the source application.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .formStyle(.grouped)
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingNewCategorySheet = false
                        newCategoryName = ""
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createCategory()
                        showingNewCategorySheet = false
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    // MARK: - Empty State

    @ViewBuilder
    private func emptyStateView(for category: CategoryData) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No items in \(category.name)")
                .foregroundColor(.secondary)

            if category.type == .manual {
                Text("Drag items here to add them to this category")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Helper Methods

    private func loadCategories() {
        do {
            let fetched = try viewModel.fetchCategories()
            categories = fetched.map { cat in
                CategoryData(
                    id: cat.id,
                    name: cat.name,
                    type: cat.type == "auto" ? .auto : .manual,
                    icon: cat.icon ?? "folder",
                    sortOrder: Int(cat.sortOrder)
                )
            }
            // Select first category by default
            if selectedCategory == nil, let first = categories.first {
                selectedCategory = first
                loadItems(for: first)
            }
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
    }

    private func loadItems(for category: CategoryData) {
        do {
            let predicate = NSPredicate(format: "category.id == %@", category.id as CVarArg)
            let fetched = try viewModel.fetchItems(
                predicate: predicate,
                sortDescriptors: [NSSortDescriptor(key: "capturedAt", ascending: false)],
                limit: nil
            )
            filteredItems = fetched.map { $0.toData() }
        } catch {
            filteredItems = []
        }
    }

    private func itemCount(for category: CategoryData) -> Int {
        do {
            let predicate = NSPredicate(format: "category.id == %@", category.id as CVarArg)
            let items = try viewModel.fetchItems(predicate: predicate, sortDescriptors: nil, limit: nil)
            return items.count
        } catch {
            return 0
        }
    }

    private func createCategory() {
        do {
            let cat = try viewModel.createCategory(
                name: newCategoryName,
                type: newCategoryType.rawValue
            )
            let newData = CategoryData(
                id: cat.id,
                name: cat.name,
                type: newCategoryType,
                icon: cat.icon ?? "folder",
                sortOrder: Int(cat.sortOrder)
            )
            categories.append(newData)
            newCategoryName = ""
        } catch {
            errorMessage = "Failed to create category: \(error.localizedDescription)"
        }
    }

    private func deleteCategory(_ category: CategoryData) {
        do {
            let fetched = try viewModel.fetchCategories()
            if let cat = fetched.first(where: { $0.id == category.id }) {
                // Remove category relationship from items first
                if let items = cat.items as? Set<ClipboardItem> {
                    for item in items {
                        item.category = nil
                        try viewModel.saveItem(item)
                    }
                }
            }
            categories.removeAll { $0.id == category.id }
            if selectedCategory?.id == category.id {
                selectedCategory = categories.first
            }
        } catch {
            errorMessage = "Failed to delete category: \(error.localizedDescription)"
        }
    }

    private func moveItemsToCategory(_ items: [String], category: CategoryData) {
        // Move clipboard items to category by updating their category relationship
        for itemIdString in items {
            guard let itemId = UUID(uuidString: itemIdString) else { continue }
            do {
                let predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                let fetched = try viewModel.fetchItems(predicate: predicate, sortDescriptors: nil, limit: 1)
                if let item = fetched.first {
                    let cats = try viewModel.fetchCategories()
                    if let cat = cats.first(where: { $0.id == category.id }) {
                        item.category = cat
                        try viewModel.saveItem(item)
                    }
                }
            } catch {
                // Ignore error
            }
        }
    }
}

// MARK: - CategoryData

/// Data model for category display
struct CategoryData: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let type: CategoryType
    let icon: String
    let sortOrder: Int
}

// MARK: - CategoryType

/// Category type (auto-generated or manually created)
enum CategoryType: String {
    case auto
    case manual
}

// MARK: - CategoryRow

/// Individual category row in the sidebar
struct CategoryRow: View {
    let category: CategoryData
    let itemCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(category.name)

            Spacer()

            Text("\(itemCount)")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel("\(itemCount) items")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CategoryDropDelegate

/// Drop delegate for dragging items into categories
struct CategoryDropDelegate: DropDelegate {
    let category: CategoryData
    let onItemsDropped: ([String]) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }

    func performDrop(info: DropInfo) -> Bool {
        var items: [String] = []

        if let item = info.itemProviders(for: [.text]).first {
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let text = String(data: data, encoding: .utf8) {
                    items.append(text)
                }
            }
        }

        // Simulate async load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onItemsDropped(items)
        }

        return true
    }
}

// MARK: - Preview

#Preview {
    let dataStore = CoreDataStore(modelName: CoreDataStore.defaultModelName)
    let monitor = ClipboardMonitor(onChange: { _, _, _, _, _ in })
    let expiryService = ExpiryService(dataStore: dataStore)
    let viewModel = ClipboardViewModel(
        dataStore: dataStore,
        monitor: monitor,
        expiryService: expiryService
    )
    CategoryManagementView(viewModel: viewModel, copyHandler: { _ in
        // Preview copy handler
    })
}
