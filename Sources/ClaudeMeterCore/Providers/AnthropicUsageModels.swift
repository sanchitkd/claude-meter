import Foundation

/// Decodes the claude.ai usage endpoint:
/// GET https://claude.ai/api/organizations/{org}/usage
///
/// `limits[]` is the canonical shape. `five_hour` / `seven_day` are kept only as a fallback
/// for accounts that don't return the array — every field decodes optionally, because the
/// payload varies by plan and Anthropic changes it without notice.
public struct AnthropicUsageDTO: Decodable, Sendable {
    public struct Window: Decodable, Sendable {
        public let utilization: Double?
        public let resetsAtRaw: String?
        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAtRaw = "resets_at"
        }
        public var resetDate: Date? {
            AnthropicUsageDTO.parseISO(resetsAtRaw)
        }
    }

    public struct Model: Decodable, Sendable {
        public let displayName: String?
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    public struct Scope: Decodable, Sendable {
        public let model: Model?
    }

    public struct Limit: Decodable, Sendable {
        public let kind: String?
        public let group: String?
        public let percent: Double?
        public let severity: String?
        public let resetsAtRaw: String?
        public let scope: Scope?
        public let isActive: Bool?
        enum CodingKeys: String, CodingKey {
            case kind, group, percent, severity, scope
            case resetsAtRaw = "resets_at"
            case isActive = "is_active"
        }
        public var resetDate: Date? {
            AnthropicUsageDTO.parseISO(resetsAtRaw)
        }
    }

    public let fiveHour: Window?
    public let sevenDay: Window?
    public let limits: [Limit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case limits
    }

    /// Tolerant ISO-8601 parse (handles 6-digit microseconds + "+00:00").
    static func parseISO(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        // Truncate fractional seconds to milliseconds, retry.
        if let dot = s.firstIndex(of: ".") {
            let tzStart = s[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) ?? s.endIndex
            let frac = s[s.index(after: dot)..<tzStart]
            if frac.count > 3 {
                let trimmed = String(s[..<s.index(after: dot)]) + frac.prefix(3) + String(s[tzStart...])
                if let d = f1.date(from: trimmed) { return d }
            }
        }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }
}

public enum AnthropicUsageMapper {
    public static func snapshot(
        from dto: AnthropicUsageDTO,
        planName: String?,
        capturedAt: Date,
        sourceDescription: String
    ) -> UsageSnapshot {
        let rows: [UsageLimit] = (dto.limits ?? []).compactMap(map(_:))

        let sessionRow = rows.first { $0.group == .session }
        let weeklyRows = rows.filter { $0.group == .weekly }

        // The whole point of the app: report the limit that will actually stop you.
        // With all-models at 53% and Fable at 100%, the honest weekly number is 100%.
        let binding = weeklyRows.max { $0.percent < $1.percent }

        let sessionPct = sessionRow?.percent ?? dto.fiveHour?.utilization
        let sessionReset = sessionRow?.resetDate ?? dto.fiveHour?.resetDate

        let weeklyPct = binding?.percent ?? dto.sevenDay?.utilization
        let weeklyReset = binding?.resetDate ?? dto.sevenDay?.resetDate

        let session = UsageWindow(
            label: "Current Session",
            usagePercentage: sessionPct,
            resetDate: sessionReset,
            resetDescription: dto.fiveHour?.resetsAtRaw
        )
        let weekly = UsageWindow(
            label: "Weekly",
            usagePercentage: weeklyPct,
            resetDate: weeklyReset,
            resetDescription: dto.sevenDay?.resetsAtRaw,
            limitDescription: binding?.displayName
        )

        let haveAny = (sessionPct != nil) || (weeklyPct != nil)
        let status: UsageStatus = !haveAny
            ? .unavailable("No usage data returned.")
            : (sessionPct == nil || weeklyPct == nil)
                ? .partial("Some usage fields were unavailable.")
                : .available

        return UsageSnapshot(
            provider: .claude,
            capturedAt: capturedAt,
            session: session,
            weekly: weekly,
            limits: rows,
            weeklyDriver: binding?.modelName,   // nil when the all-models cap is the binding one
            planName: planName,
            status: status,
            sourceDescription: sourceDescription
        )
    }

    private static func map(_ limit: AnthropicUsageDTO.Limit) -> UsageLimit? {
        guard let percent = limit.percent else { return nil }

        let group: UsageLimit.Group
        switch (limit.group ?? "").lowercased() {
        case "session": group = .session
        case "weekly": group = .weekly
        default: group = .other
        }

        let severity = UsageLimit.Severity(rawValue: (limit.severity ?? "").lowercased()) ?? .unknown
        let model = limit.scope?.model?.displayName
        let modelName = (model?.isEmpty == false) ? model : nil

        return UsageLimit(
            kind: limit.kind ?? "unknown",
            group: group,
            percent: percent,
            severity: severity,
            resetDate: limit.resetDate,
            modelName: modelName,
            isActive: limit.isActive ?? false
        )
    }
}
