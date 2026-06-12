import Foundation

public protocol UsageProvider: Sendable {
    var kind: UsageProviderKind { get }
    var displayName: String { get }

    func fetchUsage() async -> UsageSnapshot
}
