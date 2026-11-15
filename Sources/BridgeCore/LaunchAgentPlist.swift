import Foundation

/// Builds the launchd job description for the per-user LaunchAgent (pure, so it can be unit tested).
public enum LaunchAgentPlist {
    /// KeepAlive is always true; the app itself decides on launch whether an unexpected exit
    /// should be followed by running again (see LaunchAgent.swift). RunAtLoad follows the
    /// "Start when the Mac logs in" setting.
    public static func make(label: String, executable: String, startAtLogin: Bool) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": startAtLogin,
            "KeepAlive": true,
            "ProcessType": "Interactive",
        ]
    }
}
