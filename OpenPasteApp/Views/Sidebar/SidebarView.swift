import SwiftUI

/// Sidebar view with preset categories and settings
/// Displays a vertical list of category buttons with pinned settings at bottom
struct SidebarView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @Binding var selectedCategory: CategorySelector

    var body: some View {
        VStack(spacing: 0) {
            // Preset category buttons (including favorites)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(PresetCategory.allCases, id: \.self) { preset in
                        CategoryButton(
                            title: preset.customDisplayName ?? preset.displayName,
                            icon: preset.icon,
                            iconColor: preset.iconColor,
                            isSelected: selectedCategory == .preset(preset)
                        ) {
                            selectedCategory = .preset(preset)
                        }
                    }
                }
                .padding(.trailing, 10)
                .padding(.vertical, 12)
            }
            
            Spacer()

            // Search button (pinned above settings)
            CategoryButton(
                title: L10n.Common.search,
                icon: "magnifyingglass",
                isSelected: selectedCategory == .search
            ) {
                selectedCategory = .search
            }
            .padding(.trailing, 10)
            .padding(.bottom, 6)

            // Settings button (pinned to bottom)
            CategoryButton(
                title: L10n.Common.settings,
                icon: "gearshape",
                isSelected: selectedCategory.isSettings
            ) {
                selectedCategory = .settings
            }
            .padding(.trailing, 10)
            .padding(.bottom, 12)
                    }
                .background(Color.clear)
    }
}

// MARK: - Preview

#Preview {
    SidebarView(
        viewModel: previewViewModel(),
        selectedCategory: .constant(.preset(.recent))
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
