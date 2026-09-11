# SideDeck Theme, Customization, and Stability Design

## Goal

Make SideDeck visually consistent, responsive, permission-aware, and resistant to malformed persisted data while preserving its compact edge-dock identity. The release must add a complete light appearance, reliable notes completion controls, real Wi-Fi naming when macOS permits it, real-only habit history, smoother pointer interactions, and practical customization.

## Scope

This change covers:

- Semantic light, dark, and system-following appearance.
- Standard controls for completion, selection, buttons, cards, and flyouts.
- Persisted appearance, dock, interaction, and widget-visibility preferences.
- A dedicated Wi-Fi status service and Location authorization flow.
- A one-time migration from generated habit samples to one real check-in today.
- A user-triggered, confirmed habit-history reset.
- Responsive layout rules for display size and density.
- Defensive persistence and interaction state handling.
- Automated state, migration, layout, service, and interaction tests plus rendered visual verification.

This change does not add cloud sync, third-party analytics, drag-and-drop widget reordering, or network joining.

## Architecture

The current `SideDeckView.swift` mixes persistence, system services, interaction coordination, theme values, and every view. The implementation will extract focused units while keeping the executable target and existing user data format compatible where possible:

- `SideDeckTheme.swift`: semantic colors, radii, spacing, control metrics, and theme resolution.
- `SideDeckPreferences.swift`: Codable preference enums and a main-actor preferences store backed by `UserDefaults`.
- `SideDeckState.swift`: tasks, notes, focus, habits, hydration, migrations, and defensive decoding.
- `WiFiMonitor.swift`: CoreWLAN and CoreLocation integration with explicit status values.
- `CompletionToggle.swift`: the shared task/note completion control.
- `SideDeckLayout.swift`: screen-aware panel, flyout, density, and widget visibility geometry.
- `SideDeckView.swift`: composition of the dock, flyouts, and settings UI.
- `main.swift`: application lifecycle, panel ownership, permissions, and screen placement.

State exposed to SwiftUI remains main-actor isolated. Hardware callbacks are normalized into immutable snapshots before updating published UI state.

## Theme and Visual Rules

`AppearanceMode` has three values: `system`, `dark`, and `light`. System is the default and resolves from SwiftUI's current color scheme. A user override persists across launches.

Views may not use literal white or black for interface text, surfaces, borders, or completion state. They consume semantic theme roles:

- `canvas`, `rail`, `surface`, `elevatedSurface`
- `primaryText`, `secondaryText`, `tertiaryText`
- `border`, `divider`, `shadow`
- `accent`, `accentForeground`, `selectionFill`
- `controlFill`, `controlHover`, `disabled`
- `completionFill`, `completionMark`

Dark mode keeps the graphite palette. Light mode uses cool neutral whites and grays, not pure white-on-white surfaces. Both modes retain the selected accent and meet readable text contrast. System materials remain behind theme overlays so translucency behaves naturally.

Corner radii and spacing use the existing shared token hierarchy. Reusable component styles determine their own radius; individual call sites do not provide arbitrary radius values.

Completion controls are consistent everywhere:

- Unfinished: transparent center, semantic border.
- Finished: accent-filled circle with an accent-foreground checkmark.
- Minimum compact hit target of 18 points and expanded hit target of 24 points.
- One short scale/fade confirmation animation that respects Reduce Motion.
- Identical accessibility label and `Completed`/`Not completed` value behavior.

## Preferences and Customization

The settings flyout groups options without adding another full window:

### Appearance

- Theme: Auto, Dark, Light.
- Accent: Blue, Indigo, Teal, Orange, or system accent.
- Density: Compact or Comfortable.
- Translucency: On or Off.

### Dock

- Left or right edge.
- Keep open or auto-collapse.
- Auto-collapse delay: Fast, Normal, Relaxed.
- Show SideDeck in the macOS Dock.

### Widgets

- Visibility toggle for Focus, Clock, Status, Habits, Hydration, and Notes.
- At least one widget must remain visible; disabling the last visible widget is rejected in the UI and state layer.

### Data

- Reset habit history, guarded by a confirmation dialog.
- Reset appearance and dock preferences to defaults.

Preferences are written immediately and applied without rebuilding unrelated application state.

## Interaction Rules

Hover and click are separate inputs into one deterministic interaction coordinator:

- Hover previews a flyout only when no widget is click-selected.
- Clicking a widget selects and keeps its flyout open.
- Clicking the selected widget closes it.
- Clicking another widget switches directly to it.
- A stale hover-exit timer may never close a click-selected flyout.
- Entering the dock or flyout cancels pending collapse work.
- Auto-collapse begins only when the pointer is outside both regions and no click-selected flyout is open.
- Only state transitions animate. Repeated identical events perform no animation.
- Reduce Motion replaces spring/scale transitions with a short opacity change.

