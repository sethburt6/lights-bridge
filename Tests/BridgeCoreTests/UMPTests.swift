import Testing
@testable import BridgeCore

@Suite struct UMPTests {
    @Test func programChangeWord() {
        #expect(UMP.word(midi1: [0xC0, 5]) == 0x20C0_0500)
    }

    @Test func programChangeRoundTrip() {
        let w = UMP.word(midi1: [0xC2, 42])
        #expect(UMP.midi1Bytes(from: w) == [0xC2, 42, 0])
    }

    @Test func noteOnRoundTrip() {
        let w = UMP.word(midi1: [0x91, 60, 100])
        #expect(w == 0x2091_3C64)
        #expect(UMP.midi1Bytes(from: w) == [0x91, 60, 100])
    }

    @Test func nonType2ReturnsNil() {
        #expect(UMP.midi1Bytes(from: 0x4090_3C64) == nil)   // type 4 (MIDI 2.0)
        #expect(UMP.midi1Bytes(from: 0x1000_0000) == nil)   // type 1 (system)
        #expect(UMP.midi1Bytes(from: 0x0000_0000) == nil)   // type 0 (utility)
    }
}
