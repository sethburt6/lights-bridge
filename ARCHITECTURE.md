# Architecture

Notes for future maintainers. The app is small (about 1,300 lines of Swift) and uses only Apple
frameworks (Foundation, AppKit, CoreMIDI, os).

## Data flow

```
ProPresenter
    |  MIDI Note On N
    v
virtual destination "Lights Bridge"     (created by MIDIEngine)
    |  UMP words
    v
UMP decode  ->  Translator  ->  Program Change N (board channel, plus cue offset)
                                     |
                  +------------------+-------------------+
                  v                                      v
        USB-MIDI cable destination          virtual source "Lights Bridge Monitor"
        (the board's MIDI IN)               (a mirror used by SelfTest)
```

Only Note On with velocity above 0 produces output. Everything else is dropped.

## Source files

| File | Job |
|------|-----|
| `Sources/BridgeCore/UMP.swift` | Converts between MIDI 1.0 bytes and CoreMIDI Universal MIDI Packet words. |
| `Sources/BridgeCore/Translator.swift` | Pure logic: Note On N becomes Program Change N, applying the board channel and cue offset. |
| `Sources/BridgeCore/OutputChooser.swift` | Pure logic: picks which MIDI destination receives output (saved id, then saved name, then the single hardware cable). |
| `Sources/LightsBridge/App/main.swift` | Starts NSApplication as a menu-bar-only app (no Dock icon). |
| `Sources/LightsBridge/App/AppDelegate.swift` | Startup wiring, plus the developer flags. |
| `Sources/LightsBridge/MIDI/MIDIEngine.swift` | All CoreMIDI code: virtual endpoints, receiving, sending, output selection, last-cue tracking. |
| `Sources/LightsBridge/System/LaunchAgent.swift` | Installs and loads the per-user launchd agent; insists the app lives in /Applications. |
| `Sources/LightsBridge/System/Log.swift` | Logs to the unified log and `~/Library/Logs/LightsBridge.log`. |
| `Sources/LightsBridge/System/Settings.swift` | UserDefaults-backed settings, and `AppInfo` (version, setup guide link). |
| `Sources/LightsBridge/UI/StatusItemController.swift` | The menu-bar item (colored dot plus "Lights": green working, yellow waiting, red cable not found) and its menu, including the Option-only Quit. |
| `Sources/LightsBridge/UI/SettingsWindowController.swift` | The Settings window: status, output, MIDI channel, cue offset, test cue. |
| `Sources/SelfTest/main.swift` | End-to-end check tool that talks to the running app over CoreMIDI. |
| `Tests/BridgeCoreTests/` | Unit tests for BridgeCore (swift-testing). |
| `scripts/build.sh` | Builds the universal app and `dist/LightsBridge.dmg`. |
| `scripts/test.sh` | Runs `swift test` (see Testing). |
| `scripts/release-notes.sh` | Builds the GitHub release page text from CHANGELOG.md and docs/RELEASE_NOTES.md. |
| `scripts/make-icon.swift` | Generates the app icon files in `Resources/`. |

## Key decisions

- **Apple frameworks only.** No packages to go stale, so the app keeps building years from now with
  nobody maintaining it.
- **Stable virtual endpoint unique IDs.** The app saves the unique IDs of its virtual endpoints and
  reuses them at every launch, so ProPresenter remembers the "Lights Bridge" device across restarts and
  updates. Use `swift run SelfTest --print-ids` to see them.
- **LaunchAgent with KeepAlive, and the Option-only Quit.** A launchd agent starts the app at login and
  restarts it if it quits or crashes, because nobody is watching it on Sunday morning. The Quit item is
  hidden unless Option is held, so it is hard to hit by accident. Opening a new copy after an update
  restarts the running one.
- **BridgeCore is pure and unit tested.** Everything that decides what goes to the board has no CoreMIDI
  or AppKit dependency, so it is covered by fast tests.
- **Ad-hoc signing, no developer account.** `codesign --sign -` is free and has no yearly renewal. The
  cost is a one-time "Open Anyway" approval for each new install, which the docs explain.

## Testing

- `scripts/test.sh` runs the unit tests. With full Xcode this is plain `swift test`. The Command Line
  Tools ship swift-testing in a directory SwiftPM does not search by default, so the script passes the
  framework paths explicitly. CI uses this script.
- End-to-end: run the app in dev mode, then run SelfTest against it.

```
LIGHTSBRIDGE_DEV=1 .build/debug/LightsBridge &
swift run SelfTest
```

## Releasing

1. Change the number in `VERSION`.
2. Add a section for it to `CHANGELOG.md`.
3. Commit and push to main.
4. `git tag vX.Y.Z && git push origin vX.Y.Z`

GitHub Actions checks that the tag matches `VERSION`, builds the dmg, and publishes the release page.
The page text is the CHANGELOG section followed by `docs/RELEASE_NOTES.md`.

## Developer flags

These work only when the environment variable `LIGHTSBRIDGE_DEV=1` is set. In dev mode the LaunchAgent
logic is skipped, so the app runs from anywhere without installing anything.

| Flag | Effect |
|------|--------|
| `LIGHTSBRIDGE_DEV=1` | Dev mode: no LaunchAgent, no /Applications check. |
| `--open-settings` | Opens the Settings window at launch. |
| `--snapshot-settings <png>` | Opens Settings, saves a PNG of it, and quits. |
