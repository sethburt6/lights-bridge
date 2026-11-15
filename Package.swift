// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LightsBridge",
    platforms: [.macOS(.v11)],
    targets: [
        // Pure logic (no CoreMIDI): note -> program change translation.
        .target(name: "BridgeCore"),
        // The menu-bar app.
        .executableTarget(name: "LightsBridge", dependencies: ["BridgeCore"]),
        // End-to-end check tool (needs the app running).
        .executableTarget(name: "SelfTest", dependencies: ["BridgeCore"]),
        // Unit tests for BridgeCore (swift-testing).
        .testTarget(name: "BridgeCoreTests", dependencies: ["BridgeCore"]),
    ]
)
