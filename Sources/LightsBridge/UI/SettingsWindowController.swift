import AppKit

/// A small filled circle used as a status light (drawn, not an emoji).
final class StatusDotView: NSView {
    var color: NSColor = .systemGray { didSet { needsDisplay = true } }

    override var intrinsicContentSize: NSSize { NSSize(width: 10, height: 10) }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5)).fill()
    }
}

/// The "Lights Bridge Settings" window: live status, output and channel choice,
/// cue offset, and a test-cue sender. It refreshes whenever the window is shown and
/// whenever the engine posts `MIDIEngine.didChangeNotification`.
final class SettingsWindowController: NSWindowController {
    private let engine: MIDIEngine
    private var hasBeenCentered = false

    // Status
    private let cableDot = StatusDotView()
    private let cableLabel = SettingsWindowController.valueLabel()
    private let noteLabel = SettingsWindowController.valueLabel()
    private let cueLabel = SettingsWindowController.valueLabel()
    // Board
    private let outputPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let channelPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    // Advanced
    private let offsetStepper = NSStepper()
    private let offsetLabel = SettingsWindowController.valueLabel()
    // Test
    private let testField = NSTextField()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .medium; f.dateStyle = .none; return f
    }()

    init(engine: MIDIEngine) {
        self.engine = engine
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Lights Bridge Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent(in: window)
        NotificationCenter.default.addObserver(self, selector: #selector(engineDidChange),
                                               name: MIDIEngine.didChangeNotification, object: engine)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: Showing

    /// Refreshes the values and brings the window to the front.
    func show() {
        engine.refreshOutput()
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        if !hasBeenCentered { window?.center(); hasBeenCentered = true }
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(nil)
    }

    /// Dev only: writes the whole window (title bar included) to a PNG, for review screenshots
    /// when screen-recording permission blocks `screencapture`.
    func snapshot(to url: URL) {
        guard let frameView = window?.contentView?.superview else { return }
        frameView.layoutSubtreeIfNeeded()
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { return }
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: url) }
    }

    @objc private func engineDidChange() {
        if window?.isVisible == true { refresh() }
    }

    // MARK: Building

    private static func valueLabel() -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.lineBreakMode = .byTruncatingTail
        return l
    }

    private static func rowLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        return l
    }

    private static func header(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text).then {
            $0.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        }
    }

    private static func separator() -> NSBox {
        let b = NSBox(); b.boxType = .separator; return b
    }

    private func buildContent(in window: NSWindow) {
        // Controls
        outputPopup.target = self; outputPopup.action = #selector(outputChanged)
        channelPopup.target = self; channelPopup.action = #selector(channelChanged)
        for c in 1...16 { channelPopup.addItem(withTitle: "\(c)"); channelPopup.lastItem?.tag = c }

        offsetStepper.minValue = -5; offsetStepper.maxValue = 5; offsetStepper.increment = 1
        offsetStepper.valueWraps = false
        offsetStepper.target = self; offsetStepper.action = #selector(offsetChanged)
        let offsetRow = NSStackView(views: [offsetStepper, offsetLabel])
        offsetRow.orientation = .horizontal; offsetRow.spacing = 8

        let note = NSTextField(wrappingLabelWithString:
            "Only change this if the board runs a different cue than the slide asks for.")
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = 260

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0; formatter.maximum = 127; formatter.allowsFloats = false
        testField.formatter = formatter
        testField.integerValue = 1
        testField.alignment = .right
        testField.widthAnchor.constraint(equalToConstant: 56).isActive = true
        let sendButton = NSButton(title: "Send Test Cue", target: self, action: #selector(sendTest))
        let testRow = NSStackView(views: [testField, sendButton])
        testRow.orientation = .horizontal; testRow.spacing = 8

        cableDot.translatesAutoresizingMaskIntoConstraints = false
        let cableRow = NSStackView(views: [cableDot, cableLabel])
        cableRow.orientation = .horizontal; cableRow.spacing = 6

        // Footer
        let version = NSTextField(labelWithString: "Version \(AppInfo.version)")
        version.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        version.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let guide = NSButton(title: "Setup Guide", target: self, action: #selector(openGuide))
        let log = NSButton(title: "Show Log", target: self, action: #selector(openLog))
        let footer = NSStackView(views: [version, spacer, guide, log])
        footer.orientation = .horizontal; footer.spacing = 8

        // Grid: column 0 = right-aligned labels, column 1 = controls.
        let grid = NSGridView(numberOfColumns: 2, rows: 0)
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        /// A row spanning both columns; headers sit left, separators and the footer stretch.
        func fullRow(_ v: NSView, fill: Bool = true) {
            let row = grid.addRow(with: [v, NSGridCell.emptyContentView])
            row.mergeCells(in: NSRange(location: 0, length: 2))
            row.cell(at: 0).xPlacement = fill ? .fill : .leading
        }
        func formRow(_ label: String, _ control: NSView) { grid.addRow(with: [Self.rowLabel(label), control]) }
        func section(_ title: String) {
            fullRow(Self.separator())
            fullRow(Self.header(title), fill: false)
        }

        fullRow(Self.header("Status"), fill: false)
        formRow("Board cable:", cableRow)
        formRow("From ProPresenter:", noteLabel)
        formRow("Last cue sent:", cueLabel)
        section("Board")
        formRow("Send to:", outputPopup)
        formRow("MIDI channel:", channelPopup)
        section("Advanced")
        formRow("Cue number offset:", offsetRow)
        grid.addRow(with: [NSGridCell.emptyContentView, note])
        section("Test")
        formRow("Cue number:", testRow)
        fullRow(Self.separator())
        fullRow(footer)

        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 140
        grid.column(at: 1).xPlacement = .leading
        for i in 0..<grid.numberOfRows {
            grid.row(at: i).yPlacement = .center
        }

        let content = NSView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalToConstant: 460),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 460, height: content.fittingSize.height))
        refresh()
    }

    // MARK: Refreshing

    /// Copies current engine and Settings values into the controls.
    private func refresh() {
        // Status
        if let out = engine.currentOutputName {
            cableDot.color = .systemGreen
            cableLabel.stringValue = "Connected: \(out)"
        } else {
            cableDot.color = .systemRed
            cableLabel.stringValue = "Not found"
        }
        if let n = engine.lastNoteReceived {
            noteLabel.stringValue = "Note \(n.note) at \(timeFormatter.string(from: n.date))"
        } else {
            noteLabel.stringValue = "Nothing received yet"
        }
        if let c = engine.lastCue {
            cueLabel.stringValue = "Cue \(c.cue) at \(timeFormatter.string(from: c.date))"
        } else {
            cueLabel.stringValue = "None yet"
        }

        // Output popup: Automatic, then hardware first, then virtual.
        outputPopup.removeAllItems()
        outputPopup.addItem(withTitle: "Automatic (only cable)")
        outputPopup.menu?.addItem(.separator())
        let dests = engine.availableDestinations.sorted {
            ($0.isHardware ? 0 : 1, $0.name) < ($1.isHardware ? 0 : 1, $1.name)
        }
        for d in dests {
            let item = NSMenuItem(title: d.isHardware ? d.name : "\(d.name) (virtual)", action: nil, keyEquivalent: "")
            item.representedObject = ["id": NSNumber(value: d.id), "name": d.name]
            outputPopup.menu?.addItem(item)
        }
        if Settings.outputUniqueID == nil && Settings.outputName == nil {
            outputPopup.selectItem(at: 0)
        } else if let out = engine.currentOutputName,
                  let idx = dests.firstIndex(where: { $0.name == out }) {
            outputPopup.selectItem(at: idx + 2)
        } else {
            // Saved choice is not connected right now; show it, disabled, so the popup is truthful.
            let name = Settings.outputName ?? "Saved output"
            let item = NSMenuItem(title: "\(name) (not connected)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            outputPopup.menu?.addItem(item)
            outputPopup.select(item)
        }

        channelPopup.selectItem(withTag: Settings.boardChannel)

        let off = min(5, max(-5, Settings.cueOffset))
        offsetStepper.integerValue = off
        offsetLabel.stringValue = off > 0 ? "+\(off)" : "\(off)"
    }

    // MARK: Actions

    @objc private func outputChanged() {
        if outputPopup.indexOfSelectedItem == 0 {
            engine.select(id: nil, name: nil)
        } else if let info = outputPopup.selectedItem?.representedObject as? [String: Any],
                  let id = (info["id"] as? NSNumber)?.int32Value, let name = info["name"] as? String {
            engine.select(id: id, name: name)
        }
        refresh()
    }

    @objc private func channelChanged() {
        let c = channelPopup.selectedItem?.tag ?? 1
        Settings.boardChannel = c
        engine.reloadSettings()
        Log.info("Board MIDI channel set to \(c)")
    }

    @objc private func offsetChanged() {
        Settings.cueOffset = offsetStepper.integerValue
        engine.reloadSettings()
        Log.info("Cue number offset set to \(Settings.cueOffset)")
        refresh()
    }

    @objc private func sendTest() {
        window?.makeFirstResponder(nil)   // commit any text being edited
        let n = testField.integerValue
        guard (0...127).contains(n) else { NSSound.beep(); return }
        engine.sendTestCue(n)
    }

    @objc private func openGuide() { AppInfo.openSetupGuide() }
    @objc private func openLog() { Log.show() }
}

private extension NSObject {
    /// Tiny helper so a view can be configured inline.
    @discardableResult func then(_ configure: (Self) -> Void) -> Self { configure(self); return self }
}
