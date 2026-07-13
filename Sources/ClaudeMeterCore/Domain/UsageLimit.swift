import Foundation

/// One row of claude.ai's `limits[]` array.
///
/// This is the canonical shape now: Anthropic moved per-model weekly caps out of the flat
/// `seven_day_opus` / `seven_day_sonnet` / `seven_day_cowork` keys (and the codename keys —
/// `tangelo`, `nimbus_quill`, `amber_ladder`, `cinder_cove`, `iguana_necktie`) into this array.
/// Those flat keys are null husks; never decode them.
public struct UsageLimit: Equatable, Identifiable, Sendable {
    public enum Group: String, Sendable {
        case session
        case weekly
        case other
    }

    /// Anthropic's own signal for how bad it is — we render it, we don't second-guess it.
    public enum Severity: String, Sendable {
        case normal
        case warning
        case critical
        case unknown
    }

    public var kind: String          // "session" | "weekly_all" | "weekly_scoped"
    public var group: Group
    public var percent: Double
    public var severity: Severity
    public var resetDate: Date?
    public var modelName: String?    // scope.model.display_name — e.g. "Fable". nil = all models.
    public var isActive: Bool

    public var id: String { "\(kind)|\(modelName ?? "all")" }

    public init(
        kind: String,
        group: Group,
        percent: Double,
        severity: Severity = .normal,
        resetDate: Date? = nil,
        modelName: String? = nil,
        isActive: Bool = false
    ) {
        self.kind = kind
        self.group = group
        self.percent = percent
        self.severity = severity
        self.resetDate = resetDate
        self.modelName = modelName
        self.isActive = isActive
    }

    /// "Fable" for a model-scoped cap; otherwise "All models" / "Session".
    public var displayName: String {
        if let modelName, !modelName.isEmpty { return modelName }
        switch group {
        case .session: return "Session"
        case .weekly: return "All models"
        case .other: return kind
        }
    }

    /// Single-letter marker for the collapsed pill. nil when the cap isn't model-scoped.
    public var marker: String? {
        guard let modelName, let first = modelName.first else { return nil }
        return String(first).uppercased()
    }
}
