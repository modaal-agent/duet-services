# Changelog

## Unreleased

Additive. No existing declaration changes, so a consumer takes this version
with no edit; the entries below are surface a consumer opts into.

### Added — `AppLifecycleObserving`, the app's own transitions as a publisher

`AppLifecycleEvent` carries the four transitions an app branches on
(`didBecomeActive`, `willResignActive`, `didEnterBackground`,
`willEnterForeground`), and `AppLifecycleObserving` publishes them. It sits
on the inbound side beside the URL and notification handlers and is consumed
differently: every subscriber gets every event, so there is no priority and
nothing to claim. The port is annotated `sourcery: CreateMock`, so a
consumer's generation lane emits the double.

`NotificationCenterAppLifecycle` is the default. It takes the notification
centre to observe and a `[Notification.Name: AppLifecycleEvent]` map, and
`init(center:)` fills in UIKit's four names. The map being a parameter is
what puts the mapping on every lane this package builds on — its logical
tests run on the host lane over a private `NotificationCenter()` — and lets a
host whose lifecycle notifications carry other names use the same type.

### Added — the two permission prompts, as platform-neutral ports

`AppTrackingAuthorizationRequesting.requestTrackingAuthorizationIfNeeded()`
and `PushNotificationAuthorizationRequesting.requestPushAuthorizationIfNeeded()`
name no framework type in their signatures, so a feature that asks for a
permission compiles and runs its logical tests on the host lane, over the
generated doubles, and the system alert stays behind the seam. The push port
covers the registration that produces the APNS device token
`AppServicesWorker` dispatches.

### Added — `OutboundAppServicesWorker`, the outbound half of the boundary

`OutboundAppServicesWorking` composes `AppActionsProviding` (URL opening,
pasteboard, haptics), `AudioSessionConfiguring` and the two prompts;
`OutboundAppServicesWorker` implements it over the system singletons and is
a `Working`, so the composition root adopts it with the same bracket as the
inbound registry worker and forwards it down the graph as narrow
per-capability ports. iOS-bound, and hand-written doubles are unnecessary:
each narrow port it carries has its own generated mock.

Its URL, pasteboard, haptic and audio members forward to `SystemAppActions`
and `SystemAudioSession`, which gain `Sendable` conformances — both hold no
state, so the worker stores one of each rather than repeating the
main-thread discipline those calls require.

## [0.4.0] — 2026-08-20

Minor. Every consumer edits its import lines and its manifest product
entries; no port, default, worker, or type name changed, so nothing beyond
those two edits moves.

| was | is |
| --- | --- |
| `import Telemetry` | `import DuetTelemetry` |
| `import Analytics` | `import DuetTelemetry` |
| `import AppServices` | `import DuetAppServices` |
| `import Diagnostics` | `import DuetDiagnostics` |
| `import AppServicesTestSupport` | `import DuetAppServicesTestSupport` |

A manifest's `.product(name:package:)` entries take the same names. A file
that imported both `Analytics` and `Telemetry` keeps one import line.

### Changed — every product carries the `Duet` prefix

A SwiftPM product name is global to the resolved graph and a module name is
global to the file that imports it. `Analytics`, `AppServices`,
`Diagnostics` and `Telemetry` are names an app wants for its own libraries,
and `Diagnostics` additionally shadowed this package's own `Diagnostics`
protocol in any file importing the module (`Diagnostics.LogLevel` resolved
the leading name to the protocol). The products are `DuetDiagnostics`,
`DuetAppServices`, `DuetAppServicesTestSupport` and `DuetTelemetry`; each
source directory is named for its product.

### Changed — the consent store ships in `DuetTelemetry`

`AnalyticsConsentStoring` and `UserDefaultsAnalyticsConsentStore` are the
opt-out gate for the analytics pipeline whose ports and sinks
`DuetTelemetry` already carries, and the two shipped together in every
consumer. They move into `DuetTelemetry`; the `Analytics` product retires.
The types are unchanged, including the `sourcery: CreateMock` and
`sourcery: subject = "CurrentValue"` annotations, so a generated
`AnalyticsConsentStoringMock` is the same class under a new import.
`DuetTelemetry`'s dependency-free contract holds — the consent store uses
Foundation and Combine only.

