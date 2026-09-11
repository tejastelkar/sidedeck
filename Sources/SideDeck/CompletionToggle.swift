import SwiftUI

enum CompletionControlSize {
    case compact
    case regular

    var glyphSize: CGFloat { self == .compact ? 10 : 16 }
    var hitTarget: CGFloat { self == .compact ? 18 : 24 }
    var checkmarkSize: CGFloat { self == .compact ? 5.5 : 8 }
}

struct CompletionToggle: View {
    let label: String
    let isCompleted: Bool
    let size: CompletionControlSize
    let action: () -> Void

    @Environment(\.sideDeckTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmationScale: CGFloat = 1

    var body: some View {
        Button {
            action()
            guard !reduceMotion else { return }
            confirmationScale = 0.82
            withAnimation(.spring(response: 0.2, dampingFraction: 0.68)) {
                confirmationScale = 1
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isCompleted ? theme.completionFill : Color.clear)
                Circle()
                    .stroke(isCompleted ? theme.completionFill : theme.secondaryText, lineWidth: size == .compact ? 1 : 1.2)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: size.checkmarkSize, weight: .bold))
                        .foregroundStyle(theme.completionMark)
                        .transition(.opacity)
                }
            }
            .frame(width: size.glyphSize, height: size.glyphSize)
            .frame(width: size.hitTarget, height: size.hitTarget)
            .contentShape(Rectangle())
            .scaleEffect(confirmationScale)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isCompleted ? "Completed" : "Not completed")
    }
}
