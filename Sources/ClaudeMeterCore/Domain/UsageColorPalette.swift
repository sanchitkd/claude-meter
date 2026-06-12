import Foundation

public struct UsageColorPalette: Codable, Equatable {
    public var green: String
    public var cyan: String
    public var blue: String
    public var yellow: String
    public var orange: String
    public var red: String
    public var darkRed: String
    public var exhausted: String
    public var unavailable: String

    public init(
        green: String = "#20D26B",
        cyan: String = "#13D8D1",
        blue: String = "#3478F6",
        yellow: String = "#FFD84D",
        orange: String = "#FF8A2A",
        red: String = "#FF453A",
        darkRed: String = "#8B0000",
        exhausted: String = "#050505",
        unavailable: String = "#737373"
    ) {
        self.green = green
        self.cyan = cyan
        self.blue = blue
        self.yellow = yellow
        self.orange = orange
        self.red = red
        self.darkRed = darkRed
        self.exhausted = exhausted
        self.unavailable = unavailable
    }
}
