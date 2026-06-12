# Architecture

Claude Meter is a Swift Package with two targets:

- `ClaudeMeter` — the `@main` app entry point (accessory app, no Dock icon).
- `ClaudeMeterCore` — all logic and UI, so it can be reasoned about independently of the app shell.

## Data source

Claude exposes no public usage API. Claude Meter reads the same endpoint the claude.ai web app uses:

```
GET https://claude.ai/api/organizations/{org}/usage
```

This endpoint is Cloudflare-protected and authenticated by the browser session cookie (`sessionKey`), so a plain `URLSession` can't reach it. Instead, `ClaudeWebSession` hosts a hidden `WKWebView` that:

1. Loads `claude.ai` once (carrying the user's logged-in cookies from the app's local WebKit store).
2. Resolves the organization id via `GET /api/organizations` (a same-origin `fetch` from inside the loaded page).
3. Fetches `/api/organizations/{org}/usage` and decodes it.

Response shape:

```json
{
  "five_hour": { "utilization": 67.0, "resets_at": "2026-06-11T21:00:00.4259+00:00" },
  "seven_day": { "utilization": 5.0,  "resets_at": "..." }
}
```

`five_hour` is the current session window; `seven_day` is the weekly window. `AnthropicUsageModels` decodes this (with tolerant ISO-8601 parsing for the microsecond timestamps) and maps it into a provider-neutral `UsageSnapshot`.

Sign-in is handled by `ClaudeLoginWindowController`, which shows a real claude.ai login window and watches the cookie store for `sessionKey`. (Google SSO is unavailable inside embedded webviews by Google's policy, so email sign-in is used.)

> This depends on an undocumented endpoint plus the user's web session, so it can break if Anthropic changes things. It is a personal-use convenience tool, not an official integration.

## Runtime flow

1. `ClaudeIslandAppDelegate` wires up the logger, settings, web session, provider, registry, state manager, panel, menu-bar controller, and appearance controller.
2. On launch it checks `ClaudeWebSession.isLoggedIn()`; if not signed in, it opens the sign-in window.
3. `UsageStateManager` runs a refresh timer (configurable interval) plus a 1-second clock for live countdowns, and publishes the current `UsageSnapshot`.
4. `AnthropicUsageProvider` calls `ClaudeWebSession.fetchUsage()` and maps the result.
5. `IslandView` observes the state manager and renders either the collapsed pill or the hover card.
6. `IslandPanelController` hosts the SwiftUI view in a transparent, always-on-top `NSPanel`, placed beside the notch on the chosen display.

## Layers

- **Providers** — data acquisition. `AnthropicUsageProvider` + `ClaudeWebSession`. The `UsageProvider` protocol keeps the source swappable.
- **Domain** — provider-neutral models: `UsageSnapshot`, `UsageWindow`, `UsageStatus`, `UsageColorPalette`.
- **State** — `UsageStateManager` (refresh cadence, snapshot, clock, failures) and `SettingsManager` (persisted preferences).
- **UI** — `IslandView` (pill + card), `UsageColorResolver` (usage -> color + auto contrast text), `SettingsView`.
- **Platform** — `IslandPanelController` (panel + multi-display placement), `AppearanceController`, `SettingsWindowController`.
- **Utilities** — `AppLogger`, `UsageFormatters`.

## Extending with new providers

Implement `UsageProvider` and register it with `ProviderRegistry`. Normalize output into `UsageSnapshot` so the UI stays provider-agnostic. See `FUTURE_EXTENSIBILITY.md`.
