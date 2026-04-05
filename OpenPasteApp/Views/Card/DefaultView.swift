import SwiftUI

/// Default content view for displaying unknown clipboard content types
struct DefaultView: View {
    let content: String
    let contentType: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Common.clipboardContent)
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            Text(contentType)
                .font(.caption2)
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    DefaultView(content: "Some content", contentType: "com.unknown.type")
        .frame(width: 300)
        .padding()
        .background(Color.white)
}
