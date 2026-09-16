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

    /// Bare clock time. SUPERSEDED for "Last Refresh" by `lastRefreshString(_:now:)` — a bare
    /// `19:21` from yesterday reads as today at a glance, which is misleading rather than terse.
    /// Deprecated on purpose: the warning is how a second call site announces itself, instead of
    /// this sitting here as a hook nobody can tell is dead (§10.2, the `tulipOpenAuth` trap).
    @available(*, deprecated, message: "Use lastRefreshString(_:now:) — a bare clock time cannot say which day it belongs to.")
    public static func timestampString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    /// Age-aware "Last Refresh". Degrades by distance so the string can never claim a day it
    /// does not mean:
    ///
    ///   just now  →  7 min ago  →  19:21 (same day)  →  Yesterday 19:21  →  Mon 19:21  →  22 Jul 19:21
    ///
    /// `now` is a PARAMETER, not `Date()` read inside. `UsageStateManager` republishes `now`
    /// every second, so the view re-renders and "just now" ages into "7 min ago" with no extra
    /// timer, no `TimelineView`, and nothing to invalidate.
    ///
    /// The minute branch deliberately sits ABOVE the calendar branches: at 00:20 a refresh from
    /// 23:50 is "30 min ago", which is both true and more useful than "Yesterday 23:50".
    public static func lastRefreshString(
        _ date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let age = now.timeIntervalSince(date)

        // Clock skew or a snapshot stamped in the future: fall back to the plain time rather
        // than render a negative age, which would read as a bug in the app rather than in the clock.
        if age < 0 { return clockOnly.string(from: date) }

        if age < 45 { return "just now" }
        if age < 3_600 { return "\(Int(age / 60)) min ago" }

        if calendar.isDateInToday(date) { return clockOnly.string(from: date) }
        if calendar.isDateInYesterday(date) { return "Yesterday " + clockOnly.string(from: date) }

        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)
        let dayGap = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? Int.max
        if dayGap < 7 { return weekdayAndTime.string(from: date) }

        return dateAndTime.string(from: date)
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

    // Cached, because "Last Refresh" re-renders on every one-second tick of the expanded card and
    // a fresh DateFormatter per tick is pure waste. `setLocalizedDateFormatFromTemplate` keeps
    // 12h/24h and field order correct per locale — a hardcoded "HH:mm" would be wrong for half
    // the world. Trade-off accepted: a locale changed while the app is running is not picked up
    // until relaunch.
    private static let clockOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let weekdayAndTime: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE jm")
        return f
    }()

    private static let dateAndTime: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM jm")
        return f
    }()
}
