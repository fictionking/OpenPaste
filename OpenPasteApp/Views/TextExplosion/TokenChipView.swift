import SwiftUI

struct TokenChipView: View {
    let token: TextToken
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text(token.text)
            .font(.system(size: 14))
            .lineLimit(3)  // 最多3行，超过会省略
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(token.entityType.color.opacity(isHovered ? 0.3 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(token.entityType.color, lineWidth: token.isSelected ? 2 : 1)
            )
            .foregroundColor(.primary)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                onTap()
            }
    }
}
