import SwiftUI

@main
struct TunnelblickCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No windows — menu bar only app
        Settings {
            EmptyView()
        }
    }
}
