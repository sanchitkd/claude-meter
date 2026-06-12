import Foundation
import os

public final class AppLogger: @unchecked Sendable {
    private let logger = Logger(subsystem: "ClaudeMeter", category: "Application")
    public let logFileURL: URL
    private let queue = DispatchQueue(label: "ClaudeIsland.AppLogger")

    public init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = baseURL.appendingPathComponent("ClaudeMeter", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.logFileURL = directory.appendingPathComponent("ClaudeMeter.log")
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        append("INFO", message)
    }

    public func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        append("WARN", message)
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        append("ERROR", message)
    }

    public func fileSizeBytes() -> Int {
        let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)
        return (attrs?[.size] as? NSNumber)?.intValue ?? 0
    }

    public func formattedSize() -> String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes()), countStyle: .file)
    }

    /// Keeps one backup (ClaudeIsland.1.log) and starts fresh.
    public func rotate() {
        queue.async { [logFileURL] in
            let fm = FileManager.default
            let backup = logFileURL.deletingPathExtension().appendingPathExtension("1.log")
            try? fm.removeItem(at: backup)
            try? fm.moveItem(at: logFileURL, to: backup)
        }
    }

    public func clear() {
        queue.async { [logFileURL] in
            try? Data().write(to: logFileURL, options: .atomic)
        }
    }

    private func append(_ level: String, _ message: String) {
        let line = "[\(Self.timestampString(from: Date()))] [\(level)] \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        queue.async { [logFileURL] in
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logFileURL, options: .atomic)
            }
        }
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
