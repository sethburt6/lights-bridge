import Testing
@testable import BridgeCore

@Suite struct TranslatorTests {
    @Test func channel1Note5() { #expect(Translator(boardChannel: 1).translate([0x90, 5, 100]) == [0xC0, 5]) }
    @Test func channel3OnInputChannel2() { #expect(Translator(boardChannel: 3).translate([0x91, 5, 100]) == [0xC2, 5]) }
    @Test func velocityZeroIgnored() { #expect(Translator().translate([0x90, 5, 0]) == nil) }
    @Test func noteOffIgnored() { #expect(Translator().translate([0x80, 5, 64]) == nil) }
    @Test func controlChangeIgnored() { #expect(Translator().translate([0xB0, 7, 100]) == nil) }
    @Test func note0() { #expect(Translator().translate([0x90, 0, 100]) == [0xC0, 0]) }
    @Test func offsetMinus1Note1() { #expect(Translator(cueOffset: -1).translate([0x90, 1, 100]) == [0xC0, 0]) }
    @Test func offsetMinus1Note0() { #expect(Translator(cueOffset: -1).translate([0x90, 0, 100]) == nil) }
    @Test func offsetPlus1Note127() { #expect(Translator(cueOffset: 1).translate([0x90, 127, 100]) == nil) }
    @Test func channel16() { #expect(Translator(boardChannel: 16).translate([0x90, 5, 100]) == [0xCF, 5]) }
    @Test func channel0Clamps() { #expect(Translator(boardChannel: 0).translate([0x90, 5, 100]) == [0xC0, 5]) }
    @Test func channel17Clamps() { #expect(Translator(boardChannel: 17).translate([0x90, 5, 100]) == [0xCF, 5]) }
    @Test func shortMessageIgnored() { #expect(Translator().translate([0x90, 5]) == nil) }
    @Test func describe() { #expect(Translator.describe([0xC0, 0x05]) == "C0 05") }
}
