import Foundation

public enum UsageStatus: Equatable {
    case available
    case partial(String)
    case unavailable(String)

    public var message: String? {
        switch self {
        case .available:
            nil
        case let .partial(message), let .unavailable(message):
            message
        }
    }

    public var isUnavailable: Bool {
        if case .unavailable = self {
            return true
        }
        return false
    }
}
