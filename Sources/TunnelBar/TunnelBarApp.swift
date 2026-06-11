import SwiftUI

@main
struct TunnelBarApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra("TunnelBar", systemImage: "network") {
            MenuContent(runner: store.runner)
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Window("Tunnels", id: "editor") {
            EditorView(runner: store.runner)
                .environmentObject(store)
        }
        .windowResizability(.contentMinSize)
    }
}
