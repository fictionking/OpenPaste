import SwiftUI

struct TextExplosionView: View {
    @ObservedObject var viewModel: TextExplosionViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            header

            // Type filter bar
            filterBar

            // Content area
            if viewModel.isProcessing {
                Spacer()
                ProgressView()
                Text("正在分析...")
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
                    Text("复制文本后按 Cmd+Shift+B")
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
                    Text("没有可显示的文本")
                        .font(.body)
                    Text("请先复制一些文本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                tokenGrid
                footer
            }

            // Permission request overlay
            if case .failed(let message) = viewModel.insertionResult,
               message.contains("授权") || message.contains("权限") {
                overlayPermission(message: message)
            }
        }
        .frame(width: 500, height: 400)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("文本大爆炸")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部", type: nil, isSelected: viewModel.filterType == nil) {
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
        .padding(.vertical, 8)
    }

    // MARK: - Token Grid

    private var tokenGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(viewModel.filteredTokens) { token in
                    TokenChipView(token: token) {
                        handleTap(on: token)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Button(action: {
                    Task { await viewModel.insertAll() }
                }) {
                    Label("插入全部", systemImage: "doc.text")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)

                Spacer()

                if viewModel.selectedCount > 0 {
                    Text("\(viewModel.selectedCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }

                Button(action: {
                    Task { await viewModel.insertSelected() }
                }) {
                    Label("插入选中", systemImage: "checkmark.circle")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedCount == 0 || viewModel.isProcessing)
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
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text("需要辅助功能权限")
                    .font(.system(size: 20, weight: .semibold))

                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button(action: { openAccessibilitySettings() }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("打开系统设置")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }

                Text("授权后请重启应用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)
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
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? (color ?? .blue) : Color.secondary.opacity(0.1))
                )
                .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
