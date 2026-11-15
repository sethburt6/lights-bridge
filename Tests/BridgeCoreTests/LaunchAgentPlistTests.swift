import Testing
@testable import BridgeCore

@Suite struct LaunchAgentPlistTests {
    @Test func runAtLoadFollowsFlag() {
        #expect(LaunchAgentPlist.make(label: "a.b", executable: "/x", startAtLogin: true)["RunAtLoad"] as? Bool == true)
        #expect(LaunchAgentPlist.make(label: "a.b", executable: "/x", startAtLogin: false)["RunAtLoad"] as? Bool == false)
    }

    @Test func keepAliveIsAlwaysTrue() {
        for flag in [true, false] {
            #expect(LaunchAgentPlist.make(label: "a.b", executable: "/x", startAtLogin: flag)["KeepAlive"] as? Bool == true)
        }
    }

    @Test func labelAndProgramArguments() {
        let d = LaunchAgentPlist.make(label: "io.example.app", executable: "/Applications/App.app/Contents/MacOS/App", startAtLogin: true)
        #expect(d["Label"] as? String == "io.example.app")
        #expect(d["ProgramArguments"] as? [String] == ["/Applications/App.app/Contents/MacOS/App"])
    }

    @Test func processTypeIsInteractive() {
        #expect(LaunchAgentPlist.make(label: "a.b", executable: "/x", startAtLogin: true)["ProcessType"] as? String == "Interactive")
    }
}
