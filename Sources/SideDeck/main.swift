import AppKit
import SwiftUI

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
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    
    var panel: NSPanel!
    var statusItem: NSStatusItem!
    var isDockOnRight: Bool = false
    var isExpanded: Bool = false
    
    let collapsedWidth: CGFloat = 84
    let expandedWidth: CGFloat = 380
    let panelHeight: CGFloat = 620
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupStatusItem()
        setupFloatingPanel()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "SideDeck")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle SideDeck (⌥D)", action: #selector(togglePanel), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        
        let sideItem = NSMenuItem(title: "Dock Position", action: nil, keyEquivalent: "")
        let sideSubmenu = NSMenu()
        sideSubmenu.addItem(NSMenuItem(title: "Left Edge", action: #selector(dockLeft), keyEquivalent: ""))
        sideSubmenu.addItem(NSMenuItem(title: "Right Edge", action: #selector(dockRight), keyEquivalent: ""))
        sideItem.submenu = sideSubmenu
        menu.addItem(sideItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SideDeck", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    func setupFloatingPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: collapsedWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.acceptsMouseMovedEvents = true
        
        rebuildHostingView()
        updatePanelPosition(animated: false)
        panel.orderFront(nil)
    }
    
    func rebuildHostingView() {
        let rootView = SideDeckView(isDockOnRight: isDockOnRight)
        let trackingView = CustomTrackingView(rootView: rootView)
        trackingView.onMouseExit = { [weak self] in
            DispatchQueue.main.async {
                self?.setExpanded(false)
            }
        }
        panel.contentView = trackingView
    }
    
    @objc func screenParametersChanged() {
        updatePanelPosition(animated: true)
    }
    
    func updatePanelPosition(animated: Bool = true) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let currentWidth = isExpanded ? expandedWidth : collapsedWidth
        
        let x: CGFloat
        if isDockOnRight {
            x = visibleFrame.maxX - currentWidth - 8
        } else {
            x = visibleFrame.minX + 8
        }
        let y: CGFloat = visibleFrame.midY - (panelHeight / 2)
        
        let targetRect = NSRect(x: x, y: y, width: currentWidth, height: panelHeight)
        panel.setFrame(targetRect, display: true, animate: animated)
    }
    
    func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        updatePanelPosition(animated: true)
    }
    
    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
        }
    }
    
    @objc func dockLeft() {
        isDockOnRight = false
        rebuildHostingView()
        updatePanelPosition()
    }
    
    @objc func dockRight() {
        isDockOnRight = true
        rebuildHostingView()
        updatePanelPosition()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// Start Application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
