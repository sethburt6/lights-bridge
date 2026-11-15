import Foundation

/// Conversion between MIDI 1.0 bytes and CoreMIDI "Universal MIDI Packet" words.
///
/// Only message type 0x2 (MIDI 1.0 channel voice, group 0) is handled. The
/// 32-bit word layout is:
/// `[4 bits type=0x2][4 bits group][8 bits status][8 bits data1][8 bits data2]`
/// e.g. Program Change 5 on channel 1 = 0x20C50500.
public enum UMP {
    /// Builds a type-2, group-0 word from `[status, data1, data2?]`.
    /// A missing data byte is treated as 0 (Program Change has only one data byte).
    public static func word(midi1 bytes: [UInt8]) -> UInt32 {
        let status = bytes.indices.contains(0) ? UInt32(bytes[0]) : 0
        let d1 = bytes.indices.contains(1) ? UInt32(bytes[1] & 0x7F) : 0
        let d2 = bytes.indices.contains(2) ? UInt32(bytes[2] & 0x7F) : 0
        return 0x2000_0000 | status << 16 | d1 << 8 | d2
    }

    /// Extracts `[status, data1, data2]` from a type-2 word, or nil for any other message type.
    public static func midi1Bytes(from word: UInt32) -> [UInt8]? {
        guard (word >> 28) == 0x2 else { return nil }
        return [UInt8((word >> 16) & 0xFF), UInt8((word >> 8) & 0x7F), UInt8(word & 0x7F)]
    }
}
