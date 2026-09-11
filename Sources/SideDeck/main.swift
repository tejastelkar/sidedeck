import AppKit
import Combine
import SwiftUI

// MARK: - Floating Key-Capable Panel
class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum PanelHitRegion {
    static func contains(
        _ point: CGPoint,
        in bounds: CGRect,
        dockOnRight: Bool,
        flyoutOpen: Bool,
        flyoutWidth: CGFloat = 390,
        dockCollapsed: Bool = false
    ) -> Bool {
        if dockCollapsed {
            let tabWidth = SideDeckLayout.collapsedTabWidth
            let tabHeight = SideDeckLayout.collapsedTabHeight
            let tabRect = dockOnRight
                ? CGRect(x: bounds.maxX - tabWidth, y: bounds.midY - tabHeight / 2, width: tabWidth, height: tabHeight)
                : CGRect(x: bounds.minX, y: bounds.midY - tabHeight / 2, width: tabWidth, height: tabHeight)
            return tabRect.contains(point)
        }

        let dockWidth = SideDeckLayout.dockWidth
        let dockRect = dockOnRight
            ? CGRect(x: bounds.maxX - dockWidth, y: bounds.minY, width: dockWidth, height: bounds.height)
            : CGRect(x: bounds.minX, y: bounds.minY, width: dockWidth, height: bounds.height)

        if dockRect.contains(point) { return true }
        guard flyoutOpen else { return false }

        let flyoutRect = dockOnRight
            ? CGRect(x: bounds.maxX - dockWidth - SideDeckLayout.flyoutGap - flyoutWidth, y: bounds.minY, width: flyoutWidth, height: bounds.height)
            : CGRect(x: bounds.minX + dockWidth + SideDeckLayout.flyoutGap, y: bounds.minY, width: flyoutWidth, height: bounds.height)
        return flyoutRect.contains(point)
    }
}

// MARK: - Custom Tracking View to handle mouse events, focus, and click-through
class CustomTrackingView<Content: View>: NSHostingView<Content> {
    var onMouseExit: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExit?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        super.mouseDown(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let isRight = AppDelegate.shared?.isDockOnRight ?? true
        let activeWidget = AppDelegate.shared?.hoverState.activeWidget
        let settingsOpen = AppDelegate.shared?.hoverState.isSettingsOpen ?? false
        let layout = AppDelegate.shared?.currentLayout ?? .preferred
        let flyoutWidth = activeWidget.map { layout.flyoutOuterWidth(for: $0) } ?? 0
        return PanelHitRegion.contains(
            point,
            in: bounds,
            dockOnRight: isRight,
            flyoutOpen: activeWidget != nil || settingsOpen,
            flyoutWidth: settingsOpen ? min(430, max(0, layout.panelSize.width - SideDeckLayout.dockWidth - SideDeckLayout.flyoutGap)) : flyoutWidth,
            dockCollapsed: AppDelegate.shared?.hoverState.isDockCollapsed ?? false
        )
            ? super.hitTest(point)
            : nil
    }
}

