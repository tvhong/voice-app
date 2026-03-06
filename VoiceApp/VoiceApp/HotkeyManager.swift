import AppKit

class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onPress: () -> Void
    private let onRelease: () -> Void
    private var isFnDown = false

    init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onPress = onPress
        self.onRelease = onRelease
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        let fnNow = event.modifierFlags.contains(.function)
        if fnNow && !isFnDown {
            isFnDown = true
            onPress()
        } else if !fnNow && isFnDown {
            isFnDown = false
            onRelease()
        }
    }
}
