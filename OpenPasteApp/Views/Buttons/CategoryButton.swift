import SwiftUI

/// Category button for sidebar navigation
/// Spans two columns: text in left column (200pt), button in right column (50pt)
struct CategoryButton: View {
    let title: String
    let icon: String
    let iconColor: Color?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    init(
        title: String,
        icon: String,
        iconColor: Color? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.clear)
                    .background(buttonBackground)

                iconWithStroke(
                    for: Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                )
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(height: 36)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel(title)
    }

    // MARK: - Icon with Stroke

    @ViewBuilder
    private func iconWithStroke<T: View>(for content: T) -> some View {
        let iconColor = iconColor ?? .white

        if isSelected {
            // Selected: white icon, no stroke
            content.foregroundColor(iconColor)
        } else {
            // Unselected: white icon with black stroke for contrast
            ZStack {
                // Stroke layers (offset in 4 directions)
                content
                    .foregroundColor(.black.opacity(0.5))
                    .offset(x: 0, y: -1)

                content
                    .foregroundColor(.black.opacity(0.5))
                    .offset(x: 0, y: 1)

                content
                    .foregroundColor(.black.opacity(0.5))
                    .offset(x: -1, y: 0)

                content
                    .foregroundColor(.black.opacity(0.5))
                    .offset(x: 1, y: 0)

                // Main icon on top
                content.foregroundColor(iconColor)
            }
            .compositingGroup()
        }
    }

    // MARK: - Progressive Glass Effects

    @ViewBuilder
    private var buttonBackground: some View {
        if #available(macOS 26.0, *) {
            Circle()
                .glassEffect(.clear, in: Circle())
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        CategoryButton(
            title: "最近",
            icon: "clock.arrow.circlepath",
            isSelected: true,
            action: {}
        )

        CategoryButton(
            title: "文本",
            icon: "doc.text",
            isSelected: false,
            action: {}
        )

        CategoryButton(
            title: "收藏1很长的名字测试换行",
            icon: "pin.fill",
            iconColor: .red,
            isSelected: false,
            action: {}
        )
    }
    .padding()
}
