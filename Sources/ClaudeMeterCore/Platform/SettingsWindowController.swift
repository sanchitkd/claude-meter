import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    private let settings: SettingsManager
    private let logger: AppLogger?
    private let onQuit: (() -> Void)?
    private var window: NSWindow?

    public init(settings: SettingsManager, logger: AppLogger? = nil, onQuit: (() -> Void)? = nil) {
        self.settings = settings
        self.logger = logger
        self.onQuit = onQuit
    }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(rootView: SettingsView(settings: settings, logger: logger, onQuit: onQuit))
        let window = NSWindow(contentViewController: controller)
        window.title = "Claude Meter Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("ClaudeMeterPreferences")
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
