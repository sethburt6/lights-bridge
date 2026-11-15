# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-15

### Added

- Reliability section in Settings: start at login, restart automatically if it quits or crashes, and hide Quit unless Option is held. All are on by default.

### Changed

- The setup guide walks through connecting ProPresenter, creating lighting macros and adding them to slides step by step, with links to Renewed Vision's official guides, plus a reference for every setting.

## [1.0.0] - 2026-11-15

### Added

- First release.
- Translates ProPresenter MIDI Note On N into Program Change N, so slides run cues on an ETC
  Expression-family lighting board.
- Menu-bar status dot: green when working, yellow when the cable is found but nothing has come from
  ProPresenter yet, red when the board cable is not found.
- Settings window: status, output cable, MIDI channel, cue number offset and a test cue.
- Starts at login and restarts itself if it quits.
- App icon and About panel.
- Drag-to-Applications `LightsBridge.dmg` download for Intel and Apple Silicon Macs, macOS 11 or newer.
- Unit test suite, run with `swift test` (or `scripts/test.sh`).
- Setup guide, volunteer checklist, architecture document and issue templates.