### Changed — the Swift half lives under `swift/`

Sources are at `swift/Sources/<Product>` and tests at `swift/Tests/<Target>`,
with the manifest still at the repository root: SwiftPM resolves a
`.package(url:)` against the root only, and the root is where the package's
other language halves attach.

A consumer's mock-generation lane derives this repo's scan roots from the
manifest, and reading `swift/Sources` has a toolchain floor: `duet` 0.17.0.
Below it the derivation looks for `Sources` alone, contributes no roots for
this package, and mocks over the ports declared here generate incomplete —
which surfaces in the consumer's test target as "does not conform to
protocol". Bump `parity/duet-tools.ref` to 0.17.0 in the same commit that
takes this version. Generated files carrying this repo's paths in their
fingerprint input lists re-pin on the next regeneration, so run generation
rather than `--check` on that bump.

## [0.3.0] — 2026-08-19

Minor. Two migration steps, both tests-only — production targets are
unaffected (no port, default, or worker moved):

- A test that used `FakeAudioSession` links the new `AppServicesTestSupport`
  product on its TEST target and imports it.
- A test that used any other shipped fake switches to the mock its own
  generation lane emits from this package's annotated ports
  (`URLHandlingMock`, `PasteboardWritingMock`, `AnalyticsConsentStoringMock`,
  …), or keeps a private copy of the removed class in its test target.

### Changed — one hand-written double, in a TestSupport product; every other double is generated

A test double in a product's `Sources/` rode `#if DEBUG`, which keeps it out
of release binaries but not out of the module's API surface or its compile
graph. The package now ships exactly one hand-written double —
`FakeAudioSession`, in the `AppServicesTestSupport` library product that
only test targets link, under the port's own `#if os(iOS)` condition. It is
hand-written because it cannot be generated: the generated mocks file is
unconditional, and the macOS host lane cannot compile a mock over iOS-only
types. A planned mock-template extension (platform-conditional ports,
`@available` members) retires it.

### Changed — `AnalyticsConsentStoring.isEnabledPublisher` carries `sourcery: subject = "CurrentValue"`

Generated mocks for the consent store now back the publisher with a seeded
`CurrentValueSubject`, so a double reproduces the port's
emit-current-value-on-subscribe contract out of the box. Drive subsequent
emissions in a test through `isEnabledPublisherSubject.send(_:)`.

### Removed — `FakeAnalyticsConsentStore`, `FakeURLHandler`, `FakePasteboard`, `RecordingURLOpener`, `RecordingHapticFeedback`

All five doubled unconditional annotated ports, and the generated mocks are
the doubles for those: closure stubs carry a claim predicate
(`canHandleOpenUrlHandler`), the args arrays carry the recording, and the
seeded subject above carries the consent store's subscribe-time emission.
This package's own suite runs on its generated mocks for exactly these
ports.

## [0.2.0] — 2026-08-18

Minor. One migration step applies to EVERY existing consumer: call
`handlersDidRegister()` from your ingress worker (second entry below). An
app that re-pins without adding the call compiles clean and never dispatches
an inbound URL or device token again — the worker buffers them waiting for a
signal that never comes. Three changes are source-breaking where named:
exhaustive verb switches (first entry), `AppServicesRegistering` conformers
(second), and `AudioSessionConfiguring` conformers, hand-written audio
doubles included (third). All of it came out of adopting this package in an
existing duet app, which was already running shapes the package did not.

### Changed — `TrackedVerb` is an open token type, so the vocabulary is the app's

