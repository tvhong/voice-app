import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingPanel: NSPanel!
    private var settingsWindow: NSWindow?
    private var hotkeyManager: HotkeyManager!
    let controller = RecordingController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupFloatingPanel()
        requestAccessibilityIfNeeded()

        hotkeyManager = HotkeyManager(
            onPress: { [weak self] in
                Task { await self?.controller.startRecording() }
            },
            onRelease: { [weak self] in
                Task {
                    await self?.controller.stopAndTranscribe()
                    self?.simulatePaste()
                }
            }
        )
        hotkeyManager.start()
    }

    private func setupFloatingPanel() {
        let view = FloatingMicView(controller: controller, onSettingsOpen: { [weak self] in
            self?.openSettings()
        })

        let panelSize = NSSize(width: 56, height: 56)
        floatingPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        floatingPanel.level = .floating
        floatingPanel.isOpaque = false
        floatingPanel.backgroundColor = .clear
        floatingPanel.hasShadow = false
        floatingPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        floatingPanel.isMovableByWindowBackground = true
        floatingPanel.contentViewController = NSHostingController(rootView: view)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = visible.midX - panelSize.width / 2
            let y = visible.minY + 20
            floatingPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        floatingPanel.orderFront(nil)
    }

    private func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Settings"
        w.contentViewController = NSHostingController(rootView: SettingsView())
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = w
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
