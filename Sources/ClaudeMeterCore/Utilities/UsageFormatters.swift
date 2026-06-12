import Foundation

public enum UsageFormatters {
    public static func percentageString(_ value: Double?) -> String {
        guard let value else {
            return "Unavailable"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let number = NSNumber(value: max(0, min(100, value)))
        return "\(formatter.string(from: number) ?? "\(Int(value))")%"
    }

    public static func timestampString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    public static func countdownString(until resetDate: Date?, fallback: String?, now: Date) -> String {
        guard let resetDate else {
            return fallback?.isEmpty == false ? fallback! : "Unavailable"
        }

        let remaining = Int(resetDate.timeIntervalSince(now).rounded())
        guard remaining > 0 else {
            return "Now"
        }

        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}
