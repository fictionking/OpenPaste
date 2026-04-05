import SwiftUI

/// A slide-to-confirm button view
/// User must drag the slider all the way to the right to trigger the action
/// Prevents accidental taps and provides clear visual feedback
struct SlideToConfirmView: View {
    // MARK: - Properties

    /// The title text to display
    var title: String

    /// The color theme for the slider
    var themeColor: Color = .red

    /// Callback when slider reaches the end
    var onConfirm: () -> Void

    /// Current drag offset
    @State private var dragOffset: CGFloat = 0

    /// Whether the action has been triggered
    @State private var isConfirmed = false

    // MARK: - Computed Properties

    /// Current color based on slide progress (green → yellow → red)
    private var currentColor: Color {
        let progress = dragOffset / slideDistance
        if progress < 0.5 {
            // Green to yellow (hue: 0.33 → 0.16)
            let hue = 0.33 - (progress * 2 * 0.17)
            return Color(hue: hue, saturation: 0.8, brightness: 0.9)
        } else {
            // Yellow to red (hue: 0.16 → 0)
            let hue = 0.16 - ((progress - 0.5) * 2 * 0.16)
            return Color(hue: hue, saturation: 0.9, brightness: 0.9)
        }
    }

    // MARK: - Constants

    private let knobSize: CGFloat = 26
    private let cornerRadius: CGFloat = 13
    private let trackHeight: CGFloat = 28
    private let slideDistance: CGFloat = 140

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            // Background track with fixed green-to-red gradient
            RoundedRectangle(cornerRadius: trackHeight / 2)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.green, location: 0.0),
                            .init(color: Color.orange, location: 0.5),
                            .init(color: Color.red, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: slideDistance + knobSize, height: trackHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

            // Confirm text (right-aligned, stays visible as knob slides)
            Text(title)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .opacity(isConfirmed ? 0 : 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)

            // Knob
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            currentColor,
                            currentColor.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: knobSize, height: knobSize)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.black, lineWidth: 2)
                )
                .shadow(color: currentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                .overlay(
                    Image(systemName: isConfirmed ? "checkmark" : "chevron.right")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .imageScale(.medium)
                )
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !isConfirmed else { return }

                            // Calculate new offset
                            let newOffset = max(0, min(value.translation.width, slideDistance))

                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = newOffset
                            }

                            // Check if slider reached the end
                            if newOffset >= slideDistance * 0.95 {
                                confirm()
                            }
                        }
                        .onEnded { _ in
                            // Snap back if not confirmed
                            guard !isConfirmed else { return }

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                )
        }
        .frame(width: slideDistance + knobSize, height: knobSize)
        .disabled(isConfirmed)
    }

    // MARK: - Methods

    /// Execute the confirm action
    private func confirm() {
        isConfirmed = true

        // Complete the slide animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = slideDistance
        }

        // Trigger callback after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onConfirm()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        Text("Slide to Confirm Examples")
            .font(.title)
            .padding()

        SlideToConfirmView(
            title: L10n.SlideAction.slideToClear,
            themeColor: .red,
            onConfirm: {
                print("Clear confirmed!")
            }
        )

        SlideToConfirmView(
            title: L10n.SlideAction.slideToDelete,
            themeColor: .orange,
            onConfirm: {
                print("Delete confirmed!")
            }
        )

        SlideToConfirmView(
            title: L10n.SlideAction.slideToConfirm,
            themeColor: .blue,
            onConfirm: {
                print("Action confirmed!")
            }
        )
    }
    .padding()
    .background(Color(.windowBackgroundColor))
}
