import AppKit
import Foundation

@MainActor
public final class UpdateChecker {
    private let repo = "sanchitkd/claude-meter"
    private let logger: AppLogger?
    private let defaults = UserDefaults.standard
    private let lastNotifiedKey = "lastNotifiedUpdateVersion"

    public init(logger: AppLogger? = nil) { self.logger = logger }
    public func checkInBackground() { Task { await check() } }

    private func check() async {
        guard let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        do {
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard isNewer(latest, than: current),
                  defaults.string(forKey: lastNotifiedKey) != latest else { return }
            let page = (obj["html_url"] as? String).flatMap(URL.init(string:))
            present(latest: latest, page: page)
            defaults.set(latest, forKey: lastNotifiedKey)
        } catch { logger?.info("Update check skipped: \(error.localizedDescription)") }
    }

    private func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private func present(latest: String, page: URL?) {
        let alert = NSAlert()
        alert.messageText = "Claude Meter \(latest) is available"
        alert.informativeText = "You're on an older version. Download the latest from GitHub."
        alert.addButton(withTitle: "Download"); alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let page { NSWorkspace.shared.open(page) }
    }
}