Buttons inside cards consume their click without also toggling the parent card. Completion toggles therefore update the item once and do not open or close the notes flyout as a side effect.

## Wi-Fi Behavior and Permissions

`WiFiMonitor` exposes a snapshot rather than fallback strings:

- Power state.
- Connection state.
- SSID when authorized and available.
- RSSI when available.
- Authorization state: not determined, denied/restricted, or authorized.
- A user-facing status when the SSID is unavailable.

The app bundle includes `NSLocationWhenInUseUsageDescription`. SideDeck requests Location access only when the status flyout needs the network name or when the user explicitly chooses Enable Network Name. It does not repeatedly prompt after denial.

If authorized, CoreWLAN is the source of the current SSID. If macOS still returns no SSID, the UI says `Connected network` and offers Refresh rather than inventing a network name. If denied, the UI says `Allow Location Access` and provides an action that opens the app's Location settings. Wi-Fi power state continues to work without authorization.

The monitor handles missing interfaces and nil API values without force unwraps. Refreshes occur on a modest timer and network/power notifications where available; only changed snapshots publish.

## Habit-History Migration and Reset

Existing generated sample matrices are not trustworthy history. A one-time migration key, `sidedeck_real_habits_migration_v1`, controls cleanup.

On the first launch containing this migration:

- Replace the compact and annual matrices with zeros.
- Set only today's final cell to level 1.
- Set today's count to 1 and the streak to 1.
- Set the last check-in date to the migration date.
- Persist the clean matrices first and write the migration key last, so an interrupted migration safely retries rather than marking incomplete data as migrated.

The migration runs once and never overwrites later real history. New installations begin empty until the first user check-in; the one-check-in migration applies only when legacy generated matrices exist.

The Reset History action asks for confirmation, then clears both matrices, today's count, streak, and last-check-in date. It does not delete tasks, notes, hydration, or preferences. After reset, the next check-in creates exactly one level-1 cell for today.

## Persistence and Error Handling

Every persisted collection is decoded through a validating loader:

- Corrupt JSON falls back to an empty safe value without crashing.
- Habit arrays are normalized to their required lengths and values are clamped to 0...4.
- Invalid enum preference values fall back to documented defaults.
- Negative timer, hydration, and count values are clamped.
- Failed writes retain in-memory state and emit a debug log; the interface remains usable.

No user-facing control indexes an array without checking bounds. System APIs, screen lookup, and permissions are handled as optional state. Long-lived timers and observers are cancelled when their owner deinitializes.

## Responsive Layout

`SideDeckLayout` remains the single geometry authority and accepts screen size, safe margins, density, and visible widgets.

- Panel width is derived from dock width, the active flyout's measured requirement, gap, and shadow clearance, then clamped to the selected screen.
- Flyout content uses available width and replaces wide multi-column layouts with a single column below their minimum width.
- Panel height is clamped to the visible frame.
- If visible widgets exceed available height, the rail becomes vertically scrollable while pin and collapse controls remain reachable.
- Text truncates only in compact rail cards; expanded flyouts wrap or scroll.
- Hit-testing uses the same computed frames as rendering.
- Left and right placement are mirror layouts, not independent coordinate constants.

## Testing and Verification

Implementation follows red-green-refactor. Required automated coverage:

- Theme resolution and semantic token availability in all three modes.
- Preference defaults, persistence, invalid-value recovery, and at-least-one-widget validation.
- Notes and task completion toggle once, persist, and do not trigger parent-card selection.
- Click selection survives stale hover exits; repeated events do not create extra transitions.
- Wi-Fi snapshots for authorized SSID, denied permission, missing interface, and nil SSID.
- Legacy habit migration produces exactly one check-in and runs once.
- Reset clears only habit data; next check-in creates one real entry.
- Corrupt task, note, habit, and preference data cannot crash initialization.
- Responsive frames remain in bounds for left/right, compact/comfortable, wide/narrow, and short screens.

Rendered verification covers every dock/flyout in dark and light modes, both edges, narrow width, short height, reduced motion, and hidden-widget combinations. Live verification covers notes completion, repeated card clicks, collapse/pin behavior, theme switching, permission messaging, and the actual SSID when Location is authorized.

Release verification requires a clean test run, successful release build, valid app signature, valid DMG checksum, correct bundle version, and only the newest installed app plus newest distributable DMG outside Trash.
