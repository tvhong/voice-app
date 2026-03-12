import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingPanel: NSPanel!
    private var settingsWindow: NSWindow?
    private var hotkeyManager: HotkeyManager!
    private var recordingStartApp: NSRunningApplication?
    let controller = RecordingController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupFloatingPanel()
        requestAccessibilityIfNeeded()
        setupHotkey()
    }

    private func setupHotkey() {
        hotkeyManager = HotkeyManager(
            onPress: { [weak self] in
                self?.recordingStartApp = NSWorkspace.shared.frontmostApplication
                Task { await self?.controller.startRecording() }
            },
            onRelease: { [weak self] in
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

        // Same app — try AX direct insert first (no clipboard involved)
        if insertTextViaAccessibility(text) { return }

        // Fallback: clipboard + paste, then restore previous clipboard contents
        pasteRestoringClipboard(text)
    }

    private func pasteRestoringClipboard(_ text: String) {
        let savedItems: [NSPasteboardItem] = NSPasteboard.general.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSPasteboard.general.clearContents()
            if !savedItems.isEmpty {
                NSPasteboard.general.writeObjects(savedItems)
            }
        }
    }

    @discardableResult
    private func insertTextViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return false
        }
        let result = AXUIElementSetAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }
}