`TrackedVerb` was a closed enum carrying a starter set. An app cannot add a
case to an enum in a linked module, so every app's taxonomy was capped at this
package's list — and a kmp-flavored app, whose reducers mint verbs in Kotlin,
could not carry a Kotlin verb across the language boundary at all. It is a
`RawRepresentable` struct now: the same starter verbs ship as static members,
and an app adds its own in one line
(`extension TrackedVerb { static let shared = TrackedVerb("Shared") }`).

- **The token is the whole story** — identity (`TrackedVerb("Completed") ==
  .completed`), wire form (a verb encodes as the bare token string), and the
  vendor-facing spelling (`encodedName()` splices the token after the
  subject). `rendered` is REMOVED: with an open type each verb is minted
  spelled exactly as a dashboard should read it (`TrackedVerb("Signed
  Out")`), so there is nothing to derive and no second table. A
  dual-language app's converter picks the crossing token from the Kotlin
  declaration's display name — one declaration is the spelling's source on
  both platforms.
- Starter set: nine single-word tokens are unchanged; `signedOut`'s token is
  now `"Signed Out"` (0.1.x encoded it as `"SignedOut"` and derived the
  display spelling).
- Migration: replace `verb.rendered` with `verb.rawValue`; an exhaustive
  `switch` over verbs (one without a `default` arm) no longer compiles —
  compare against the members or add a `default`. Call sites
  (`verb: .completed`), `TrackedEvent` construction and `encodedName()` are
  source-compatible.

### Added — `AppServicesWorker` holds inbound events until registration completes

Handler registration is asynchronous — it rides the ingress worker's `run()`,
which `StoreHost.adopt` starts on its own task — while a scene's cold-launch
drain is synchronous, so a launch-tapped universal link reached an empty
registry and was dropped. The worker now buffers inbound URLs (capped at 8;
overflow is dropped with a log line) and the APNS device token (last one wins)
until the new `AppServicesRegistrationSettling.handlersDidRegister()` reports
the registration burst complete, then dispatches the buffer in arrival order
against the full priority-ordered registry — so a high-priority handler
registered late in the burst still out-ranks a catch-all registered early. The
signal is idempotent and one-way.

`AppServicesRegistering` inherits the new protocol on both platform branches.

- **An adopting app must make that call** from its ingress worker, after the
  registration burst. Without it, inbound URLs stay in the buffer.
- Unclaimed URLs are logged now (scheme and host only — a link's path is where
  a token rides).
- The buffered device token drains against the notification registry as it
  stood when the burst completed (a snapshot, like the URL half); draining
  with zero notification handlers logs the drop.

### Changed — `AudioSessionConfiguring`'s permission members move to the iOS 17 API

`recordPermission` and `requestRecordPermission` were spelled on
`AVAudioSession.RecordPermission`, deprecated since iOS 17, so every consumer
conformed to a deprecated API — and an app that builds with warnings as errors
could not adopt the port at all. They now use `AVAudioApplication`, carrying
`@available(iOS 17, *)`: this package keeps its iOS 16 floor, an app whose
deployment target is 17 or higher conforms and calls with no annotation of its
own, and the handler is `@Sendable` (it arrives off the main thread).

- Migration for every conformer: change the permission type to
  `AVAudioApplication.recordPermission` and add `@Sendable` to the handler
  parameter. A conformer whose own deployment floor is below iOS 17 also
  annotates the two members `@available(iOS 17, *)`.

### Added — `FakeAudioSession`

An in-memory `AudioSessionConfiguring` beside the other fakes (DEBUG-only,
iOS-only like the port): records activations, answers a fixed permission
state. Construction is availability-free (`FakeAudioSession()`); the
permission-typed initializer is iOS 17+. The port is platform-conditional and
therefore not mock-generated, so until now every consumer hand-wrote this
double.

### Added — CI compiles the iOS-only surface

`ci.yml` gains an iOS Simulator build job: `swift test` runs on macOS, so the
`#if os(iOS)` files — the audio-session port, `FakeAudioSession`, the APNS
half of `AppServicesWorker` — were compiled by no lane of this repo.

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

## [0.1.0] — 2026-08-16

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
