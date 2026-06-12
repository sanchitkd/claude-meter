import Foundation

public enum UsageProviderKind: String, CaseIterable, Codable, Identifiable {
    case claude
    case openAI
    case gemini
    case cursor
    case localGPU
    case system

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude:
            "Claude Code"
        case .openAI:
            "OpenAI"
        case .gemini:
            "Gemini"
        case .cursor:
            "Cursor"
        case .localGPU:
            "Local GPU"
        case .system:
            "System"
        }
    }
}
