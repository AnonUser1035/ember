import SwiftUI
import AppKit

@main
struct EmberApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView(appState: appState)
        } label: {
            MenuBarLabel(appState: appState)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Ember") {
                    Task {
                        await appState.prepareForQuit()
                        NSApp.terminate(nil)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }

        WindowGroup(id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)

        WindowGroup(id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}
