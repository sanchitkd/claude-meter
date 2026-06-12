# Future Extensibility

Claude Meter normalizes every source into a `UsageSnapshot` behind the `UsageProvider` protocol, so new sources can be added without touching the UI. Add one by implementing `UsageProvider` and registering it with `ProviderRegistry`.

`UsageProviderKind` already reserves IDs for likely future sources:

- `openAI`
- `gemini`
- `cursor`
- `localGPU`
- `system`

## Possible future providers

**OpenAI / Gemini / Cursor** — each would read its own authenticated usage surface: an official usage API where one exists, or an authenticated web session in the same spirit as the Claude provider, but only where permitted by that service's terms.

**Local AI / GPU** — `powermetrics`, Metal Performance HUD, or vendor tools; may require a helper process or elevated permissions.

**CPU / RAM** — `host_statistics` / `ProcessInfo`, no external commands required.

Each new provider should ship: provider metadata, a `fetchUsage()` implementation, and (optionally) its own settings view. Keep provider-specific models out of the UI — always map into `UsageSnapshot`.
