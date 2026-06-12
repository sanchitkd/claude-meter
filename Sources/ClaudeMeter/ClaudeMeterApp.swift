import ClaudeMeterCore
import SwiftUI

@main
struct ClaudeMeterApp: App {
    @NSApplicationDelegateAdaptor(ClaudeIslandAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
