import AppKit
import WebKit

@MainActor
public final class ClaudeLoginWindowController: NSObject, WKNavigationDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var onDone: (() -> Void)?
    private var pollTimer: Timer?

    public override init() { super.init() }

    public func show(onDone: @escaping () -> Void) {
        if let window {                       // already open → focus it
            self.onDone = onDone
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        self.onDone = onDone

        let frame = NSRect(x: 0, y: 0, width: 460, height: 720)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: frame, configuration: config)
        wv.navigationDelegate = self
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        self.webView = wv

        let win = NSWindow(contentRect: frame,
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "Sign in to Claude — use Email (Google isn’t supported in apps)"
        win.isReleasedWhenClosed = false
        win.contentView = wv
        win.center()
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        wv.load(URLRequest(url: URL(string: "https://claude.ai/login")!))

        let t = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkAuth() }
        }
        t.tolerance = 0.5
        self.pollTimer = t
    }

    private func checkAuth() {
        guard let store = webView?.configuration.websiteDataStore.httpCookieStore else { return }
        store.getAllCookies { [weak self] cookies in
            let ok = cookies.contains { $0.name == "sessionKey" && !$0.value.isEmpty }
            guard ok else { return }
            Task { @MainActor in self?.finish() }
        }
    }

    private func finish() {
        pollTimer?.invalidate(); pollTimer = nil
        let w = window; let cb = onDone
        window = nil; webView = nil; onDone = nil
        DispatchQueue.main.async { w?.close(); cb?() }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { checkAuth() }
}
