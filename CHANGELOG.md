# Changelog

## [0.1.0] — 2026-08-17

**This is a `0.x` line.** Minor releases may break API while the package
stabilises; patch releases stay source-compatible. At publication, pin with
`.upToNextMinor(from:)` rather than `from:` — SwiftPM reads `from: "0.1.0"`
as `0.1.0 ..< 1.0.0`, which would accept a breaking `0.2.0` without asking.

- Initial package: four library products — `Diagnostics` (structured-logging
  port + `os.Logger`-backed worker with crash-reporter hooks), `Analytics`
  (defaults-backed consent store), `AppServices` (inbound-URL/notification
  registry worker + system-integration ports), and `Telemetry` (the
  semantic-event grammar substrate; its target is dependency-free by
  contract). iOS 16 / macOS 13 floors, complete concurrency checking under
  the Swift 5 language mode.
