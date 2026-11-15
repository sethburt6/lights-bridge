import AppKit
import BridgeCore

/// Keeps the app running: a per-user launchd agent starts it at login and
/// restarts it if it ever quits or crashes (KeepAlive).
///
/// Reliability settings design:
/// - KeepAlive stays true in the plist at all times, so launchd always relaunches the app after
///   any exit. We never reload the running job to apply a setting.
/// - "Start at login" only changes RunAtLoad in the plist file; launchd reads it at next login.
/// - "Restart if it quits" is decided by the app on launch, using a crash marker file. The marker
///   is created once startup finishes and deleted on every clean exit (Settings quit, menu Quit,
///   logout). If a launchd-started copy finds the marker, the previous run died unexpectedly; if
///   the setting is off it stops itself (bootout) instead of continuing.
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
        if !plistMatches(executable: exe) && startedByLaunchd {
            // Already running as the launchd job: just refresh the file for next login. Booting
            // out our own job here would kill this process before it could load the new plist.
            writePlist(executable: exe)
            Log.info("LaunchAgent file refreshed")
        } else if !plistMatches(executable: exe) {
            writePlist(executable: exe)
            clearRunningMarker()   // a deliberate restart is not a crash
            // bootout first in case an old copy is loaded (error ignored), then load the new plist.
            _ = run("/bin/launchctl", ["bootout", "\(domain)/\(label)"])
            let r = run("/bin/launchctl", ["bootstrap", domain, plistURL.path])
            Log.info("LaunchAgent installed (bootstrap status \(r))")
            if !startedByLaunchd {
                // With RunAtLoad off, bootstrap alone does not start the app, so start it now.
                let k = run("/bin/launchctl", ["kickstart", "\(domain)/\(label)"])
                Log.info("Started LaunchAgent (kickstart status \(k))")
                exit(0)   // launchd's copy is now the only instance
            }
        } else if !startedByLaunchd {
            // -k restarts a running copy, so opening the app after an update loads the new version.
            clearRunningMarker()   // a deliberate restart is not a crash
            var r = run("/bin/launchctl", ["kickstart", "-k", "\(domain)/\(label)"])
            if r != 0 {
                // The job isn't loaded (e.g. after "Quit (stops until next login)"), so load it,
                // then start it (RunAtLoad may be off, so do not rely on it).
                r = run("/bin/launchctl", ["bootstrap", domain, plistURL.path])
                let k = run("/bin/launchctl", ["kickstart", "\(domain)/\(label)"])
                Log.info("Re-loaded LaunchAgent (bootstrap status \(r), kickstart status \(k))")
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

        // Crash marker (see the design note above). Only launchd-started copies reach this point.
        if startedByLaunchd {
            if FileManager.default.fileExists(atPath: markerURL.path) {
                if !Settings.restartIfQuits {
                    Log.info("Previous run ended unexpectedly; automatic restart is off, stopping")
                    stopUntilNextLogin()
                }
                Log.info("Restarted after unexpected exit")
            }
            try? FileManager.default.createDirectory(at: markerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: markerURL.path, contents: nil)
        }
    }

    /// Present while a launchd-started copy is running; removed on clean exit.
    private static var markerURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Lights Bridge/running")
    }

    /// Removes the crash marker. Call on every clean exit. No-op in dev mode.
    static func clearRunningMarker() {
        if devMode { return }
        try? FileManager.default.removeItem(at: markerURL)
    }

    /// Applies the "Start when the Mac logs in" setting by rewriting the plist file only.
    /// launchd reads it at next login; the running job is not booted out or reloaded.
    static func applyStartAtLogin() {
        if devMode { Log.info("Dev mode: start at login set to \(Settings.startAtLogin) (plist not written)"); return }
        writePlist(executable: Bundle.main.executablePath ?? "")
        Log.info("Start at login set to \(Settings.startAtLogin)")
    }

    /// Stop now; launchd will start us again at next login (plist stays in place).
    static func stopUntilNextLogin() {
        Log.info("Stopping until next login")
        clearRunningMarker()
        _ = run("/bin/launchctl", ["bootout", "\(domain)/\(label)"])
        exit(0)
    }

    private static func plistMatches(executable: String) -> Bool {
        guard let d = NSDictionary(contentsOf: plistURL),
              let args = d["ProgramArguments"] as? [String] else { return false }
        let runAtLoad = d["RunAtLoad"] as? Bool ?? true
        return args == [executable] && runAtLoad == Settings.startAtLogin
    }

    private static func writePlist(executable: String) {
        let dict = LaunchAgentPlist.make(label: label, executable: executable, startAtLogin: Settings.startAtLogin)
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
