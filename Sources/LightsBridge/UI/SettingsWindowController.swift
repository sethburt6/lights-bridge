import AppKit

// MARK: - Reusable views

/// A small filled circle used as a status light (drawn, not an emoji).
final class StatusDotView: NSView {
    var color: NSColor = .systemGray { didSet { needsDisplay = true } }
    private let diameter: CGFloat

    init(diameter: CGFloat = 8) {
        self.diameter = diameter
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize { NSSize(width: diameter, height: diameter) }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}

/// One row inside a `GroupBox`: a fixed-height strip with an optional hairline along its top edge.
private final class GroupRow: NSView {
    private let showsSeparator: Bool

    init(showsSeparator: Bool) {
        self.showsSeparator = showsSeparator
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        guard showsSeparator else { return }
        NSColor.separatorColor.setFill()
        // Hairline along the top edge, inset from the left like System Settings.
        NSRect(x: GroupBox.inset, y: bounds.maxY - 0.5, width: bounds.width - GroupBox.inset, height: 0.5).fill()
    }
}

/// A rounded "card" that holds rows of `label ........ control`, like a group in System Settings.
final class GroupBox: NSView {
    static let rowHeight: CGFloat = 32
    static let inset: CGFloat = 12
    private let stack = NSStackView()
    private var rowCount = 0

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        // Colors are resolved at draw time, so the card follows light and dark mode.
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.25, dy: 0.25), xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    /// Adds a row: `label` on the left (13 pt), `control` right-aligned. The tooltip, when given,
    /// is set on the label and on the control (and its sub-controls).
    @discardableResult
    func addRow(label: String, control: NSView, tooltip: String? = nil) -> NSView {
        let row = GroupRow(showsSeparator: rowCount > 0)
        rowCount += 1

        let text = NSTextField(labelWithString: label)
        text.font = .systemFont(ofSize: 13)
        text.textColor = .labelColor
        text.lineBreakMode = .byTruncatingTail
        text.translatesAutoresizingMaskIntoConstraints = false
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.addSubview(text)
        row.addSubview(control)
        stack.addArrangedSubview(row)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: GroupBox.rowHeight),
            row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            text.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: GroupBox.inset),
            text.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -GroupBox.inset),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -8),
        ])
        if let tooltip = tooltip {
            text.toolTip = tooltip
            GroupBox.applyTooltip(tooltip, to: control)
        }
        return row
    }

    private static func applyTooltip(_ tip: String, to view: NSView) {
        view.toolTip = tip
        view.subviews.forEach { applyTooltip(tip, to: $0) }
    }
}

// MARK: - Window

/// The "Lights Bridge" settings window: a status header, then grouped cards for the board,
/// reliability and advanced options. It refreshes whenever the window is shown and whenever the
/// engine posts `MIDIEngine.didChangeNotification`.
final class SettingsWindowController: NSWindowController {
    private let engine: MIDIEngine
    private var hasBeenCentered = false

    private static let contentWidth: CGFloat = 440
    private static let margin: CGFloat = 20

