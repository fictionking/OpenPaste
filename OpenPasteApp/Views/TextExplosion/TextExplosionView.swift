import SwiftUI

struct TextExplosionView: View {
    @ObservedObject var viewModel: TextExplosionViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Filter bar with close button
                filterBarWithClose

                // Content area
                if viewModel.isProcessingOCR {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView(value: viewModel.ocrProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)

                        Text(L10n.TextExplosion.processing)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .transition(.opacity)
                    Spacer()
                } else if viewModel.isProcessing {
                    Spacer()
                    ProgressView()
                    Text(L10n.TextExplosion.analyzing)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.body)
                        Text(L10n.TextExplosion.emptyHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if viewModel.tokens.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(L10n.TextExplosion.noText)
                            .font(.body)
                        Text(L10n.TextExplosion.emptyHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    tokenGrid
                }
            }
            .frame(width: 700, height: 280)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Permission request overlay
            if case .failed(let message) = viewModel.insertionResult,
               message.contains(L10n.TextExplosion.needPermission) || message.contains("permission") || message.contains("授权") || message.contains("权限") {
                overlayPermission(message: message)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBarWithClose: some View {
        HStack {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: L10n.Common.all, type: nil, isSelected: viewModel.filterType == nil, color: .gray) {
                        viewModel.filterType = nil
                    }

                    ForEach(TokenType.allCases.filter({ $0 != .plain }), id: \.self) { type in
                        FilterChip(
                            title: type.displayName,
                            type: type,
                            isSelected: viewModel.filterType == type,
                            color: type.color
                        ) {
                            viewModel.filterType = viewModel.filterType == type ? nil : type
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Token Grid

    private var tokenGrid: some View {
        ScrollView {
            FlowLayout(spacing: 6) {
                ForEach(viewModel.filteredTokens) { token in
                    TokenChipView(token: token) {
                        handleTap(on: token)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func handleTap(on token: TextToken) {
        Task { await viewModel.insertToken(token) }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Permission Overlay

    private func overlayPermission(message: String) -> some View {
        ZStack {
            // Dark background covering entire panel
            Color.black.opacity(0.7)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // White info box with original size
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text(L10n.TextExplosion.needPermission)
                    .font(.system(size: 20, weight: .semibold))

                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button(action: openAccessibilitySettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text(L10n.TextExplosion.openSettings)
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .padding(.horizontal, -4)
                        .padding(.vertical, -4)
                )

                Text(L10n.TextExplosion.restartAfterAuth)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 400)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
        }
        .transition(.opacity)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let type: TokenType?
    let isSelected: Bool
    var color: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? (color ?? .blue) : Color.secondary.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke((color ?? .blue), lineWidth: isSelected ? 2 : 1.5)
                    )

                Group {
                    if type == .currency {
                        Text("$")
                            .font(.system(size: 13, weight: .medium))
                    } else if type == .date {
                        Image(systemName: type?.iconName ?? "calendar")
                            .font(.system(size: 11))
                    } else {
                        Image(systemName: type?.iconName ?? "asterisk")
                            .font(.system(size: 11))
                    }
                }
                .foregroundColor(isSelected ? .white : (color ?? .blue))
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}
