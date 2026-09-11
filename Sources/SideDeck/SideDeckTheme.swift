import SwiftUI

struct ResolvedSideDeckTheme {
    let scheme: ColorScheme
    let accentChoice: AccentChoice

    var canvas: Color { scheme == .dark ? Color(hex: 0x090B0E) : Color(hex: 0xEEF1F5) }
    var rail: Color { scheme == .dark ? Color(hex: 0x0D0F12) : Color(hex: 0xF7F9FC) }
    var surface: Color { scheme == .dark ? Color(hex: 0x171A1F) : Color(hex: 0xFFFFFF) }
    var elevatedSurface: Color { scheme == .dark ? Color(hex: 0x1D2127) : Color(hex: 0xF3F6FA) }
    var primaryText: Color { scheme == .dark ? Color(hex: 0xF5F7FA) : Color(hex: 0x15181D) }
    var secondaryText: Color { scheme == .dark ? Color(hex: 0x9299A6) : Color(hex: 0x626A76) }
    var tertiaryText: Color { scheme == .dark ? Color(hex: 0x69717E) : Color(hex: 0x858D99) }
    var border: Color { scheme == .dark ? Color(hex: 0x2A2F38) : Color(hex: 0xD4DAE3) }
    var divider: Color { border.opacity(0.72) }
    var shadow: Color { Color.black.opacity(scheme == .dark ? 0.42 : 0.16) }
    var accent: Color {
        switch accentChoice {
        case .system: return Color.accentColor
        case .blue: return Color(hex: 0x287EF0)
        case .indigo: return Color(hex: 0x6259E8)
        case .teal: return Color(hex: 0x008E91)
        case .orange: return Color(hex: 0xD86A19)
        }
    }
    var accentForeground: Color { .white }
    var selectionFill: Color { accent.opacity(scheme == .dark ? 0.18 : 0.12) }
    var controlFill: Color { scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06) }
    var controlHover: Color { scheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.10) }
    var disabled: Color { tertiaryText.opacity(0.55) }
    var completionFill: Color { accent }
    var completionMark: Color { accentForeground }
}

private struct SideDeckThemeKey: EnvironmentKey {
    static let defaultValue = ResolvedSideDeckTheme(scheme: .dark, accentChoice: .blue)
}

extension EnvironmentValues {
    var sideDeckTheme: ResolvedSideDeckTheme {
        get { self[SideDeckThemeKey.self] }
        set { self[SideDeckThemeKey.self] = newValue }
    }
}

struct SideDeckThemeContainer<Content: View>: View {
    @ObservedObject var store: SideDeckPreferencesStore
    @Environment(\.colorScheme) private var systemScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        let mode = store.preferences.appearance
        let resolved = mode.resolved(system: systemScheme)
        content()
            .environment(
                \.sideDeckTheme,
                ResolvedSideDeckTheme(scheme: resolved, accentChoice: store.preferences.accent)
            )
            .preferredColorScheme(mode == .system ? nil : resolved)
    }
}
