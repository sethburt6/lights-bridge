import AppKit

/// Wiring only: creates the engine and the UI controllers and runs the LaunchAgent check.
/// Everything else lives in MIDIEngine, StatusItemController and SettingsWindowController.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = MIDIEngine()
    private var settingsWindow: SettingsWindowController!
    private var statusController: StatusItemController!
    /// Turns SIGTERM (logout, restart, `launchctl` stop, Activity Monitor "Quit") into a normal
    /// AppKit quit, so applicationWillTerminate runs and the crash marker is cleared. Without this
    /// a Mac restart would look like a crash, and with "Restart automatically" off the app would
    /// stop itself at the next login.
    private var termSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        termSource = source

        let args = CommandLine.arguments
        /// Value following a dev flag, e.g. `--snapshot-settings <path>`.
        func devValue(_ flag: String) -> String? {
            guard LaunchAgent.devMode, let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
            return args[i + 1]
        }

        Log.info("Lights Bridge starting (version \(AppInfo.version), pid \(ProcessInfo.processInfo.processIdentifier), dev=\(LaunchAgent.devMode))")
        LaunchAgent.ensureInstalledOrExit()

        settingsWindow = SettingsWindowController(engine: engine)
        statusController = StatusItemController(engine: engine, settingsWindow: settingsWindow)
        engine.start()

        // Dev only: open the Settings window at launch, optionally save a PNG of it and quit.
        if LaunchAgent.devMode && (args.contains("--open-settings") || args.contains("--snapshot-settings")) {
            settingsWindow.show()
        }
        if let path = devValue("--snapshot-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.settingsWindow.snapshot(to: URL(fileURLWithPath: path))
                NSApp.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        LaunchAgent.clearRunningMarker()
    }
}
