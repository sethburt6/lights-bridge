import Foundation

/// A MIDI destination the app could send to (our own endpoint and offline ones are already filtered out).
public struct Destination: Equatable {
    public let id: Int32
    public let name: String
    /// True for a real device (USB cable), false for a virtual endpoint from another app.
    public let isHardware: Bool

    public init(id: Int32, name: String, isHardware: Bool) {
        self.id = id
        self.name = name
        self.isHardware = isHardware
    }
}

/// Decides which destination receives the Program Change messages.
public enum OutputChooser {
    /// Rules, in order:
    /// 1. A destination whose id matches the saved id.
    /// 2. Else one whose name matches the saved name.
    /// 3. Else, if nothing at all is saved (automatic), the single hardware destination if exactly one exists.
    /// 4. Else nil.
    public static func choose(from list: [Destination], savedID: Int32?, savedName: String?) -> Destination? {
        if let sid = savedID, let m = list.first(where: { $0.id == sid }) { return m }
        if let sname = savedName, let m = list.first(where: { $0.name == sname }) { return m }
        if savedID == nil && savedName == nil {
            let hw = list.filter { $0.isHardware }
            if hw.count == 1 { return hw[0] }
        }
        return nil
    }
}
