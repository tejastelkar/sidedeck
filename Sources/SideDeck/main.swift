import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var statusItem: NSStatusItem!
    var isDockOnRight: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
            contentRect: NSRect(x: 0, y: 0, width: 72, height: 600),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        
        let hostingView = NSHostingView(rootView: SideDeckView())
        panel.contentView = hostingView
        
        updatePanelPosition()
        panel.orderFront(nil)
    }
    
    @objc func screenParametersChanged() {
        updatePanelPosition()
    }
    
    func updatePanelPosition() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 72
        let panelHeight: CGFloat = 580
        
        let x: CGFloat = isDockOnRight ? (visibleFrame.maxX - panelWidth - 8) : (visibleFrame.minX + 8)
        let y: CGFloat = visibleFrame.midY - (panelHeight / 2)
        
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true, animate: true)
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
        updatePanelPosition()
    }
    
    @objc func dockRight() {
        isDockOnRight = true
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
app.setActivationPolicy(.accessory) // Accessory app: lives in status bar, no dock icon
app.run()
