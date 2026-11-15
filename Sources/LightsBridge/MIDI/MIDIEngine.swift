import Foundation
import CoreMIDI
import BridgeCore

/// All CoreMIDI work lives here.
///
/// Flow: ProPresenter -> our virtual destination "Lights Bridge" -> Translator
///       -> USB cable destination (Program Change) and also -> our virtual
///       source "Lights Bridge Monitor" (a mirror used by SelfTest).
///
/// CoreMIDI 1.0 data is carried as "UMP" 32-bit words; see `UMP` in BridgeCore for the layout.
///
/// Change notification: whenever anything the UI shows may have changed (output
/// found/lost, a note arrived, a cue was sent) the engine posts
/// `MIDIEngine.didChangeNotification` on NotificationCenter, always on the main
/// thread. The notification's `userInfo["sent"]` is `true` when a message was just
/// sent to the board (for observers that care about outgoing traffic). Any number of
/// observers (menu-bar item, Settings window) can listen without the engine knowing them.
final class MIDIEngine {

    /// Posted on the main thread when engine state changes. See the type documentation.
    static let didChangeNotification = Notification.Name("LightsBridgeEngineDidChange")

    // State read by the UI (main thread).
    private(set) var availableDestinations: [Destination] = []
    private(set) var currentOutputName: String?
    /// Last translated cue (set from the work queue, read on main).
    var lastCue: (cue: Int, date: Date)? { lock.lock(); defer { lock.unlock() }; return _lastCue }
    /// Last Note On received from any app, whether or not it was translated.
    var lastNoteReceived: (note: Int, date: Date)? { lock.lock(); defer { lock.unlock() }; return _lastNote }
    var translatedCount: Int { lock.lock(); defer { lock.unlock() }; return _translatedCount }

    private var client = MIDIClientRef()
    private var inputEndpoint = MIDIEndpointRef()
    private var monitorEndpoint = MIDIEndpointRef()
    private var outPort = MIDIPortRef()

    // Work done off the main thread. `lock` protects everything below it.
    private let workQueue = DispatchQueue(label: "io.github.sethburt6.lightsbridge.midi")
    private let lock = NSLock()
    private var translator = Translator()
    private var outputRef: MIDIEndpointRef = 0
    private var outputDisplay: String = ""
    private var _lastCue: (cue: Int, date: Date)?
    private var _lastNote: (note: Int, date: Date)?
    private var _translatedCount = 0

    // MARK: Setup

    func start() {
        var status = MIDIClientCreateWithBlock("Lights Bridge" as CFString, &client) { [weak self] note in
            switch note.pointee.messageID {
            case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved, .msgPropertyChanged:
                DispatchQueue.main.async { self?.refreshOutput() }
            default: break
            }
        }
        if status != noErr { Log.info("ERROR: MIDIClientCreate failed (\(status))"); return }

        // Input: apps send Note On here.
        status = MIDIDestinationCreateWithProtocol(client, "Lights Bridge" as CFString, ._1_0, &inputEndpoint) { [weak self] listPtr, _ in
            self?.handleIncoming(listPtr)
        }
        if status != noErr { Log.info("ERROR: creating input endpoint failed (\(status))") }
        else {
            Settings.inputUniqueID = Self.assignUniqueID(inputEndpoint, saved: Settings.inputUniqueID)
        }

        // Monitor: a mirror of everything we send (even with no hardware attached).
        status = MIDISourceCreateWithProtocol(client, "Lights Bridge Monitor" as CFString, ._1_0, &monitorEndpoint)
        if status != noErr { Log.info("ERROR: creating monitor endpoint failed (\(status))") }
        else {
            Settings.monitorUniqueID = Self.assignUniqueID(monitorEndpoint, saved: Settings.monitorUniqueID)
        }

        status = MIDIOutputPortCreate(client, "Lights Bridge Out" as CFString, &outPort)
        if status != noErr { Log.info("ERROR: MIDIOutputPortCreate failed (\(status))") }

        reloadSettings()
        refreshOutput()
        Log.info("MIDI engine started (channel \(Settings.boardChannel), cueOffset \(Settings.cueOffset))")
    }

    /// Give a virtual endpoint a stable unique ID so other apps (ProPresenter)
    /// recognise it after a restart. CoreMIDI assigns a new random ID each time
    /// an endpoint is created unless we override it. Returns the ID in use.
    private static func assignUniqueID(_ endpoint: MIDIEndpointRef, saved: Int32?) -> Int32? {
        var candidate = saved ?? Int32.random(in: 1...Int32.max)
        for _ in 0..<5 {
            let s = MIDIObjectSetIntegerProperty(endpoint, kMIDIPropertyUniqueID, candidate)
            if s == noErr { return candidate }
            if s == OSStatus(kMIDIIDNotUnique) { candidate = Int32.random(in: 1...Int32.max); continue }
            Log.info("ERROR: could not set unique ID (\(s))")
            return nil
        }
        return nil
    }

    /// Copy current settings into the lock-protected snapshot. Call on main after any change.
    func reloadSettings() {
        lock.lock()
        translator = Translator(boardChannel: Settings.boardChannel, cueOffset: Settings.cueOffset)
        lock.unlock()
    }

    // MARK: Choosing the output cable

