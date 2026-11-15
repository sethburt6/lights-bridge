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
        populate(menu)
    }

    /// Rebuilds the menu items. `forceQuit` shows the Quit item regardless of the Option key
    /// (used by the dev menu snapshot).
    private func populate(_ menu: NSMenu, forceQuit: Bool = false) {
        menu.removeAllItems()

        // Status lines. They have an action (open Settings) so macOS draws them in normal colors
        // instead of dimmed.
        let connected = engine.currentOutputName != nil
        let statusText = connected ? "Connected to \(engine.currentOutputName ?? "")" : "Board cable not found"
        let status = action(statusText, #selector(openSettings))
        status.attributedTitle = NSAttributedString(string: statusText, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ])
        status.image = Self.circleImage(color: connected ? .systemGreen : .systemRed, diameter: 9)
        menu.addItem(status)

        let cueText: String
        if let last = engine.lastCue {
            cueText = "Last cue \(last.cue) at \(cueTimeFormatter.string(from: last.date))"
        } else {
            cueText = "No cues sent yet"
        }
        let cue = action(cueText, #selector(openSettings))
        cue.attributedTitle = NSAttributedString(string: cueText, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        cue.image = Self.circleImage(color: nil, diameter: 9)   // blank, keeps the text aligned
        menu.addItem(cue)
        menu.addItem(.separator())

        menu.addItem(action("Send Test Cue…", #selector(sendTestCue), symbol: "paperplane"))
        let settings = action("Settings…", #selector(openSettings), symbol: "gearshape")
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(.separator())

        menu.addItem(action("Setup Guide", #selector(openSetupGuide), symbol: "book"))
        menu.addItem(action("Show Log", #selector(showLog), symbol: "doc.text"))
        menu.addItem(.separator())

        menu.addItem(action("About Lights Bridge", #selector(showAbout), symbol: "info.circle"))

        if forceQuit || !Settings.quitNeedsOption || NSEvent.modifierFlags.contains(.option) {
            menu.addItem(.separator())
            menu.addItem(action("Quit Lights Bridge", #selector(quit), symbol: "power"))
        }
    }

    private func action(_ title: String, _ sel: Selector, symbol: String? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        it.target = self
        if let symbol = symbol { it.image = Self.symbolImage(symbol) }
        return it
    }

    /// An SF Symbol at about 13 pt regular, as a template image so the menu tints it.
    private static func symbolImage(_ name: String) -> NSImage? {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let configured = img.withSymbolConfiguration(config) ?? img
        configured.isTemplate = true
        return configured
    }

    /// A small drawn circle. With a nil color the image is blank (same size, nothing drawn).
    private static func circleImage(color: NSColor?, diameter: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            if let color = color {
                color.setFill()
                NSBezierPath(ovalIn: rect).fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    // MARK: Dev snapshot

    /// Dev only: draws the built menu items into a PNG inside a menu-like panel. A real NSMenu
    /// cannot be rendered offscreen, so this lays the same titles, attributed strings and images
    /// out by hand.
    func snapshotMenu(to url: URL) {
        let menu = NSMenu()
        populate(menu, forceQuit: true)
        let view = MenuPreviewView(items: menu.items)
        let size = view.intrinsicContentSize
        view.frame = NSRect(origin: .zero, size: size)
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                                         pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: url) }
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

/// Dev only: a hand-drawn stand-in for an open menu, used by `--snapshot-menu`.
private final class MenuPreviewView: NSView {
    private let items: [NSMenuItem]
    private let pad: CGFloat = 10          // panel padding around the rows
    private let rowHeight: CGFloat = 24
    private let separatorHeight: CGFloat = 11
    private let width: CGFloat = 270

    init(items: [NSMenuItem]) {
        self.items = items
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize {
        let h = items.reduce(CGFloat(0)) { $0 + ($1.isSeparatorItem ? separatorHeight : rowHeight) }
        return NSSize(width: width, height: h + pad)
    }

    /// Draws an image tinted with a color (needed for template symbols).
    private func draw(_ image: NSImage, in rect: NSRect, tint: NSColor?) {
        guard image.isTemplate, let tint = tint else { image.draw(in: rect); return }
        let tinted = NSImage(size: rect.size, flipped: false) { r in
            image.draw(in: r)
            tint.setFill()
            r.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: rect)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let panel = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
            (dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.95, alpha: 1)).setFill()
            panel.fill()
            NSColor.separatorColor.setStroke()
            panel.stroke()

            var y = bounds.maxY - pad / 2
            let imageColumn: CGFloat = 16 + 10
            let textX: CGFloat = 12 + imageColumn + 6
            for item in items {
                if item.isSeparatorItem {
                    y -= separatorHeight
                    NSColor.separatorColor.setFill()
                    NSRect(x: 14, y: y + separatorHeight / 2, width: bounds.width - 28, height: 1).fill()
                    continue
                }
                y -= rowHeight
                let rowRect = NSRect(x: 0, y: y, width: bounds.width, height: rowHeight)
                if let img = item.image {
                    let s = img.size
                    let r = NSRect(x: 12 + (imageColumn - s.width) / 2, y: rowRect.midY - s.height / 2,
                                   width: s.width, height: s.height)
                    draw(img, in: r, tint: .labelColor)
                }
                let title = item.attributedTitle ?? NSAttributedString(string: item.title, attributes: [
                    .font: NSFont.menuFont(ofSize: 0),
                    .foregroundColor: NSColor.labelColor,
                ])
                let ts = title.size()
                title.draw(at: NSPoint(x: textX, y: rowRect.midY - ts.height / 2))
                if !item.keyEquivalent.isEmpty {
                    let key = NSAttributedString(string: "\u{2318}\(item.keyEquivalent)", attributes: [
                        .font: NSFont.menuFont(ofSize: 0),
                        .foregroundColor: NSColor.secondaryLabelColor,
                    ])
                    let ks = key.size()
                    key.draw(at: NSPoint(x: bounds.width - 14 - ks.width, y: rowRect.midY - ks.height / 2))
                }
            }
        }
    }
}
