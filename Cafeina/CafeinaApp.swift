import SwiftUI

@main
struct CafeinaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar accessory app — UI lives in the status item and About window.
        Settings {
            EmptyView()
        }
    }
}
