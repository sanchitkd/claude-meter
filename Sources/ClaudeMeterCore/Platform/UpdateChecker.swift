import AppKit
import Foundation

@MainActor
public final class UpdateChecker {
    private let logger: AppLogger?
    private let defaults = UserDefaults.standard
    private let lastNotifiedKey = "lastNotifiedUpdateVersion"
    private let installIDKey = "anonymousInstallID"

    public init(logger: AppLogger? = nil) { self.logger = logger }
    public func checkInBackground() { Task { await check() } }

    /// A random UUID, generated once and stored only on this Mac. It is not derived from you,
    /// your account or your hardware — it exists so the update endpoint can count how many
    /// installs are still *running* (COUNT DISTINCT) rather than how many times apps launched.
    /// Disclosed in the README and in the site's privacy list.
    private var installID: String {
        if let existing = defaults.string(forKey: installIDKey) { return existing }
        let fresh = UUID().uuidString.lowercased()
        defaults.set(fresh, forKey: installIDKey)
        return fresh
    }

    private struct PingResponse: Decodable {
        let latest: String?
        let url: String?
    }

    private func check() async {
        guard let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }

        var components = URLComponents(string: AppLinks.ping)
        components?.queryItems = [
            URLQueryItem(name: "v", value: current),
            URLQueryItem(name: "id", value: installID),
        ]
        guard let url = components?.url else { return }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)

            let body = try JSONDecoder().decode(PingResponse.self, from: data)
            guard let tag = body.latest, !tag.isEmpty else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

            guard isNewer(latest, than: current),
                  defaults.string(forKey: lastNotifiedKey) != latest else { return }

            present(latest: latest, page: body.url.flatMap(URL.init(string:)))
            defaults.set(latest, forKey: lastNotifiedKey)
        } catch {
            // Never bother the user because an update check failed.
            logger?.info("Update check skipped: \(error.localizedDescription)")
        }
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
