import AppKit

/// Keeps the app running: a per-user launchd agent starts it at login and
/// restarts it if it ever quits or crashes (KeepAlive).
enum LaunchAgent {
    static let label = "io.github.sethburt6.lightsbridge"
    static let devMode = ProcessInfo.processInfo.environment["LIGHTSBRIDGE_DEV"] == "1"
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    private static var domain: String { "gui/\(getuid())" }

    /// launchd sets XPC_SERVICE_NAME to the job label for jobs it starts.
    static var startedByLaunchd: Bool {
        ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] == label
    }

    /// Call before showing any UI. May terminate the process.
    static func ensureInstalledOrExit() {
        if devMode { Log.info("Dev mode: LaunchAgent logic skipped"); return }

        if !Bundle.main.bundlePath.hasPrefix("/Applications/") {
            let alert = NSAlert()
            alert.messageText = "Please move Lights Bridge into your Applications folder, then open it again."
            alert.addButton(withTitle: "Show in Finder")
            alert.addButton(withTitle: "Quit")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: Bundle.main.bundlePath)])
            }
            exit(0)
        }

        let exe = Bundle.main.executablePath ?? ""
        if !plistMatches(executable: exe) {
            writePlist(executable: exe)
            // bootout first in case an old copy is loaded (error ignored), then load the new plist.
            _ = run("/bin/launchctl", ["bootout", "\(domain)/\(label)"])
            let r = run("/bin/launchctl", ["bootstrap", domain, plistURL.path])
            Log.info("LaunchAgent installed (bootstrap status \(r))")
            if !startedByLaunchd { exit(0) }   // launchd's copy is now the only instance
        } else if !startedByLaunchd {
            // -k restarts a running copy, so opening the app after an update loads the new version.
            var r = run("/bin/launchctl", ["kickstart", "-k", "\(domain)/\(label)"])
            if r != 0 {
                // The job isn't loaded (e.g. after "Quit (stops until next login)"), so load it;
                // RunAtLoad then starts it.
                r = run("/bin/launchctl", ["bootstrap", domain, plistURL.path])
                Log.info("Re-loaded LaunchAgent (bootstrap status \(r))")
            } else {
                Log.info("Handing over to launchd (kickstart status \(r))")
            }
            exit(0)
        }

        // Single-instance guard.
        if let id = Bundle.main.bundleIdentifier {
            let me = ProcessInfo.processInfo.processIdentifier
            if NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != me }) {
                Log.info("Another instance is running; exiting")
                exit(0)
            }
        }
    }

    /// Stop now; launchd will start us again at next login (plist stays in place).
    static func stopUntilNextLogin() {
        Log.info("Stopping until next login")
        _ = run("/bin/launchctl", ["bootout", "\(domain)/\(label)"])
        exit(0)
    }

    private static func plistMatches(executable: String) -> Bool {
        guard let d = NSDictionary(contentsOf: plistURL),
              let args = d["ProgramArguments"] as? [String] else { return false }
        return args == [executable]
    }

    private static func writePlist(executable: String) {
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
        ]
        try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        (dict as NSDictionary).write(to: plistURL, atomically: true)
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
    }
}
