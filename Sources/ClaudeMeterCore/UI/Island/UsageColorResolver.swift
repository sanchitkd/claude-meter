import AppKit
import SwiftUI

public enum UsageColorResolver {
    public static func color(for percentage: Double?, palette: UsageColorPalette) -> Color {
        Color(nsColor: nsColor(for: percentage, palette: palette))
    }

    public static func nsColor(for percentage: Double?, palette: UsageColorPalette) -> NSColor {
        guard let percentage else {
            return NSColor(hex: palette.unavailable) ?? .systemGray
        }

        let value = max(0, min(100, percentage))
        let hex: String
        switch value {
        case 100...:   hex = palette.exhausted
        case 95..<100: hex = palette.darkRed
        case 85..<95:  hex = palette.red
        case 75..<85:  hex = palette.orange
        case 60..<75:  hex = palette.yellow
        case 40..<60:  hex = palette.blue
        case 20..<40:  hex = palette.cyan
        default:       hex = palette.green
        }
        return NSColor(hex: hex) ?? .systemGray
    }
    public static func textColor(for percentage: Double?, palette: UsageColorPalette) -> Color {
        let ns = nsColor(for: percentage, palette: palette).usingColorSpace(.deviceRGB) ?? .gray
        let lum = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return lum < 0.55 ? Color.white.opacity(0.96) : Color.black.opacity(0.85)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6,
              let integer = Int(value, radix: 16)
        else {
            return nil
        }

        let red = CGFloat((integer >> 16) & 0xFF) / 255
        let green = CGFloat((integer >> 8) & 0xFF) / 255
        let blue = CGFloat(integer & 0xFF) / 255
        self.init(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }

    func hexString() -> String {
        let color = usingColorSpace(.deviceRGB) ?? self
        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    func interpolated(to target: NSColor, progress: Double) -> NSColor {
        let left = usingColorSpace(.deviceRGB) ?? self
        let right = target.usingColorSpace(.deviceRGB) ?? target
        let clamped = CGFloat(max(0, min(1, progress)))

        return NSColor(
            calibratedRed: left.redComponent + (right.redComponent - left.redComponent) * clamped,
            green: left.greenComponent + (right.greenComponent - left.greenComponent) * clamped,
            blue: left.blueComponent + (right.blueComponent - left.blueComponent) * clamped,
            alpha: left.alphaComponent + (right.alphaComponent - left.alphaComponent) * clamped
        )
    }
}
