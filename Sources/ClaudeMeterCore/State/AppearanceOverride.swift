import Foundation

public enum AppearanceOverride: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            "System"
        case .dark:
            "Dark"
        case .light:
            "Light"
        }
    }
}
