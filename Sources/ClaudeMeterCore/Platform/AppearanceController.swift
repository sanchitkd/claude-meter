import AppKit
import Combine

@MainActor
public final class AppearanceController {
    private let settings: SettingsManager
    private var cancellables: Set<AnyCancellable> = []

    public init(settings: SettingsManager) {
        self.settings = settings

        settings.$appearanceOverride
            .sink { appearance in
                Task { @MainActor in
                    Self.apply(appearance)
                }
            }
            .store(in: &cancellables)
    }

    private static func apply(_ appearance: AppearanceOverride) {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
}
