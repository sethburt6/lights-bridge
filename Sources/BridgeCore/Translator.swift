import Foundation

/// Translates MIDI Note On messages into Program Change messages.
/// This type is pure (no CoreMIDI) so it can be unit tested easily.
public struct Translator {
    /// Board MIDI channel, 1...16 (values outside are clamped).
    public var boardChannel: Int { didSet { boardChannel = Translator.clamp(boardChannel) } }
    /// Added to the note number to get the cue number. Normally 0.
    public var cueOffset: Int

    public init(boardChannel: Int = 1, cueOffset: Int = 0) {
        self.boardChannel = Translator.clamp(boardChannel)
        self.cueOffset = cueOffset
    }

    private static func clamp(_ c: Int) -> Int { min(16, max(1, c)) }

    /// Input: one MIDI 1.0 message as bytes [status, d1, d2?].
    /// Returns [0xC0 | (boardChannel-1), cue] or nil if the message should be ignored.
    public func translate(_ msg: [UInt8]) -> [UInt8]? {
        guard msg.count >= 3 else { return nil }
        // Only Note On (0x9n) with velocity > 0, on any input channel.
        // Note On with velocity 0 means Note Off in MIDI, so it is ignored.
        guard (msg[0] & 0xF0) == 0x90, msg[2] > 0 else { return nil }
        let cue = Int(msg[1]) + cueOffset
        guard (0...127).contains(cue) else { return nil }
        let ch = Translator.clamp(boardChannel)
        return [0xC0 | UInt8(ch - 1), UInt8(cue)]
    }

    /// Hex text for logs, e.g. "C0 05".
    public static func describe(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
