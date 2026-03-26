import SwiftUI
import AppKit

struct ShortcutRecorderButton: View {
    @Binding var shortcut: HotkeyShortcut
    @Binding var isRecording: Bool
    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?

    var body: some View {
        Button {
            if isRecording {
                stopListening()
            } else {
                startListening()
            }
        } label: {
            Text(isRecording ? "Press shortcut…" : shortcut.label)
                .frame(minWidth: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .onDisappear {
            stopListening()
        }
    }

    private func startListening() {
        isRecording = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Escape cancels
            if event.keyCode == 53 {
                stopListening()
                return nil
            }

            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .subtracting(.function)

            // Require at least one modifier
            guard !mods.isEmpty else {
                NSSound.beep()
                return nil
            }

            shortcut = HotkeyShortcut(
                keyCode: event.keyCode,
                modifiers: mods.rawValue,
                isFnOnly: false
            )
            stopListening()
            return nil  // swallow the event
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .function {
                shortcut = .fn
                stopListening()
            }
            return event
        }
    }

    private func stopListening() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
        flagsMonitor = nil
        isRecording = false
    }
}
