import Combine
import Foundation
import ServiceManagement

public enum PillScreenMode: String, CaseIterable, Identifiable, Sendable {
    case builtIn, activeScreen, underMouse, specific
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .builtIn: return "Built-in display"
        case .activeScreen: return "Active screen"
        case .underMouse: return "Screen under mouse"
        case .specific: return "Specific display"
        }
    }
}

@MainActor
public final class SettingsManager: ObservableObject {
    @Published public var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published public var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: Keys.animationsEnabled) }
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published public var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    @Published public var appearanceOverride: AppearanceOverride {
        didSet { defaults.set(appearanceOverride.rawValue, forKey: Keys.appearanceOverride) }
    }

    @Published public var colorPalette: UsageColorPalette {
        didSet { savePalette() }
    }
    @Published public var pillScreenMode: PillScreenMode {
        didSet { defaults.set(pillScreenMode.rawValue, forKey: Keys.pillScreenMode) }
    }
    @Published public var pillDisplayID: Int {
        didSet { defaults.set(pillDisplayID, forKey: Keys.pillDisplayID) }
    }
    private let defaults: UserDefaults
    private let logger: AppLogger?

    public init(defaults: UserDefaults = .standard, logger: AppLogger? = nil) {
        self.defaults = defaults
        self.logger = logger

        let savedInterval = defaults.double(forKey: Keys.refreshInterval)
        self.refreshInterval = savedInterval > 0 ? max(60, savedInterval) : 300
        self.animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.showMenuBarIcon = defaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true

        let savedAppearance = defaults.string(forKey: Keys.appearanceOverride)
        self.appearanceOverride = savedAppearance
            .flatMap(AppearanceOverride.init(rawValue:)) ?? .system

        if let data = defaults.data(forKey: Keys.colorPalette),
           let palette = try? JSONDecoder().decode(UsageColorPalette.self, from: data) {
            self.colorPalette = palette
        } else {
            self.colorPalette = UsageColorPalette()
        }
        let savedMode = defaults.string(forKey: Keys.pillScreenMode)
        self.pillScreenMode = savedMode.flatMap(PillScreenMode.init(rawValue:)) ?? .builtIn
        self.pillDisplayID = defaults.integer(forKey: Keys.pillDisplayID)
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            logger?.error("Unable to update launch at login: \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    public func resetPalette() {
        colorPalette = UsageColorPalette()
    }

    private func savePalette() {
        guard let data = try? JSONEncoder().encode(colorPalette) else {
            return
        }
        defaults.set(data, forKey: Keys.colorPalette)
    }

    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let animationsEnabled = "animationsEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let appearanceOverride = "appearanceOverride"
        static let colorPalette = "colorPalette"
        static let pillScreenMode = "pillScreenMode"
        static let pillDisplayID = "pillDisplayID"
    }
}
