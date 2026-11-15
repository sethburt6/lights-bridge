import AppKit

/// Owns the menu-bar item and its menu. The item shows a colored dot and the word "Lights"
/// (green working, yellow waiting for ProPresenter, red board cable not found).
final class StatusItemController: NSObject, NSMenuDelegate {
    private let engine: MIDIEngine
    private let settingsWindow: SettingsWindowController
    private let statusItem: NSStatusItem

    private let cueTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    init(engine: MIDIEngine, settingsWindow: SettingsWindowController) {
        self.engine = engine
        self.settingsWindow = settingsWindow
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(engineDidChange(_:)),
                                               name: MIDIEngine.didChangeNotification, object: engine)
        updateIcon()
    }

    // MARK: Icon

    @objc private func engineDidChange(_ note: Notification) {
        updateIcon()
    }

    private func updateIcon() {
        let color: NSColor
        let tip: String
        if engine.currentOutputName == nil {
            color = .systemRed
            tip = "Board cable not found. Check the USB MIDI cable."
        } else if engine.translatedCount > 0 {
            color = .systemGreen
            tip = "Working: slides have triggered cues."
        } else {
            color = .systemYellow
            tip = "Board cable found. Nothing received from ProPresenter yet."
        }
        let title = NSMutableAttributedString(string: "\u{25CF} ", attributes: [.foregroundColor: color])
        title.append(NSAttributedString(string: "Lights"))
        statusItem.button?.image = nil
        statusItem.button?.attributedTitle = title
        statusItem.button?.toolTip = tip
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        engine.refreshOutput()
        updateIcon()
        menu.removeAllItems()

        if let out = engine.currentOutputName {
            menu.addItem(disabled("Ready — sending to \(out)"))
        } else {
            menu.addItem(disabled("Board cable not found"))
        }
        if let last = engine.lastCue {
            menu.addItem(disabled("Last cue: \(last.cue) at \(cueTimeFormatter.string(from: last.date))"))
        } else {
            menu.addItem(disabled("Last cue: none yet"))
        }
        menu.addItem(.separator())

        menu.addItem(action("Send Test Cue…", #selector(sendTestCue)))
        let settings = action("Settings…", #selector(openSettings))
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(action("Setup Guide", #selector(openSetupGuide)))
        menu.addItem(action("Show Log", #selector(showLog)))
        menu.addItem(.separator())

        menu.addItem(action("About Lights Bridge", #selector(showAbout)))

        if NSEvent.modifierFlags.contains(.option) {
            menu.addItem(.separator())
            menu.addItem(action("Quit (stops until next login)", #selector(quit)))
        }
    }

    private func action(_ title: String, _ sel: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        it.target = self
        return it
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.isEnabled = false
        return it
    }

    // MARK: Actions

    @objc private func sendTestCue() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Send Test Cue"
        alert.informativeText = "Enter a cue number from 0 to 127."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = "1"
        alert.accessoryView = field
        alert.addButton(withTitle: "Send")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let n = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), (0...127).contains(n) {
            engine.sendTestCue(n)
        } else {
            let bad = NSAlert()
            bad.messageText = "Please enter a number from 0 to 127."
            bad.runModal()
        }
    }

    @objc private func openSettings() { settingsWindow.show() }
    @objc private func openSetupGuide() { AppInfo.openSetupGuide() }
    @objc private func showLog() { Log.show() }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Turns ProPresenter slide cues into Program Change messages for your lighting board.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Lights Bridge",
            .applicationVersion: AppInfo.version,
            .version: "",
            .credits: credits,
        ])
    }

    @objc private func quit() {
        if LaunchAgent.devMode { NSApp.terminate(nil) } else { LaunchAgent.stopUntilNextLogin() }
    }
}
