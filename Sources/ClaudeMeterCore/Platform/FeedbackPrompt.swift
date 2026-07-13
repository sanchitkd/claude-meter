import AppKit
import Foundation

/// One gentle ask, once, ever — on the first launch that happens at least three days after
/// the very first launch.
///
/// Deliberately not on day one: at first launch there is nothing to give feedback *about*,
/// and an uninvited browser tab is the fastest way to get a menu-bar app dragged to the bin.
@MainActor
public final class FeedbackPrompt {
    private let defaults = UserDefaults.standard
    private let firstLaunchKey = "firstLaunchDate"
    private let shownKey = "feedbackPromptShown"
    private let waitInterval: TimeInterval = 3 * 24 * 60 * 60
    private let settleDelay: UInt64 = 8_000_000_000   // let the app finish launching first
    private let logger: AppLogger?

    public init(logger: AppLogger? = nil) { self.logger = logger }

    public func considerPrompting() {
        guard let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date else {
            defaults.set(Date(), forKey: firstLaunchKey)   // first ever launch — just stamp it
            return
        }
        guard !defaults.bool(forKey: shownKey),
              Date().timeIntervalSince(firstLaunch) >= waitInterval else { return }

        defaults.set(true, forKey: shownKey)   // set before showing: never ask twice, even after a crash

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            self?.present()
        }
    }

    private func present() {
        let alert = NSAlert()
        alert.messageText = "How's Claude Meter treating you?"
        alert.informativeText = """
        It's been in your menu bar for a few days now. Claude Meter is free, open source, and \
        built by one person — I'd genuinely love to hear what's broken, what's missing, or just \
        that it works.
        """
        alert.addButton(withTitle: "Send feedback")
        alert.addButton(withTitle: "It's great — close")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(AppLinks.feedback)
        }
        logger?.info("Feedback prompt shown (day-3, one time).")
    }
}
