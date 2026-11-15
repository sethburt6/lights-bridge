import Testing
@testable import BridgeCore

@Suite struct OutputChooserTests {
    let usb = Destination(id: 10, name: "USB MIDI Cable", isHardware: true)
    let usb2 = Destination(id: 11, name: "Other Cable", isHardware: true)
    let virt = Destination(id: 20, name: "Some Virtual", isHardware: false)

    @Test func savedIDWinsOverName() {
        let r = OutputChooser.choose(from: [usb, usb2], savedID: 10, savedName: "Other Cable")
        #expect(r == usb)
    }

    @Test func nameFallbackWhenIDMissing() {
        let r = OutputChooser.choose(from: [usb, usb2], savedID: 999, savedName: "Other Cable")
        #expect(r == usb2)
    }

    @Test func autoPicksExactlyOneHardware() {
        #expect(OutputChooser.choose(from: [virt, usb], savedID: nil, savedName: nil) == usb)
    }

    @Test func noAutoPickWithTwoHardware() {
        #expect(OutputChooser.choose(from: [usb, usb2], savedID: nil, savedName: nil) == nil)
    }

    @Test func noAutoPickWithZeroHardware() {
        #expect(OutputChooser.choose(from: [], savedID: nil, savedName: nil) == nil)
    }

    @Test func noAutoPickOfVirtualOnly() {
        #expect(OutputChooser.choose(from: [virt], savedID: nil, savedName: nil) == nil)
    }

    @Test func noAutoPickWhenSomethingSavedButMissing() {
        #expect(OutputChooser.choose(from: [usb], savedID: 999, savedName: "Gone") == nil)
        #expect(OutputChooser.choose(from: [usb], savedID: nil, savedName: "Gone") == nil)
        #expect(OutputChooser.choose(from: [usb], savedID: 999, savedName: nil) == nil)
    }
}
