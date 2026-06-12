import Foundation

public struct UsageSnapshot: Equatable {
    public var provider: UsageProviderKind
    public var capturedAt: Date
    public var session: UsageWindow?
    public var weekly: UsageWindow?
    public var planName: String?
    public var status: UsageStatus
    public var sourceDescription: String
    public var rawOutputPreview: String?

    public init(
        provider: UsageProviderKind,
        capturedAt: Date,
        session: UsageWindow? = nil,
        weekly: UsageWindow? = nil,
        planName: String? = nil,
        status: UsageStatus = .available,
        sourceDescription: String,
        rawOutputPreview: String? = nil
    ) {
        self.provider = provider
        self.capturedAt = capturedAt
        self.session = session
        self.weekly = weekly
        self.planName = planName
        self.status = status
        self.sourceDescription = sourceDescription
        self.rawOutputPreview = rawOutputPreview
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
