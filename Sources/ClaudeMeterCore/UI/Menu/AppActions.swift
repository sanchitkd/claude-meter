import AppKit
import Foundation

@MainActor
public final class AppActions: ObservableObject {
    private weak var stateManager: UsageStateManager?
    private let settings: SettingsManager
    private let logger: AppLogger
    private var preferencesHandler: (() -> Void)?
    private var signInHandler: (() -> Void)?

    public init(
        stateManager: UsageStateManager,
        settings: SettingsManager,
        logger: AppLogger
    ) {
        self.stateManager = stateManager
        self.settings = settings
        self.logger = logger
    }

    public func setPreferencesHandler(_ handler: @escaping () -> Void) {
        preferencesHandler = handler
    }

    public func setSignInHandler(_ handler: @escaping () -> Void) {
        signInHandler = handler
    }

    public func signIn() {
        signInHandler?()
    }

    public func refresh() {
        stateManager?.refreshNow()
    }

    public func openClaude() {
        open(URL(string: "https://claude.ai")!)
    }

    public func openUsagePage() {
        open(URL(string: "https://claude.ai/settings/usage")!)
    }

    public func openLogs() {
        NSWorkspace.shared.activateFileViewerSelecting([logger.logFileURL])
    }

    public func openPreferences() {
        preferencesHandler?()
    }

    public func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
