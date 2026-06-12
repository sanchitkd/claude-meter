import Foundation
import WebKit
import AppKit

@MainActor
public final class ClaudeWebSession: NSObject {
    public enum WebSessionError: Error { case notLoggedIn, badResponse, noOrg }

    private let webView: WKWebView
    private let logger: AppLogger?
    private var loadCont: CheckedContinuation<Void, Error>?
    private var navToken: UUID?
    private var cachedOrgID: String?
    private var baseLoaded = false

    public init(logger: AppLogger? = nil) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.logger = logger
        super.init()
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
    }

    // Navigate to an HTML page (never a raw JSON endpoint). Guarded + timed out.
    private func navigate(to url: URL) async throws {
        if let pending = loadCont { loadCont = nil; pending.resume(throwing: WebSessionError.badResponse) }
        let token = UUID(); navToken = token
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            loadCont = c
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                guard let self, self.navToken == token, let pending = self.loadCont else { return }
                self.loadCont = nil
                pending.resume()   // proceed; DOM is usually ready enough to fetch
            }
        }
    }

    private func ensureBase() async throws {
        if baseLoaded, webView.url?.host?.contains("claude.ai") == true { return }
        try await navigate(to: URL(string: "https://claude.ai/new")!)
        baseLoaded = true
    }

    // Same-origin fetch from inside the loaded claude.ai page (cookies auto-sent).
    private func jsonGET(_ path: String) async throws -> String {
        try await ensureBase()
        let js = """
        const res = await fetch(path, { credentials: 'include', headers: { 'accept': 'application/json' } });
        return await res.text();
        """
        let r = try await webView.callAsyncJavaScript(js, arguments: ["path": path], in: nil, contentWorld: .page)
        return (r as? String) ?? ""
    }

    public func isLoggedIn() async -> Bool {
        do { _ = try await organizationID(); return true } catch { return false }
    }

    public func fetchUsage() async throws -> AnthropicUsageDTO {
        let org = try await organizationID()
        let text = try await jsonGET("/api/organizations/\(org)/usage")
        guard let data = text.data(using: .utf8),
              let dto = try? JSONDecoder().decode(AnthropicUsageDTO.self, from: data) else {
            throw classify(text)
        }
        return dto
    }

    private func organizationID() async throws -> String {
        if let cachedOrgID { return cachedOrgID }
        let text = try await jsonGET("/api/organizations")
        guard let data = text.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !arr.isEmpty else {
            throw classify(text)
        }
        guard let uuid = arr.compactMap({ $0["uuid"] as? String }).first else { throw WebSessionError.noOrg }
        cachedOrgID = uuid
        return uuid
    }

    private func classify(_ text: String) -> WebSessionError {
        let t = text.lowercased()
        if t.isEmpty || t.contains("unauthorized") || t.contains("authentication")
            || t.contains("\"type\":\"error\"") || t.contains("log in") {
            return .notLoggedIn
        }
        return .badResponse
    }

    public func resetSession() { baseLoaded = false; cachedOrgID = nil }
}

extension ClaudeWebSession: WKNavigationDelegate {
    public func webView(_ w: WKWebView, didFinish n: WKNavigation!) { loadCont?.resume(); loadCont = nil }
    public func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { loadCont?.resume(throwing: e); loadCont = nil }
    public func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { loadCont?.resume(throwing: e); loadCont = nil }
}
