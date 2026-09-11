import SwiftUI
import AppKit

@main
struct TestRenderer {
    static func main() {
        print("Starting render with @main...")
        let suiteName = "SideDeckPreview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = SideDeckState(defaults: defaults, startServices: false)
        let hoverState = SideDeckHoverState(defaults: defaults)
        let preferencesStore = SideDeckPreferencesStore(defaults: defaults)
        let preferredLayout = SideDeckLayout.preferred

        func renderView<V: View>(_ view: V, name: String) {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2.0
            if let img = renderer.nsImage,
               let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
                print("Saved /tmp/\(name).png (\(img.size))")
            } else {
                print("Failed to render \(name)")
            }
        }

        // 1. Collapsed Dock
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_full")

        // 2. Focus Flyout
        hoverState.activeWidget = .focus
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_focus")

        // 3. Clock Flyout
        hoverState.activeWidget = .clock
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_clock")

        // 4. Status Flyout
        hoverState.activeWidget = .battery
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_battery")

        // 5. Habits Flyout
        hoverState.activeWidget = .habits
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_habits")

        // 6. Hydration Flyout
        hoverState.activeWidget = .water
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_water")

        // 7. Notes Flyout
        hoverState.activeWidget = .notes
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_notes")

        // 8. Collapsed Edge Tab
        hoverState.collapseDock()
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_collapsed")

        // 9. Left Edge Layout
        hoverState.expandDock()
        hoverState.hoverCard(.clock)
        renderView(SideDeckView(isDockOnRight: false, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout), name: "dock_left_clock")

        // 10. Narrow display layout with the widest flyout
        hoverState.activeWidget = .habits
        let narrowLayout = SideDeckLayout(availableSize: CGSize(width: 520, height: 600))
        renderView(SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: narrowLayout), name: "dock_narrow_habits")

        // 11. Settings in dark mode
        hoverState.activeWidget = nil
        hoverState.toggleSettings()
        preferencesStore.setAppearance(.dark)
        renderView(
            SideDeckThemeContainer(store: preferencesStore) {
                SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout)
            },
            name: "dock_settings_dark"
        )

        // 12. Settings and rail in light mode
        preferencesStore.setAppearance(.light)
        renderView(
            SideDeckThemeContainer(store: preferencesStore) {
                SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout)
            },
            name: "dock_settings_light"
        )

        // 13. Habits contrast in light mode
        hoverState.toggleSettings()
        hoverState.hoverCard(.habits)
        renderView(
            SideDeckThemeContainer(store: preferencesStore) {
                SideDeckView(isDockOnRight: true, hoverState: hoverState, state: state, preferencesStore: preferencesStore, layout: preferredLayout)
            },
            name: "dock_habits_light"
        )
    }
}
