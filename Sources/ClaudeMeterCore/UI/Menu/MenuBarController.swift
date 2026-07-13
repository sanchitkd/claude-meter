import AppKit
import Combine

@MainActor
public final class MenuBarController: NSObject {
    private let settings: SettingsManager
    private let actions: AppActions
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    public init(settings: SettingsManager, actions: AppActions) {
        self.settings = settings
        self.actions = actions
        super.init()

        settings.$showMenuBarIcon
            .sink { [weak self] visible in
                Task { @MainActor [weak self] in
                    self?.setVisible(visible)
                }
            }
            .store(in: &cancellables)
    }

    private func setVisible(_ visible: Bool) {
        if visible, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.image = NSImage(
                systemSymbolName: "chart.line.uptrend.xyaxis",
                accessibilityDescription: "Claude Meter"
            )
            item.button?.image?.isTemplate = true
            item.menu = makeMenu()
            statusItem = item
        } else if !visible, let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "Claude Meter")
        menu.addItem(NSMenuItem(title: "Sign in to Claude", action: #selector(signIn), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Open Claude", action: #selector(openClaude), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Usage Page", action: #selector(openUsagePage), keyEquivalent: "u"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Logs", action: #selector(openLogs), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Send Feedback…", action: #selector(sendFeedback), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        return menu
    }

    @objc private func signIn() {
        actions.signIn()
    }

    @objc private func refresh() {
        actions.refresh()
    }

    @objc private func openClaude() {
        actions.openClaude()
    }

    @objc private func openUsagePage() {
        actions.openUsagePage()
    }

    @objc private func openLogs() {
        actions.openLogs()
    }

    @objc private func openPreferences() {
        actions.openPreferences()
    }

    /// Always one click away — the permanent half of the feedback ask.
    @objc private func sendFeedback() {
        NSWorkspace.shared.open(AppLinks.feedback)
    }

    @objc private func quit() {
        actions.quit()
    }
}