    /// Re-reads the CoreMIDI destination list and picks the output via `OutputChooser`.
    func refreshOutput() {
        var list: [(dest: Destination, ref: MIDIEndpointRef)] = []
        for i in 0..<MIDIGetNumberOfDestinations() {
            let ep = MIDIGetDestination(i)
            if ep == 0 || ep == inputEndpoint { continue }              // never send to ourselves
            if Self.intProperty(ep, kMIDIPropertyOffline) == 1 { continue }
            var entity = MIDIEntityRef()
            let hw = MIDIEndpointGetEntity(ep, &entity) == noErr && entity != 0
            let d = Destination(id: Self.intProperty(ep, kMIDIPropertyUniqueID),
                                name: Self.stringProperty(ep, kMIDIPropertyDisplayName),
                                isHardware: hw)
            list.append((d, ep))
        }
        availableDestinations = list.map { $0.dest }

        let pick = OutputChooser.choose(from: availableDestinations,
                                        savedID: Settings.outputUniqueID,
                                        savedName: Settings.outputName)
        let chosenRef = pick.flatMap { p in list.first(where: { $0.dest == p })?.ref }

        let newName = pick?.name
        lock.lock()
        outputRef = chosenRef ?? 0
        outputDisplay = pick?.name ?? ""
        lock.unlock()
        if newName != currentOutputName {
            currentOutputName = newName
            Log.info("Output: \(newName ?? "none found")")
        }
        notifyChange(sent: false)
    }

    /// Posts `didChangeNotification` on the main thread (hops to main if needed).
    private func notifyChange(sent: Bool) {
        let post = {
            NotificationCenter.default.post(name: MIDIEngine.didChangeNotification, object: self,
                                            userInfo: ["sent": sent])
        }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
    }

    /// Remember a chosen output, or pass nil for automatic.
    func select(id: Int32?, name: String?) {
        Settings.outputUniqueID = id
        Settings.outputName = name
        Log.info("Output setting changed: \(name ?? "Automatic")")
        refreshOutput()
    }

    // MARK: Receiving

    private func handleIncoming(_ listPtr: UnsafePointer<MIDIEventList>) {
        // Collect MIDI 1.0 channel-voice messages from every packet's UMP words.
        var messages: [[UInt8]] = []
        let packetOffset = MemoryLayout<MIDIEventList>.offset(of: \MIDIEventList.packet)!
        let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.words)!
        var packet = UnsafeRawPointer(listPtr).advanced(by: packetOffset).assumingMemoryBound(to: MIDIEventPacket.self)
        for _ in 0..<listPtr.pointee.numPackets {
            let count = Int(packet.pointee.wordCount)
            let words = UnsafeRawPointer(packet).advanced(by: wordsOffset).assumingMemoryBound(to: UInt32.self)
            for i in 0..<count {
                if let bytes = UMP.midi1Bytes(from: words[i]) { messages.append(bytes) }
            }
            packet = UnsafePointer(MIDIEventPacketNext(packet))
        }
        workQueue.async { [weak self] in
            for m in messages { self?.process(m) }
        }
    }

    /// Runs on workQueue.
    private func process(_ msg: [UInt8]) {
        lock.lock(); let t = translator; lock.unlock()
        let isNoteOn = (msg[0] & 0xF0) == 0x90 && msg[2] > 0
        if isNoteOn {
            lock.lock(); _lastNote = (Int(msg[1]), Date()); lock.unlock()
        }
        guard let out = t.translate(msg) else {
            if isNoteOn { notifyChange(sent: false) }
            return
        }
        let cue = Int(out[1])
        let ok = send(out)
        lock.lock()
        _lastCue = (cue, Date()); _translatedCount += 1
        let dest = outputDisplay
        lock.unlock()
        let text: String
        if ok { text = "Cue \(cue) → \(dest) (ch \(t.boardChannel))" }
        else { text = "Note \(msg[1]) received but board cable not found" }
        Log.info("Note \(Translator.describe(msg)) -> PC \(Translator.describe(out)): \(text)")
        notifyChange(sent: ok)
    }

    // MARK: Sending

    /// Mirror to the monitor source always; send to the board if one is selected.
    /// Returns true if it was sent to a board output.
    @discardableResult
    private func send(_ pc: [UInt8]) -> Bool {
        let word = UMP.word(midi1: pc)
        let raw = UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: 8)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
        var cur = MIDIEventListInit(list, ._1_0)
        var w = word
        cur = MIDIEventListAdd(list, 256, cur, 0, 1, &w)

        if monitorEndpoint != 0 { MIDIReceivedEventList(monitorEndpoint, list) }

        lock.lock(); let dest = outputRef; lock.unlock()
        guard dest != 0 else { return false }
        let s = MIDISendEventList(outPort, dest, list)
        if s != noErr { Log.info("ERROR: MIDISendEventList failed (\(s))"); return false }
        return true
    }

    /// Sends a Program Change straight to the board (and monitor), bypassing translation.
    func sendTestCue(_ cue: Int) {
        guard (0...127).contains(cue) else { return }
        reloadSettings()
        let ch = Settings.boardChannel
        let pc: [UInt8] = [0xC0 | UInt8(ch - 1), UInt8(cue)]
        workQueue.async { [weak self] in
            guard let self = self else { return }
            let ok = self.send(pc)
            self.lock.lock(); let dest = self.outputDisplay; self.lock.unlock()
            let text = ok ? "Test cue \(cue) → \(dest) (ch \(ch))" : "Test cue \(cue) not sent: board cable not found"
            Log.info("Test PC \(Translator.describe(pc)): \(text)")
            self.notifyChange(sent: ok)
        }
    }

    // MARK: Property helpers

    private static func intProperty(_ obj: MIDIObjectRef, _ key: CFString) -> Int32 {
        var v: Int32 = 0
        MIDIObjectGetIntegerProperty(obj, key, &v)
        return v
    }
    private static func stringProperty(_ obj: MIDIObjectRef, _ key: CFString) -> String {
        var s: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(obj, key, &s) == noErr, let s = s { return s.takeRetainedValue() as String }
        return "Unknown"
    }
}
