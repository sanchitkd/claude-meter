import Foundation

/// Every outbound URL the app can open, in one place.
public enum AppLinks {
    /// Opens the feedback modal directly — the plain #feedback anchor only scrolls to the section.
    public static let feedback = URL(string: "https://claude.sanchitkd.com/#send-feedback")!
    public static let site = URL(string: "https://claude.sanchitkd.com/")!
    /// Update check. Sends the app version and an anonymous random install ID — nothing else.
    public static let ping = "https://claude.sanchitkd.com/ping"
}
