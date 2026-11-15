import Foundation
import CoreMIDI
import BridgeCore

// Usage:
//   SelfTest --print-ids   print the unique IDs of the running app's endpoints
//   SelfTest               end-to-end test against the running app (unit tests: scripts/test.sh)

func stringProp(_ o: MIDIObjectRef, _ k: CFString) -> String {
    var s: Unmanaged<CFString>?
    if MIDIObjectGetStringProperty(o, k, &s) == noErr, let s = s { return s.takeRetainedValue() as String }
    return ""
}
func intProp(_ o: MIDIObjectRef, _ k: CFString) -> Int32 {
    var v: Int32 = 0; MIDIObjectGetIntegerProperty(o, k, &v); return v
}

// MARK: Find endpoints

func findDestination(named name: String) -> MIDIEndpointRef? {
    for i in 0..<MIDIGetNumberOfDestinations() {
        let e = MIDIGetDestination(i)
        if stringProp(e, kMIDIPropertyName) == name { return e }
    }
    return nil
}
func findSource(named name: String) -> MIDIEndpointRef? {
    for i in 0..<MIDIGetNumberOfSources() {
        let e = MIDIGetSource(i)
        if stringProp(e, kMIDIPropertyName) == name { return e }
    }
    return nil
}

let args = CommandLine.arguments
if args.contains("--print-ids") {
    guard let d = findDestination(named: "Lights Bridge"), let s = findSource(named: "Lights Bridge Monitor") else {
        print("Could not find the endpoints. Is Lights Bridge running?"); exit(1)
    }
    print("destination 'Lights Bridge' uniqueID=\(intProp(d, kMIDIPropertyUniqueID))")
    print("source 'Lights Bridge Monitor' uniqueID=\(intProp(s, kMIDIPropertyUniqueID))")
    exit(0)
}

var client = MIDIClientRef()
MIDIClientCreate("SelfTest" as CFString, nil, nil, &client)
// CoreMIDI needs a moment to populate the endpoint list for a new client.
Thread.sleep(forTimeInterval: 0.3)

guard let dest = findDestination(named: "Lights Bridge"), let monitor = findSource(named: "Lights Bridge Monitor") else {
    print("Could not find 'Lights Bridge' / 'Lights Bridge Monitor'. Is Lights Bridge running?")
    print("FAIL"); exit(1)
}

// Collect everything the monitor mirrors.
let lock = NSLock()
var received: [[UInt8]] = []
var inPort = MIDIPortRef()
let st = MIDIInputPortCreateWithProtocol(client, "SelfTest In" as CFString, ._1_0, &inPort) { listPtr, _ in
    let packetOffset = MemoryLayout<MIDIEventList>.offset(of: \MIDIEventList.packet)!
    let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.words)!
    var p = UnsafeRawPointer(listPtr).advanced(by: packetOffset).assumingMemoryBound(to: MIDIEventPacket.self)
    for _ in 0..<listPtr.pointee.numPackets {
        let words = UnsafeRawPointer(p).advanced(by: wordsOffset).assumingMemoryBound(to: UInt32.self)
        for i in 0..<Int(p.pointee.wordCount) {
            let w = words[i]
            if let bytes = UMP.midi1Bytes(from: w) {
                lock.lock()
                received.append(bytes)
                lock.unlock()
            }
        }
        p = UnsafePointer(MIDIEventPacketNext(p))
    }
}
guard st == noErr else { print("Could not create input port (\(st))"); print("FAIL"); exit(1) }
MIDIPortConnectSource(inPort, monitor, nil)

var outPort = MIDIPortRef()
MIDIOutputPortCreate(client, "SelfTest Out" as CFString, &outPort)

// Send the way older apps do: legacy MIDISend with a MIDIPacketList.
func sendLegacy(_ bytes: [UInt8]) {
    var buffer = [UInt8](repeating: 0, count: 256)
    buffer.withUnsafeMutableBytes { raw in
        let list = raw.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self)
        let cur = MIDIPacketListInit(list)
        _ = MIDIPacketListAdd(list, 256, cur, 0, bytes.count, bytes)
        MIDISend(outPort, dest, list)
    }
    Thread.sleep(forTimeInterval: 0.2)
}

sendLegacy([0x90, 5, 100])     // Note On ch1 note 5  -> cue 5
sendLegacy([0x91, 1, 64])      // Note On ch2 note 1  -> cue 1
sendLegacy([0x90, 127, 1])     // Note On ch1 note 127 -> cue 127
sendLegacy([0x80, 5, 0])       // Note Off -> ignored
sendLegacy([0x90, 9, 0])       // Note On velocity 0 -> ignored
Thread.sleep(forTimeInterval: 0.5)

lock.lock(); let got = received; lock.unlock()
print("Received: " + got.map { Translator.describe([$0[0], $0[1]]) }.joined(separator: ", "))
let programs = got.map { Int($0[1]) }
let channelsOK = Set(got.map { $0[0] }).count <= 1 && got.allSatisfy { ($0[0] & 0xF0) == 0xC0 }
if programs == [5, 1, 127] && channelsOK {
    print("PASS"); exit(0)
} else {
    print("Expected programs [5, 1, 127] on one channel; got programs \(programs), same channel: \(channelsOK)")
    print("FAIL"); exit(1)
}
