import SwiftUI

struct TokenChipView: View {
    let token: TextToken
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text(token.text)
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(token.entityType.color.opacity(isHovered ? 0.3 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(token.entityType.color, lineWidth: token.isSelected ? 2 : 1)
            )
            .foregroundColor(.primary)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                onTap()
            }
    }
}
