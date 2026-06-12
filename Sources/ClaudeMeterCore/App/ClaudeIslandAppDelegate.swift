import AppKit

@MainActor
public final class ClaudeIslandAppDelegate: NSObject, NSApplicationDelegate {
    private var logger: AppLogger?
    private var settings: SettingsManager?
    private var stateManager: UsageStateManager?
    private var actions: AppActions?
    private var panelController: IslandPanelController?
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var appearanceController: AppearanceController?
    private var webSession: ClaudeWebSession?
    private var loginController: ClaudeLoginWindowController?
    private var updateChecker: UpdateChecker?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let logger = AppLogger()
        let settings = SettingsManager(logger: logger)
        let webSession = ClaudeWebSession(logger: logger)
        let claudeProvider = AnthropicUsageProvider(session: webSession, logger: logger)
        self.webSession = webSession
        let registry = ProviderRegistry(providers: [claudeProvider])
        let stateManager = UsageStateManager(
            providerRegistry: registry,
            settings: settings,
            logger: logger
        )
        let actions = AppActions(
            stateManager: stateManager,
            settings: settings,
            logger: logger
        )
        let settingsWindowController = SettingsWindowController(settings: settings, logger: logger, onQuit: { [weak actions] in actions?.quit() })
        actions.setPreferencesHandler { [weak settingsWindowController] in
            settingsWindowController?.show()
        }

        let islandView = IslandView(
            stateManager: stateManager,
            settings: settings,
            actions: actions
        )
        let panelController = IslandPanelController(rootView: islandView, settings: settings)
        let menuBarController = MenuBarController(settings: settings, actions: actions)
        let appearanceController = AppearanceController(settings: settings)

        self.logger = logger
        self.settings = settings
        self.stateManager = stateManager
        self.actions = actions
        self.settingsWindowController = settingsWindowController
        self.panelController = panelController
        self.menuBarController = menuBarController
        self.appearanceController = appearanceController

        panelController.show()
        logger.info("Claude Meter launched.")
        let updateChecker = UpdateChecker(logger: logger)
        self.updateChecker = updateChecker
        updateChecker.checkInBackground()

        let loginController = ClaudeLoginWindowController()
        self.loginController = loginController

        actions.setSignInHandler { [weak loginController, weak actions, weak self] in
            loginController?.show {
                actions?.refresh()
                self?.panelController?.show()
            }
        }

        Task { @MainActor in
            if await webSession.isLoggedIn() == false {
                actions.signIn()
            } else {
                actions.refresh()
            }
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
