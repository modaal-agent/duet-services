# Changelog

## [0.1.1] — 2026-08-17

Patch. No product API change; the package becomes resolvable by URL.

### Changed — `duet` is an exact URL pin, not a sibling checkout

`Package.swift` reaches the framework at
`https://github.com/modaal-agent/duet.git`, `exact: "0.2.1"`, with
`Package.resolved` committed. `0.1.0` declared a path dependency on
`../modaal-agent-duet`, so resolving that tag from anywhere but a sibling
layout fails; pin `0.1.1` or later.

`.github/workflows/ci.yml` drops the sibling-materialization steps and the
credential rewrite in both jobs — SwiftPM fetches the framework itself, and
`scripts/generate-mocks.sh` clones the pinned tag for sourcery's inherited
protocol requirements.

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
