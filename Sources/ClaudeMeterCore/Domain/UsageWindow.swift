import Foundation

public struct UsageWindow: Equatable {
    public var label: String
    public var usagePercentage: Double?
    public var resetDate: Date?
    public var resetDescription: String?
    public var limitDescription: String?

    public init(
        label: String,
        usagePercentage: Double? = nil,
        resetDate: Date? = nil,
        resetDescription: String? = nil,
        limitDescription: String? = nil
    ) {
        self.label = label
        self.usagePercentage = usagePercentage
        self.resetDate = resetDate
        self.resetDescription = resetDescription
        self.limitDescription = limitDescription
    }

    public var remainingPercentage: Double? {
        guard let usagePercentage else {
            return nil
        }
        return max(0, min(100, 100 - usagePercentage))
    }
}
