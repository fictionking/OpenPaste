import SwiftUI

/// File content view for displaying file URL clipboard items
struct FileView: View {
    let content: String

    @State private var fileIcon: NSImage?
    @State private var fileSize: String?
    @State private var fileType: String?

    var body: some View {
        HStack(spacing: 12) {
            // Real file icon from system
            Group {
                if let icon = fileIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "doc")
                                .foregroundColor(.secondary)
                                .font(.title3)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let fileName = extractFileName(from: content) {
                    Text(fileName)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)

                    // File info line
                    HStack(spacing: 6) {
                        if let fileSize = fileSize {
                            Text(fileSize)
                                .font(.caption2)
                                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        }

                        if let fileType = fileType {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))

                            Text(fileType)
                                .font(.caption2)
                                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        }
                    }
                } else {
                    Text(L10n.ContentType.file)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                }
            }
        }
        .onAppear {
            loadFileInfo()
        }
    }

    // MARK: - Private Methods

    /// Extract file name from file URL content
    private func extractFileName(from content: String) -> String? {
        guard let data = content.data(using: .utf8),
              let urls = try? JSONDecoder().decode([String].self, from: data),
              let firstURL = urls.first,
              let url = URL(string: firstURL) else {
            return nil
        }
        return url.lastPathComponent
    }

    /// Load file information (size, type, and icon)
    private func loadFileInfo() {
        guard let data = content.data(using: .utf8),
              let urls = try? JSONDecoder().decode([String].self, from: data),
              let urlString = urls.first,
              let url = URL(string: urlString)?.standardizedFileURL else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Get file icon from system
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            // Get file size
            var sizeString: String?
            var ext: String?

            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                let fileSizeValue = attributes[.size] as? UInt64 ?? 0
                sizeString = formatFileSize(fileSizeValue)

                let pathExt = url.pathExtension.uppercased()
                ext = pathExt.isEmpty ? nil : pathExt
            }

            DispatchQueue.main.async {
                self.fileIcon = icon
                self.fileSize = sizeString
                self.fileType = ext
            }
        }
    }

    /// Format file size to human readable string
    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Preview

#Preview {
    FileView(content: "[\"file:///Users/example/Documents/report.pdf\"]")
        .frame(width: 300)
        .padding()
        .background(Color.white)
}
