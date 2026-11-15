import AppKit
import os

/// Logs to the unified system log and to ~/Library/Logs/LightsBridge.log
/// (trimmed to roughly its last half when it passes 1 MB).
enum Log {
    static let fileURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/LightsBridge.log")
    private static let logger = Logger(subsystem: "io.github.sethburt6.lightsbridge", category: "app")
    private static let queue = DispatchQueue(label: "io.github.sethburt6.lightsbridge.log")
    private static let maxBytes = 1_000_000
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    /// Opens the log file in the default app (Console).
    static func show() { NSWorkspace.shared.open(fileURL) }

    /// Writes one line to both logs. Safe to call from any thread.
    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        queue.async {
            let line = "\(formatter.string(from: Date())) \(message)\n"
            let fm = FileManager.default
            try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fm.fileExists(atPath: fileURL.path) {
                fm.createFile(atPath: fileURL.path, contents: nil)
            }
            guard let h = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? h.close() }
            h.seekToEndOfFile()
            h.write(Data(line.utf8))
            trimIfNeeded()
        }
    }

    // Called on `queue` only.
    private static func trimIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int, size > maxBytes,
              let data = try? Data(contentsOf: fileURL) else { return }
        var tail = data.suffix(size / 2)
        // Drop the partial first line.
        if let nl = tail.firstIndex(of: 0x0A) { tail = tail[tail.index(after: nl)...] }
        try? Data(tail).write(to: fileURL, options: .atomic)
    }
}
