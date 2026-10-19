import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var notchPanel: NotchPanel!
    var viewModel = NotchViewModel()
    var settingsWindow: NSWindow?
    private var statusMenu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel.onOpenSettings = { [weak self] in
            DispatchQueue.main.async {
                self?.openPreferences()
            }
        }
        
        notchPanel = NotchPanel(viewModel: viewModel)
        notchPanel.orderFrontRegardless()
        
        setupStatusItem()
        
        HotKeyManager.shared.register { [weak self] in
            DispatchQueue.main.async {
                self?.viewModel.toggleExpand()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notchPanel.reposition(animated: true)
        }
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "macbook.gen2", accessibilityDescription: "DynamicBox")
            button.toolTip = "DynamicBox (Click to toggle, right-click for menu)"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        createMenu()
    }
    
    func createMenu() {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "DynamicBox", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "Toggle Notch (⌥ Space)", action: #selector(toggleNotch), keyEquivalent: "")
        menu.addItem(toggleItem)
        
        let wingsTitle = viewModel.isOuterPanelHidden ? "Show Outer Island Wings" : "Hide Outer Island Wings"
        let toggleWingsItem = NSMenuItem(title: wingsTitle, action: #selector(toggleOuterWings), keyEquivalent: "")
        menu.addItem(toggleWingsItem)
        
        menu.addItem(NSMenuItem(title: "Clear File Shelf", action: #selector(clearShelf), keyEquivalent: "k"))
        menu.addItem(NSMenuItem(title: "Open AirDrop...", action: #selector(openAirDrop), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DynamicBox", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusMenu = menu
    }
    
    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            createMenu()
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            DispatchQueue.main.async {
                self.statusItem.menu = nil
            }
        } else {
            viewModel.toggleExpand()
        }
    }
    
    @objc func toggleNotch() {
        viewModel.toggleExpand()
    }
    
    @objc func toggleOuterWings() {
        viewModel.toggleOuterPanel()
    }
    
    @objc func clearShelf() {
        viewModel.clearAllFiles()
    }
    
    @objc func openAirDrop() {
        let urls = viewModel.stashedFiles.map { $0.url }
        if !urls.isEmpty {
            viewModel.triggerAirDrop(urls: urls)
        } else {
            if let service = NSSharingService(named: .sendViaAirDrop) {
                service.perform(withItems: [])
            }
        }
    }
    
    @objc func openPreferences() {
        viewModel.collapse(immediate: true)
        if settingsWindow == nil {
            let settingsView = SettingsView(viewModel: viewModel)
            let hosting = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hosting)
            window.title = "DynamicBox Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

@main
struct Launcher {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
