import AppKit

class HotkeyManager {
    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []
    private let onPress: () -> Void
    private let onRelease: () -> Void
    private var isKeyDown = false
    let key: HotkeyKey

    // Virtual key code for 'D'
    private static let kVKCodeD: UInt16 = 2

    init(key: HotkeyKey, onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.key = key
        self.onPress = onPress
        self.onRelease = onRelease
    }

    func start() {
        switch key {
        case .fn:
            let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFn(event)
            }
            let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFn(event)
                return event
            }
            if let global { globalMonitors.append(global) }
            if let local { localMonitors.append(local) }

        case .commandD:
            let globalDown = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleCommandD(event, isDown: true)
            }
            let globalUp = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
                self?.handleCommandD(event, isDown: false)
            }
            let localDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.handleCommandD(event, isDown: true) == true {
                    return nil // swallow the event
                }
                return event
            }
            let localUp = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
                if self?.handleCommandD(event, isDown: false) == true {
                    return nil
                }
                return event
            }
            if let globalDown { globalMonitors.append(globalDown) }
            if let globalUp { globalMonitors.append(globalUp) }
            if let localDown { localMonitors.append(localDown) }
            if let localUp { localMonitors.append(localUp) }
        }
    }

    func stop() {
        for monitor in globalMonitors { NSEvent.removeMonitor(monitor) }
        for monitor in localMonitors { NSEvent.removeMonitor(monitor) }
        globalMonitors.removeAll()
        localMonitors.removeAll()
        isKeyDown = false
    }

    private func handleFn(_ event: NSEvent) {
        let fnNow = event.modifierFlags.contains(.function)
        if fnNow && !isKeyDown {
            isKeyDown = true
            onPress()
        } else if !fnNow && isKeyDown {
            isKeyDown = false
            onRelease()
        }
    }

    @discardableResult
    private func handleCommandD(_ event: NSEvent, isDown: Bool) -> Bool {
        guard event.keyCode == Self.kVKCodeD,
              event.modifierFlags.contains(.command) else {
            return false
        }

        if isDown && !isKeyDown {
            isKeyDown = true
            onPress()
        } else if !isDown && isKeyDown {
            isKeyDown = false
            onRelease()
        }
        return true
    }
}
