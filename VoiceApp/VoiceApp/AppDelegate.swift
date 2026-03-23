import AppKit
import CoreGraphics
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingPanel: NSPanel!
    private var settingsWindow: NSWindow?
    private var hotkeyManager: HotkeyManager!
    private var hotkeyKeyObserver: NSObjectProtocol?
    private var recordingStartApp: NSRunningApplication?
    let controller = RecordingController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupFloatingPanel()
        requestAccessibilityIfNeeded()
        setupHotkey()
        observeHotkeyKeyChange()
    }

    private func observeHotkeyKeyChange() {
        hotkeyKeyObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let currentKey = HotkeyConfig.key
            if self.hotkeyManager.key != currentKey {
                self.hotkeyManager.stop()
                self.setupHotkey()
            }
        }
    }

    private func setupHotkey() {
        hotkeyManager = HotkeyManager(
            key: HotkeyConfig.key,
            onPress: { [weak self] in
                guard let self else { return }
                switch HotkeyConfig.mode {
                case .hold:
                    self.recordingStartApp = NSWorkspace.shared.frontmostApplication
                    Task { await self.controller.startRecording() }
                case .toggle:
                    if self.controller.state == .recording {
                        Task {
                            await self.controller.stopAndTranscribe()
                            if case .done(let text) = self.controller.state {
                                self.handleTranscriptionOutput(text)
                            }
                        }
                    } else {
                        self.recordingStartApp = NSWorkspace.shared.frontmostApplication
                        Task { await self.controller.startRecording() }
                    }
                }
            },
            onRelease: { [weak self] in
                guard HotkeyConfig.mode == .hold else { return }
                Task {
                    guard let self else { return }
                    await self.controller.stopAndTranscribe()
                    if case .done(let text) = self.controller.state {
                        self.handleTranscriptionOutput(text)
                    }
                }
            }
        )
        hotkeyManager.start()
    }

    private func setupFloatingPanel() {
        let view = FloatingMicView(
            controller: controller,
            onSettingsOpen: { [weak self] in
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
        let options =
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func handleTranscriptionOutput(_ text: String) {
        let currentApp = NSWorkspace.shared.frontmostApplication
        guard let startApp = recordingStartApp,
              currentApp?.bundleIdentifier == startApp.bundleIdentifier else {
            // User switched apps — copy to clipboard only
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return
        }

        // Same app — type directly via keyboard events (no clipboard involved)
        typeText(text)
    }

    private func typeText(_ text: String) {
        let src = CGEventSource(stateID: .hidSystemState)
        for scalar in text.unicodeScalars {
            var chars = [UniChar](scalar.utf16)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            keyDown?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            keyUp?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

}
