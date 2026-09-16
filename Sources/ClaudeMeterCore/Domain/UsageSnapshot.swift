import Foundation

/// What the pill's weekly figure means. Lives in Domain, not alongside the other settings
/// enums in `SettingsManager`, because the snapshot's own resolver needs it — Domain reaching
/// up into State would be backwards, and `PillScreenMode` next door is pure presentation
/// whereas this one changes which number is being read.
public enum PillWeeklyMode: String, CaseIterable, Identifiable, Sendable {
    /// The all-models weekly cap. What v1.0.0–v1.2.0 have always shown.
    case allModels
    /// Whichever weekly cap is nearest its limit — the all-models row included.
    case closest

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .allModels: return "All models"
        case .closest: return "Closest to limit"
        }
    }

    public var explanation: String {
        switch self {
        case .allModels:
            return "W is your combined weekly cap. A single model can be at 100% while this still reads green."
        case .closest:
            return "W is whichever weekly cap is nearest its limit. A model-scoped cap adds its initial, e.g. W·F."
        }
    }
}

/// The weekly figure as it should be rendered, resolved once so the pill, the card title, the
/// accessibility label and the countdown cannot disagree with each other.
public struct WeeklyReading: Equatable, Sendable {
    public var percent: Double?
    /// Single letter beside "W" on the pill. nil when the all-models cap is the one being shown.
    public var marker: String?
    /// Model name for the card title. nil when the all-models cap is the one being shown.
    public var driver: String?
    public var resetDate: Date?

    public init(percent: Double?, marker: String? = nil, driver: String? = nil, resetDate: Date? = nil) {
        self.percent = percent
        self.marker = marker
        self.driver = driver
        self.resetDate = resetDate
    }
}

public struct UsageSnapshot: Equatable {
    public var provider: UsageProviderKind
    public var capturedAt: Date
    public var session: UsageWindow?
    public var weekly: UsageWindow?
    /// Every row claude.ai reported. Empty on accounts that don't return `limits[]`.
    public var limits: [UsageLimit]
    /// The model driving the weekly number, when it isn't the all-models cap (e.g. "Fable").
    /// nil means the all-models cap is the one binding you.
    ///
    /// HISTORY: hardcoded nil in `AnthropicUsageMapper` from v1.2.0 until 2026-09-15, which left
    /// this field, `weeklyMarker`, the pill's "W·F" marker and the card's "Weekly · Fable" title
    /// all unreachable — four rendered paths that the handover described as unbuilt while they
    /// sat in the tree. The mapper now populates it.
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

    /// The weekly cap nearest its limit, all-models row included. `weeklyLimits` is already
    /// sorted worst-first, so this is just its head — there is no second sort and no second
    /// definition of "worst" to drift from the chips' own ordering.
    public var weeklyBinding: UsageLimit? { weeklyLimits.first }

    /// Resolve the weekly figure for a given preference. Presentation decides here, NOT the
    /// provider: threading the mode into `AnthropicUsageMapper` would mean routing settings
    /// through `AnthropicUsageProvider` and `ClaudeWebSession`, and would make the stored
    /// snapshot mean different things depending on a checkbox. The snapshot carries the truth;
    /// this picks which part of it to show.
    public func weeklyReading(mode: PillWeeklyMode) -> WeeklyReading {
        let allModels = WeeklyReading(
            percent: weekly?.usagePercentage,
            resetDate: weekly?.resetDate
        )

        guard mode == .closest, let binding = weeklyBinding else { return allModels }

        // `marker` and `driver` are nil for an unscoped row, which is exactly right: when the
        // all-models cap IS the worst, .closest renders identically to .allModels. That is the
        // honest result, not a missing feature.
        return WeeklyReading(
            percent: binding.percent,
            marker: binding.marker,
            driver: binding.modelName,
            resetDate: binding.resetDate ?? weekly?.resetDate
        )
    }

    /// Letter shown beside "W" on the pill when a model cap — not the all-models cap — is
    /// the thing about to stop you.
    @available(*, deprecated, message: "Use weeklyReading(mode:).marker — this ignores the user's PillWeeklyMode.")
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
