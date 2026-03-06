import SwiftUI

@main
struct VoiceAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("VoiceApp", id: "main") {
            TabView {
                Tab("History", systemImage: "clock") {
                    HistoryView()
                        .environment(appDelegate.controller.history)
                }
                Tab("Settings", systemImage: "gear") {
                    SettingsView()
                }
            }
        }
        .defaultSize(width: 480, height: 400)
        .defaultLaunchBehavior(.presented)
    }
}
