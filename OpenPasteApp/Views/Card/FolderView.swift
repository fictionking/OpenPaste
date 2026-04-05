import SwiftUI

/// Folder content view for displaying folder/directory clipboard items
struct FolderView: View {
    let content: String

    @State private var folderIcon: NSImage?
    @State private var folderName: String?

    var body: some View {
        HStack(spacing: 12) {
            // Folder icon
            Group {
                if let icon = folderIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let name = folderName {
                        Text(name)
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .lineLimit(2)

                        Text(L10n.ContentType.folder)
                            .font(.caption2)
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                    } else {
                        Text(L10n.ContentType.folder)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    }
                }
            }
        }
        .onAppear {
            loadFolderInfo()
        }
    }

    // MARK: - Private Methods

    private func loadFolderInfo() {
        guard let data = content.data(using: .utf8),
              let urls = try? JSONDecoder().decode([String].self, from: data),
              let urlString = urls.first,
              let url = URL(string: urlString)?.standardizedFileURL else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let name = url.lastPathComponent

            DispatchQueue.main.async {
                self.folderIcon = icon
                self.folderName = name
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FolderView(content: "[\"file:///Users/example/Documents/MyFolder\"]")
        .frame(width: 300)
        .padding()
        .background(Color.white)
}
