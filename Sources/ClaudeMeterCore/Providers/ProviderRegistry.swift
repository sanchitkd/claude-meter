import Foundation

public final class ProviderRegistry: @unchecked Sendable {
    private var providers: [UsageProviderKind: any UsageProvider]
    public private(set) var activeProvider: UsageProviderKind

    public init(providers: [any UsageProvider], activeProvider: UsageProviderKind = .claude) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.kind, $0) })
        self.activeProvider = activeProvider
    }

    public func provider(for kind: UsageProviderKind? = nil) -> (any UsageProvider)? {
        providers[kind ?? activeProvider]
    }

    public func register(_ provider: any UsageProvider) {
        providers[provider.kind] = provider
    }

    public func setActiveProvider(_ kind: UsageProviderKind) {
        guard providers[kind] != nil else {
            return
        }
        activeProvider = kind
    }
}
