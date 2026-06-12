import Foundation

/// Decodes the claude.ai usage endpoint:
/// GET https://claude.ai/api/organizations/{org}/usage
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
    public let fiveHour: Window?
    public let sevenDay: Window?
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
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
        let session = UsageWindow(
            label: "Current Session",
            usagePercentage: dto.fiveHour?.utilization,
            resetDate: dto.fiveHour?.resetDate,
            resetDescription: dto.fiveHour?.resetsAtRaw
        )
        let weekly = UsageWindow(
            label: "Weekly",
            usagePercentage: dto.sevenDay?.utilization,
            resetDate: dto.sevenDay?.resetDate,
            resetDescription: dto.sevenDay?.resetsAtRaw
        )
        let haveAny = (dto.fiveHour?.utilization != nil) || (dto.sevenDay?.utilization != nil)
        let status: UsageStatus = !haveAny
            ? .unavailable("No usage data returned.")
            : (dto.fiveHour?.utilization == nil || dto.sevenDay?.utilization == nil)
                ? .partial("Some usage fields were unavailable.")
                : .available
        return UsageSnapshot(
            provider: .claude,
            capturedAt: capturedAt,
            session: session,
            weekly: weekly,
            planName: planName,
            status: status,
            sourceDescription: sourceDescription
        )
    }
}