    // Status header
    private let cableDot = StatusDotView(diameter: 8)
    private let cableLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    // Board
    private let outputPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let channelPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    // Reliability
    private let loginSwitch = NSSwitch()
    private let restartSwitch = NSSwitch()
    private let quitOptionSwitch = NSSwitch()
    // Advanced
    private let offsetStepper = NSStepper()
    private let offsetLabel = NSTextField(labelWithString: "")
    private let testField = NSTextField()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    init(engine: MIDIEngine) {
        self.engine = engine
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: SettingsWindowController.contentWidth, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Lights Bridge"
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

    /// A small secondary-color caption above a card ("Board", "Reliability", ...).
    private static func caption(_ text: String) -> NSView {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        let s = NSStackView(views: [l])
        s.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        return s
    }

    /// A borderless text button in the link color, for the footer.
    private func linkButton(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.isBordered = false
        b.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.linkColor,
        ])
        return b
    }

    private func configure(_ sw: NSSwitch, action: Selector) {
        sw.target = self
        sw.action = action
    }

    private func buildContent(in window: NSWindow) {
        // --- Status header ---
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true

        cableLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        cableLabel.textColor = .labelColor
        let line1 = NSStackView(views: [cableDot, cableLabel])
        line1.orientation = .horizontal; line1.spacing = 6; line1.alignment = .centerY

        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let lines = NSStackView(views: [line1, detailLabel])
        lines.orientation = .vertical; lines.alignment = .leading; lines.spacing = 3
        let header = NSStackView(views: [icon, lines])
        header.orientation = .horizontal; header.alignment = .centerY; header.spacing = 12

        // --- Board ---
        outputPopup.target = self; outputPopup.action = #selector(outputChanged)
        outputPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 170).isActive = true
        channelPopup.target = self; channelPopup.action = #selector(channelChanged)
        for c in 1...16 { channelPopup.addItem(withTitle: "\(c)"); channelPopup.lastItem?.tag = c }
        channelPopup.widthAnchor.constraint(equalToConstant: 64).isActive = true

        let boardBox = GroupBox()
        boardBox.addRow(label: "Send to", control: outputPopup)
        boardBox.addRow(label: "MIDI channel", control: channelPopup)

        // --- Reliability ---
        configure(loginSwitch, action: #selector(loginChanged))
        configure(restartSwitch, action: #selector(restartChanged))
        configure(quitOptionSwitch, action: #selector(quitOptionChanged))
        let reconnect = NSTextField(labelWithString: "Always on")
        reconnect.font = .systemFont(ofSize: 13)
        reconnect.textColor = .secondaryLabelColor

        let reliabilityBox = GroupBox()
        reliabilityBox.addRow(label: "Start at login", control: loginSwitch,
                              tooltip: "Lights Bridge is ready before ProPresenter opens.")
        reliabilityBox.addRow(label: "Restart if it quits", control: restartSwitch,
                              tooltip: "Comes back within about 10 seconds if it quits or crashes.")
        reliabilityBox.addRow(label: "Hide Quit (hold Option to show)", control: quitOptionSwitch,
                              tooltip: "Prevents quitting by accident.")
        reliabilityBox.addRow(label: "Cable reconnect", control: reconnect,
                              tooltip: "Finds the cable again after it's unplugged.")

        // --- Advanced ---
        offsetStepper.minValue = -5; offsetStepper.maxValue = 5; offsetStepper.increment = 1
        offsetStepper.valueWraps = false
        offsetStepper.target = self; offsetStepper.action = #selector(offsetChanged)
        offsetLabel.font = .systemFont(ofSize: 13)
        offsetLabel.alignment = .right
        offsetLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let offsetControl = NSStackView(views: [offsetLabel, offsetStepper])
        offsetControl.orientation = .horizontal; offsetControl.spacing = 6; offsetControl.alignment = .centerY

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0; formatter.maximum = 127; formatter.allowsFloats = false
        testField.formatter = formatter
        testField.integerValue = 1
        testField.alignment = .center
        testField.controlSize = .small
        testField.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small))
        testField.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let sendButton = NSButton(title: "Send", target: self, action: #selector(sendTest))
        sendButton.bezelStyle = .rounded
        sendButton.controlSize = .small
        let testControl = NSStackView(views: [testField, sendButton])
        testControl.orientation = .horizontal; testControl.spacing = 8; testControl.alignment = .centerY

        let advancedBox = GroupBox()
        advancedBox.addRow(label: "Cue number offset", control: offsetControl,
                           tooltip: "Only change this if the board runs a different cue than the slide asks for.")
        advancedBox.addRow(label: "Test cue", control: testControl,
                           tooltip: "Sends this cue straight to the board, without ProPresenter.")

        // --- Footer ---
        let version = NSTextField(labelWithString: "Version \(AppInfo.version)")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let footer = NSStackView(views: [version, spacer,
                                         linkButton("Setup Guide", action: #selector(openGuide)),
                                         linkButton("Show Log", action: #selector(openLog))])
        footer.orientation = .horizontal; footer.spacing = 14; footer.alignment = .centerY

        // --- Assemble ---
        let main = NSStackView()
        main.orientation = .vertical
        main.alignment = .leading
        main.spacing = 4
        main.translatesAutoresizingMaskIntoConstraints = false
        let sections: [(NSView, CGFloat)] = [   // (view, space after it)
            (header, 18),
            (Self.caption("Board"), 4), (boardBox, 16),
            (Self.caption("Reliability"), 4), (reliabilityBox, 16),
            (Self.caption("Advanced"), 4), (advancedBox, 14),
            (footer, 0),
        ]
        for (v, after) in sections {
            main.addArrangedSubview(v)
            if after > 0 { main.setCustomSpacing(after, after: v) }
        }
        for v in [header, boardBox, reliabilityBox, advancedBox, footer] {
            v.widthAnchor.constraint(equalTo: main.widthAnchor).isActive = true
        }

        let content = NSView()
        content.addSubview(main)
        let m = Self.margin
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalToConstant: Self.contentWidth),
            main.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: m),
            main.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),
            main.topAnchor.constraint(equalTo: content.topAnchor, constant: m),
            main.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -m),
        ])
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: Self.contentWidth, height: content.fittingSize.height))
        refresh()
    }

    // MARK: Refreshing

    /// Copies current engine and Settings values into the controls.
    private func refresh() {
        // Status header
        let note = engine.lastNoteReceived
        let cue = engine.lastCue
        if let out = engine.currentOutputName {
            cableDot.color = .systemGreen
            cableLabel.stringValue = "Connected to \(out)"
        } else {
            cableDot.color = .systemRed
            cableLabel.stringValue = "Board cable not found"
        }
        if let c = cue {
            detailLabel.stringValue = "Last cue \(c.cue) at \(timeFormatter.string(from: c.date))"
        } else if let n = note {
            detailLabel.stringValue = "Received note \(n.note) from ProPresenter at \(timeFormatter.string(from: n.date))"
        } else {
            detailLabel.stringValue = "Waiting for ProPresenter"
        }
        let noteText = note.map { "Note \($0.note) at \(timeFormatter.string(from: $0.date))" } ?? "Nothing received yet"
        let cueText = cue.map { "Cue \($0.cue) at \(timeFormatter.string(from: $0.date))" } ?? "None yet"
        detailLabel.toolTip = "From ProPresenter: \(noteText)\nLast cue sent: \(cueText)"

        // Output popup: Automatic, then hardware first, then virtual.
        outputPopup.removeAllItems()
        outputPopup.addItem(withTitle: "Automatic")
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

        loginSwitch.state = Settings.startAtLogin ? .on : .off
        restartSwitch.state = Settings.restartIfQuits ? .on : .off
        quitOptionSwitch.state = Settings.quitNeedsOption ? .on : .off

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

    @objc private func loginChanged() {
        Settings.startAtLogin = loginSwitch.state == .on
        LaunchAgent.applyStartAtLogin()
    }

    @objc private func restartChanged() {
        Settings.restartIfQuits = restartSwitch.state == .on
        Log.info("Restart if it quits set to \(Settings.restartIfQuits)")
    }

    @objc private func quitOptionChanged() {
        Settings.quitNeedsOption = quitOptionSwitch.state == .on
        Log.info("Hide Quit unless Option is held set to \(Settings.quitNeedsOption)")
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
