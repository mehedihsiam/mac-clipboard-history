// ClipboardHistoryAppDelegate.swift
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var lastClipboard: String = ""
    var history: [String] = []
    var popupWindow: NSWindow?
    var skipNextClipboardUpdate = false

    static var shared: AppDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppDelegate.shared = self
        setupMenuBar()
        startClipboardMonitoring()
        setupKeyboardShortcutMonitor()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

            if let button = statusItem.button {
                if let image = NSImage(named: "MenuBarIcon") {
                    button.image = image
                    button.image?.isTemplate = true // makes it adapt to dark/light mode
                } else {
                    print("❌ MenuBarIcon failed to load")
                }
            }

        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true // Ensures correct rendering (light/dark mode)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "No history yet", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
    }

    func updateMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        for (index, item) in history.prefix(10).enumerated() {
            let title = item.count > 40 ? String(item.prefix(40)) + "…" : item
            let menuItem = NSMenuItem(title: "\(index + 1). \(title)", action: #selector(copyToClipboard(_:)), keyEquivalent: "")
            menuItem.representedObject = item
            menuItem.target = self
            menu.addItem(menuItem)
        }

        menu.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
    }

    func startClipboardMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.skipNextClipboardUpdate {
                self.skipNextClipboardUpdate = false
                return
            }

            if let current = NSPasteboard.general.string(forType: .string),
               current != self.lastClipboard {
                self.lastClipboard = current
                self.addToHistory(current)
            }
        }
    }


    func addToHistory(_ item: String) {
        guard !item.isEmpty else { return }

        // Remove if item already exists anywhere
        if let existingIndex = history.firstIndex(of: item) {
            history.remove(at: existingIndex)
        }

        history.insert(item, at: 0)
        if history.count > 10 { history.removeLast() }
        updateMenu()
    }



    @objc func copyToClipboard(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.simulatePaste()
        }
    }

    func triggerClipboardPaste(index: Int) {
        guard index < history.count else { return }
        let item = history[index]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item, forType: .string)
        simulatePaste()
    }

    func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)

        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true)
        let vDown   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let vUp     = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        let cmdUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    func setupKeyboardShortcutMonitor() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, _ in
                if type == .keyDown {
                    let flags = event.flags
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let code = Int(keyCode)

                    if flags.contains([.maskCommand, .maskAlternate]) && code == 9 {
                        print("⌘ + ⌥ + V detected")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            AppDelegate.shared?.showPopupWindow()
                        }
                    }
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            print("Failed to create event tap.")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func showPopupWindow() {
        if popupWindow != nil { return }

        let popupView = PopupClipboardView(history: history, onSelect: { selected in
            AppDelegate.shared?.skipNextClipboardUpdate = true
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(selected, forType: .string)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.simulatePaste()
            }
            self.popupWindow?.close()
            self.popupWindow = nil
        })

        let hostingController = NSHostingController(rootView: popupView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Clipboard History"
        window.setContentSize(NSSize(width: 400, height: 300))
        window.styleMask = [.titled, .closable]
        window.isOpaque = false
        window.level = .floating
        window.center()
        window.title = "📋 Clipboard History"
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = false // Optional

        window.setContentSize(NSSize(width: 400, height: 300))
        window.styleMask = [.titled, .closable]
        window.isOpaque = false
        window.level = .floating
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // 👇 Add this line: observe close and reset popupWindow
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            self.popupWindow = nil
        }

        popupWindow = window
    }


    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}

