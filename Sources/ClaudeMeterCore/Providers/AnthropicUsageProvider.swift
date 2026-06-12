import Foundation

public final class AnthropicUsageProvider: UsageProvider, @unchecked Sendable {
    public let kind: UsageProviderKind = .claude
    public let displayName = "Claude Code"

    private let session: ClaudeWebSession
    private let logger: AppLogger

    public init(session: ClaudeWebSession, logger: AppLogger) {
        self.session = session
        self.logger = logger
    }

    public func fetchUsage() async -> UsageSnapshot {
        let capturedAt = Date()
        do {
            let dto = try await session.fetchUsage()
            return AnthropicUsageMapper.snapshot(
                from: dto, planName: "Claude Pro",
                capturedAt: capturedAt, sourceDescription: "claude.ai/usage"
            )
        } catch ClaudeWebSession.WebSessionError.notLoggedIn {
            logger.warning("Claude web session not signed in.")
            return .unavailable(provider: .claude,
                message: "Sign in to Claude to show usage.",
                capturedAt: capturedAt, sourceDescription: "claude.ai")
        } catch {
            logger.error("Usage fetch failed: \(error.localizedDescription)")
            return .unavailable(provider: .claude,
                message: "Could not read usage.",
                capturedAt: capturedAt, sourceDescription: "claude.ai")
        }
    }
}