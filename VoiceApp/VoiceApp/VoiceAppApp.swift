import SwiftUI

@main
struct VoiceAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Transcription History", id: "history") {
            HistoryView()
                .environment(appDelegate.controller.history)
        }
        .defaultSize(width: 480, height: 400)
        .defaultLaunchBehavior(.presented)

        Settings { SettingsView() }
    }
}
