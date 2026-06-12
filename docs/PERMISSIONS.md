# Permissions

Claude Meter needs **no special macOS permissions** — no Accessibility, Screen Recording, Input Monitoring, or Full Disk Access.

## What it uses

- **Network (WebKit):** loads `claude.ai` in a hidden `WKWebView` and calls the authenticated usage endpoint. This is the only network destination.
- **Local cookie storage:** your claude.ai session cookie lives in the app's local WebKit data store on your Mac. It is never transmitted anywhere except to `claude.ai`.
- **Logs:** writes to `~/Library/Application Support/ClaudeMeter/ClaudeMeter.log`.
- **Open URLs:** opens links (Claude, the usage page, feedback) in your default browser.
- **Launch at login (optional):** uses `SMAppService.mainApp`, which works from a proper `.app` bundle.

## Not used

No CLI execution, no reading other apps' data, no filesystem access beyond its own Application Support folder and log file.

## Sandboxing & signing

The SwiftPM build is not App Sandbox-enabled, and the distributed app is unsigned — so macOS Gatekeeper requires a right-click -> Open on first launch. If you later sign and sandbox it, the only entitlement required is outgoing network access (for WebKit).
