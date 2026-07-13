import Foundation

public struct UsageSnapshot: Equatable {
    public var provider: UsageProviderKind
    public var capturedAt: Date
    public var session: UsageWindow?
    public var weekly: UsageWindow?
    /// Every row claude.ai reported. Empty on accounts that don't return `limits[]`.
    public var limits: [UsageLimit]
    /// The model driving the weekly number, when it isn't the all-models cap (e.g. "Fable").
    /// nil means the all-models cap is the one binding you.
    public var weeklyDriver: String?
    public var planName: String?
    public var status: UsageStatus
    public var sourceDescription: String
    public var rawOutputPreview: String?

    public init(
        provider: UsageProviderKind,
        capturedAt: Date,
        session: UsageWindow? = nil,
        weekly: UsageWindow? = nil,
        limits: [UsageLimit] = [],
        weeklyDriver: String? = nil,
        planName: String? = nil,
        status: UsageStatus = .available,
        sourceDescription: String,
        rawOutputPreview: String? = nil
    ) {
        self.provider = provider
        self.capturedAt = capturedAt
        self.session = session
        self.weekly = weekly
        self.limits = limits
        self.weeklyDriver = weeklyDriver
        self.planName = planName
        self.status = status
        self.sourceDescription = sourceDescription
        self.rawOutputPreview = rawOutputPreview
    }

    /// Every weekly cap, worst first — what the hover card lists.
    public var weeklyLimits: [UsageLimit] {
        limits.filter { $0.group == .weekly }.sorted { $0.percent > $1.percent }
    }

    /// Letter shown beside "W" on the pill when a model cap — not the all-models cap — is
    /// the thing about to stop you.
    public var weeklyMarker: String? {
        guard let weeklyDriver, let first = weeklyDriver.first else { return nil }
        return String(first).uppercased()
    }

    public static func unavailable(
        provider: UsageProviderKind = .claude,
        message: String,
        capturedAt: Date = Date(),
        sourceDescription: String = "No usage source"
    ) -> UsageSnapshot {
        UsageSnapshot(
            provider: provider,
            capturedAt: capturedAt,
            status: .unavailable(message),
            sourceDescription: sourceDescription
        )
    }
}
