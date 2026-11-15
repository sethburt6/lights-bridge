import AppKit

/// User settings, stored in UserDefaults (~/Library/Preferences/io.github.sethburt6.lightsbridge.plist).
enum Settings {
    private static let d = UserDefaults.standard

    /// MIDI channel (1...16) that Program Change is sent on.
    static var boardChannel: Int {
        get {
            let v = d.object(forKey: "boardChannel") as? Int ?? 1
            return min(16, max(1, v))
        }
        set { d.set(min(16, max(1, newValue)), forKey: "boardChannel") }
    }

    /// Added to the note number to get the cue number (default 0). Shown in the
    /// Settings window as a -5...5 stepper; the value is not clamped here so a
    /// larger one set in Terminal still works:
    /// defaults write io.github.sethburt6.lightsbridge cueOffset -int 1
    static var cueOffset: Int {
        get { d.object(forKey: "cueOffset") as? Int ?? 0 }
        set { d.set(newValue, forKey: "cueOffset") }
    }

    /// The chosen output cable (nil = automatic).
    static var outputUniqueID: Int32? {
        get { d.object(forKey: "outputUniqueID") == nil ? nil : Int32(truncatingIfNeeded: d.integer(forKey: "outputUniqueID")) }
        set { if let v = newValue { d.set(Int(v), forKey: "outputUniqueID") } else { d.removeObject(forKey: "outputUniqueID") } }
    }
    static var outputName: String? {
        get { d.string(forKey: "outputName") }
        set { if let v = newValue { d.set(v, forKey: "outputName") } else { d.removeObject(forKey: "outputName") } }
    }

    /// Saved unique IDs of our own virtual endpoints, so apps (ProPresenter)
    /// recognise them after a restart.
    static var inputUniqueID: Int32? {
        get { d.object(forKey: "inputUniqueID") == nil ? nil : Int32(truncatingIfNeeded: d.integer(forKey: "inputUniqueID")) }
        set { if let v = newValue { d.set(Int(v), forKey: "inputUniqueID") } }
    }
    static var monitorUniqueID: Int32? {
        get { d.object(forKey: "monitorUniqueID") == nil ? nil : Int32(truncatingIfNeeded: d.integer(forKey: "monitorUniqueID")) }
        set { if let v = newValue { d.set(Int(v), forKey: "monitorUniqueID") } }
    }
}

/// Static facts about the app shared by the menu and the Settings window.
enum AppInfo {
    /// Marketing version from Info.plist ("dev" when run outside the app bundle).
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static let setupGuideURL = URL(string: "https://github.com/sethburt6/lights-bridge/blob/main/docs/SETUP.md")!

    static func openSetupGuide() { NSWorkspace.shared.open(setupGuideURL) }
}