// MARK: - Application Delegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, SideDeckHostDelegate {
    static var shared: AppDelegate?

    var panel: FloatingPanel!
    var statusItem: NSStatusItem!
    var isDockOnRight: Bool = true
    var showInDock: Bool = true
    private var dockScreen: NSScreen?
    private var preferenceCancellable: AnyCancellable?

    let hoverState = SideDeckHoverState()
    let state = SideDeckState()
    let preferencesStore = SideDeckPreferencesStore()

    var currentLayout: SideDeckLayout {
        guard let screen = dockScreen ?? screenUnderMouse() ?? NSScreen.main else {
            return .preferred
        }
        return SideDeckLayout(availableSize: screen.visibleFrame.size)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        hoverState.delegate = self

        // Load saved preferences
        showInDock = preferencesStore.preferences.showInDock
        isDockOnRight = preferencesStore.preferences.dockOnRight
        hoverState.setPinned(preferencesStore.preferences.keepOpen)
        hoverState.setCollapseDelay(preferencesStore.preferences.collapseSpeed.delay)
        dockScreen = screenUnderMouse() ?? NSScreen.main

        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        setupStatusItem()
        setupFloatingPanel()
        applyPanelAppearance(preferencesStore.preferences.appearance)

        preferenceCancellable = preferencesStore.$preferences
            .dropFirst()
            .sink { [weak self] preferences in
                self?.apply(preferences)
            }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updatePanelPosition(animated: false)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        updatePanelPosition(animated: false)
        panel.orderFrontRegardless()
        return true
    }

    func setupStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: isDockOnRight ? "sidebar.right" : "sidebar.left", accessibilityDescription: "SideDeck")
        }

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Show/Hide SideDeck", action: #selector(togglePanel), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())

        let sideItem = NSMenuItem(title: "Dock Position", action: nil, keyEquivalent: "")
        let sideSubmenu = NSMenu()
        let leftItem = NSMenuItem(title: "Left Edge", action: #selector(dockLeft), keyEquivalent: "")
        leftItem.target = self
        leftItem.state = isDockOnRight ? .off : .on
        let rightItem = NSMenuItem(title: "Right Edge", action: #selector(dockRight), keyEquivalent: "")
        rightItem.target = self
        rightItem.state = isDockOnRight ? .on : .off
        sideSubmenu.addItem(leftItem)
        sideSubmenu.addItem(rightItem)
        sideItem.submenu = sideSubmenu
        menu.addItem(sideItem)

        let pinItem = NSMenuItem(title: "Keep Dock Open", action: #selector(togglePinned), keyEquivalent: "")
        pinItem.target = self
        pinItem.state = hoverState.isPinned ? .on : .off
        menu.addItem(pinItem)

        let collapseItem = NSMenuItem(title: "Collapse to Edge", action: #selector(collapseDock), keyEquivalent: "")
        collapseItem.target = self
        collapseItem.isEnabled = !hoverState.isDockCollapsed
        menu.addItem(collapseItem)

        let settingsItem = NSMenuItem(title: "Customize SideDeck…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let dockItem = NSMenuItem(title: "Show in macOS Dock", action: #selector(toggleShowInDock), keyEquivalent: "")
        dockItem.target = self
        dockItem.state = showInDock ? .on : .off
        menu.addItem(dockItem)

        menu.addItem(NSMenuItem.separator())
        let donateItem = NSMenuItem(title: "Support Developer on Ko-fi…", action: #selector(openDonate), keyEquivalent: "")
        donateItem.target = self
        menu.addItem(donateItem)

        let quitItem = NSMenuItem(title: "Quit SideDeck", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func setupFloatingPanel() {
        let layout = currentLayout
        panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: layout.panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false

        rebuildHostingView()
        updatePanelPosition(animated: false)
        panel.orderFrontRegardless()
    }

    func rebuildHostingView() {
        let rootView = SideDeckThemeContainer(store: preferencesStore) {
            SideDeckView(
                isDockOnRight: self.isDockOnRight,
                hoverState: self.hoverState,
                state: self.state,
                preferencesStore: self.preferencesStore,
                layout: self.currentLayout
            )
        }
        let trackingView = CustomTrackingView(rootView: rootView)
        trackingView.onMouseExit = { [weak self] in
            DispatchQueue.main.async {
                self?.hoverState.scheduleCollapseIfOutside(delay: 0.12)
            }
        }
        panel.contentView = trackingView
    }

    @objc func screenParametersChanged() {
        if let dockScreen, !NSScreen.screens.contains(where: { $0 === dockScreen }) {
            self.dockScreen = screenUnderMouse() ?? NSScreen.main
        }
        rebuildHostingView()
        updatePanelPosition(animated: false)
    }

    @objc func workspaceDidWake() {
        updatePanelPosition(animated: false)
    }

    private func screenUnderMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(location) })
    }

    func updatePanelPosition(animated: Bool = false) {
        guard let screen = dockScreen ?? screenUnderMouse() ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let layout = SideDeckLayout(availableSize: visibleFrame.size)

        let x: CGFloat
        if isDockOnRight {
            x = visibleFrame.maxX - layout.panelSize.width
        } else {
            x = visibleFrame.minX
        }
        let y: CGFloat = visibleFrame.midY - (layout.panelSize.height / 2)

        let targetRect = NSRect(origin: CGPoint(x: x, y: y), size: layout.panelSize)
        panel.setFrame(targetRect, display: true, animate: animated)
    }

    func openMenu() {
        setupStatusItem()
        statusItem.button?.performClick(nil)
    }

    func refreshDockMenu() {
        setupStatusItem()
    }

    func setExpanded(_ expanded: Bool) {
        updatePanelPosition(animated: false)
        refreshDockMenu()
    }

    @objc func togglePinned() {
        preferencesStore.setKeepOpen(!preferencesStore.preferences.keepOpen)
    }

    @objc func collapseDock() {
        hoverState.collapseDock()
    }

    @objc func openSettings() {
        if !hoverState.isSettingsOpen {
            hoverState.toggleSettings()
        }
        panel.orderFrontRegardless()
    }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            updatePanelPosition(animated: false)
            panel.orderFrontRegardless()
        }
    }

    @objc func toggleShowInDock() {
        preferencesStore.setShowInDock(!preferencesStore.preferences.showInDock)
    }

    @objc func dockLeft() {
        preferencesStore.setDockOnRight(false)
    }

    @objc func dockRight() {
        preferencesStore.setDockOnRight(true)
    }

    private func apply(_ preferences: SideDeckPreferences) {
        let sideChanged = isDockOnRight != preferences.dockOnRight
        let dockVisibilityChanged = showInDock != preferences.showInDock
        isDockOnRight = preferences.dockOnRight
        showInDock = preferences.showInDock
        hoverState.setPinned(preferences.keepOpen)
        hoverState.setCollapseDelay(preferences.collapseSpeed.delay)
        if dockVisibilityChanged {
            NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        }
        applyPanelAppearance(preferences.appearance)
        setupStatusItem()
        if sideChanged {
            rebuildHostingView()
        }
        updatePanelPosition(animated: false)
    }

    private func applyPanelAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system: panel?.appearance = nil
        case .dark: panel?.appearance = NSAppearance(named: .darkAqua)
        case .light: panel?.appearance = NSAppearance(named: .aqua)
        }
    }

    @objc func openDonate() {
        if let url = URL(string: "https://ko-fi.com/tejastelkar") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// Start Application
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
