import Combine
import Foundation

@MainActor
public final class UsageStateManager: ObservableObject {
    @Published public private(set) var snapshot: UsageSnapshot
    @Published public private(set) var now: Date
    @Published public private(set) var isRefreshing: Bool
    @Published public private(set) var lastRefreshFailure: String?

    private let providerRegistry: ProviderRegistry
    private let settings: SettingsManager
    private let logger: AppLogger
    private var cancellables: Set<AnyCancellable> = []
    private var refreshCancellable: AnyCancellable?

    public init(
        providerRegistry: ProviderRegistry,
        settings: SettingsManager,
        logger: AppLogger
    ) {
        self.providerRegistry = providerRegistry
        self.settings = settings
        self.logger = logger
        self.snapshot = .unavailable(
            provider: .claude,
            message: "Waiting for first refresh.",
            sourceDescription: "Claude CLI"
        )
        self.now = Date()
        self.isRefreshing = false
        self.lastRefreshFailure = nil

        configureTimers()
        refreshNow()
    }

    public func refreshNow() {
        guard !isRefreshing else {
            return
        }
        guard let provider = providerRegistry.provider() else {
            snapshot = .unavailable(
                provider: providerRegistry.activeProvider,
                message: "No provider registered.",
                capturedAt: Date(),
                sourceDescription: "Provider registry"
            )
            return
        }

        isRefreshing = true

        Task { [weak self, provider] in
            let nextSnapshot = await provider.fetchUsage()

            await MainActor.run {
                guard let self else {
                    return
                }

                self.snapshot = nextSnapshot
                self.now = Date()
                self.isRefreshing = false
                self.lastRefreshFailure = nextSnapshot.status.message

                if let message = nextSnapshot.status.message {
                    self.logger.warning("Usage refresh completed with warning: \(message)")
                } else {
                    self.logger.info("Usage refresh completed.")
                }
            }
        }
    }

    public func sessionCountdownText() -> String {
        UsageFormatters.countdownString(
            until: snapshot.session?.resetDate,
            fallback: snapshot.session?.resetDescription,
            now: now
        )
    }

    public func weeklyCountdownText() -> String {
        UsageFormatters.countdownString(
            until: snapshot.weekly?.resetDate,
            fallback: snapshot.weekly?.resetDescription,
            now: now
        )
    }

    private func configureTimers() {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                Task { @MainActor [weak self] in
                    self?.now = date
                }
            }
            .store(in: &cancellables)

        settings.$refreshInterval
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.restartRefreshTimer()
                }
            }
            .store(in: &cancellables)

        restartRefreshTimer()
    }

    private func restartRefreshTimer() {
        refreshCancellable?.cancel()
        refreshCancellable = Timer.publish(every: settings.refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshNow()
                }
            }
    }
}
