# Changelog

## [0.8.0] — 2026-08-21

`GradientToken` in the Kotlin theming engine. Every other product in the
release is byte-identical to 0.7.0, `DuetTheming` included: a consumer that
links only those re-pins with no code change.

### Added — `GradientToken` (`dev.modaal.duet.services:theming`)

A gradient's stops per appearance, as `0xAARRGGBB` values in paint order —
`auto(light:dark:)` for a wash that inverts with the page, `fixed(...)` for one
that does not. It is the third value type a palette entry takes, alongside
`ColorToken` and `FontToken`, and it closes the one shape a Kotlin palette
could not express: a colour resolved per appearance, a typeface resolved per
role, and a gradient written out by hand at the call site.

There is no gradient role and no `DuetThemeSpec` method. The role sets exist to
fill Material's slots — thirty-six on `ColorScheme`, fifteen on `Typography` —
and Material carries no gradient among them, so a gradient role would map to
nothing; an app reads a gradient from its own palette by its own semantic
token.

`DuetTheming` reaches the same value the other way. A gradient is one of its
four asset kinds, so `Appearance<Gradient>` and
`ThemeProvider.gradient(for:preferredAppearance:on:)` resolve it against the
current theme and appearance exactly as they resolve a colour. This type is the
Kotlin half of that value, for the platform whose theme has nowhere to put it.
Direction stays the call site's on both: a stop list is the whole value, and
the Compose layer in an app's tree turns it into whichever `Brush` the surface
wants.

## [0.7.0] — 2026-08-21

The theming layer, in both languages: a fourth Swift library product,
`DuetTheming`, and a second Kotlin artifact,
`dev.modaal.duet.services:theming`, the platform-free theming engine,
published to the family's Maven repository on the same targets and from the
same release tag as `telemetry`. The four products that shipped in 0.6.0 are
byte-identical; a consumer that links only those re-pins with no code change,
and a Kotlin consumer that wants only telemetry keeps the one coordinate.

### Added — the `DuetTheming` Swift product

A theme engine that takes the app's catalog by conformance. `Theme`, `Themed`
and `Assetable` declare which color, font, image and gradient each theme has,
over the app's own asset-key enums; `Appearance<T>` covers light and dark in
one entry (`.static`, `.auto(light:dark:)`, or `.dynamic` from the trait
collection — for `UIColor`, the latter two resolve to a dynamic `UIColor`
while the preferred appearance is `.system`, so a color already handed to a
view keeps following the system setting); `ThemeProvider` resolves an asset
key against the current theme and appearance and persists the user's choice
through `ThemeProviderPersisting`; and `ThemeScope` and
`ThemedHostingController` publish the provider to a SwiftUI tree, which a
view reads as `@Environment(\.theme)` without declaring a parameter.

The target declares no dependencies at all — not a third-party one, and not a
`duet` product: an app that wants a theme engine resolves this package and
nothing else to get one. It imports UIKit and SwiftUI and is iOS-only, so
every file is `#if os(iOS)` whole-file and `swift test` on macOS compiles the
target to nothing.

Fourteen of its sixteen files are derived from SwiftTheming (MIT) and carry a
"Based on" line naming it. `NOTICE`, new in this release, reproduces that
license and lists the dependencies resolved at build time.

### Added — the Kotlin theming engine artifact

`commonMain` carries the value types a palette entry takes — `ColorToken`
(`0xAARRGGBB` per appearance, `auto` or `fixed`) and `FontToken` (family,
weight, size, line height, tracking, plus the `opsz`/`SOFT`/`wdth` axes a
variable cut is pinned at) — the two role sets a resolved theme fills
(`DuetColorRole`, Material 1.3.2's thirty-six `ColorScheme` slots;
`DuetFontRole`, its fifteen `Typography` slots), the `DuetThemeSpec` seam and
its `ResolvedPalette` projection, and the appearance model (`Appearance`,
`ResolvedAppearance`, `AppearanceStore` and an in-memory default).

The module compiles no Compose and names no platform colour class. An app's
palette is common code that depends on these types, so they carry no
platform; resolution is native and lives in the consuming app. Android
consumers resolve the `-jvm` variant, the route the telemetry artifact's
Android consumers already take, so no android variant is published and the
Kotlin CI job still needs no Android SDK.

Its dependency rule is narrower than the telemetry artifact's:
`kotlinx-coroutines`, for the `StateFlow` the appearance store publishes, and
nothing else — a consumer that links only this artifact resolves it and
coroutines.

`DuetThemeSpec` keeps the token vocabulary on the app's side: the engine sees
roles and values, never the app's semantic-token enum, so adding, renaming or
dropping a token needs no artifact release. Adding or dropping a *role* does,
and is a breaking change — an app's binding is an exhaustive `when`. The
suite pins both role counts so that a change to either is deliberate.

### Changed — the publication set

`kotlin/scripts/publish-maven.sh` publishes ten coordinates per release:
`telemetry` and `theming`, each as the root publication plus `-jvm`,
`-iosarm64`, `-iossimulatorarm64` and `-macosarm64`. The atomicity assertion
covers all ten — a release stages every coordinate or writes none.

### Changed — the iOS CI lane

`scripts/test-ios.sh` builds every target for a simulator destination and
then runs `ThemingTests` on a booted simulator: those tests mount SwiftUI
trees under a `UIWindow` and assert on what a view resolved from the
environment, which needs a UIKit runtime. CI's `ios` job runs that same
script, and so covers what the previous build-only step covered plus the new
suite.

## [0.6.0] — 2026-08-21

`DuetTelemetry` gains its Kotlin twin: `dev.modaal.duet.services:telemetry`,
a Kotlin Multiplatform artifact (jvm, iosArm64, iosSimulatorArm64,
macosArm64) published to the family's Maven repository by the tag-triggered
publish workflow — one release tag now covers both halves. The Swift
products are byte-identical to 0.5.0; a Swift-only consumer re-pins with no
code change.

### Added — the Kotlin telemetry artifact

`commonMain` carries the grammar (`TrackedEvent`, `TrackedVerb`,
`TrackedParam`), the vendor-name encoding rule (`encodedName()` /
`encodedProperties()`), the wire-form serializers, and the ports
(`AnalyticsTracking`, `AnalyticsProviding`). The jvm side adds the
worker-typed sink surface — `AnalyticsTrackingWorking` and the
`AnalyticsTrackingWorker` fan-out — because `Working` lives in
`dev.modaal.duet:shells-compose`, a JVM module, and the Apple side of a
dual-language app types its sinks on the native Swift substrate and
converts crossing values app-side.

`TrackedVerb` is an open token type, matching the Swift declaration: it
stores the display spelling (`rendered`), the starter vocabulary is a set
of companion values (`TrackedVerb.Viewed`, …), an app mints its own verb in
one line, and the bare token is the wire form. An app replacing its own
copy of this substrate maps:

| was (app-local substrate) | is |
| --- | --- |
| `CompositeAnalytics(sinks, initiallyOptedOut)` | `AnalyticsTrackingWorker(sinks, isEnabled)` |
| `NoOpAnalytics()` | `AnalyticsTrackingWorker(emptyList())` |
| `analytics.setOptedOut(x)` | `analytics.setEnabled(!x)` |
| `enum class TrackedVerb(val rendered: …)` | the open token type; entry call sites (`TrackedVerb.Viewed`) compile unchanged |

The enum-to-token move changes the verb's serialized form from the entry
name to the stored display spelling — the two differ only for multi-word
verbs (`"SignedOut"` → `"Signed Out"`), and the display spelling is what
the Swift twin already encodes.

### Added — the twin contract

`contracts/telemetry-twin/` pins serialized equivalence: the Kotlin suite
declares the sample events and writes each fixture through its own encoders;
the Swift suite decodes the same files and asserts the vendor-facing name,
the property bag, and the re-encoded wire form agree. Both CI jobs gate on
the committed fixtures, so a grammar edit that lands in one language fails
the other's lane. Regenerate after a deliberate grammar change with
`cd kotlin && ./gradlew :telemetry:jvmTest -PregenFixtures=1` and commit the
diff.

## [0.5.0] — 2026-08-20

Minor, and the largest migration this package has asked for. `DuetAppServices`
renames one worker and its composite protocol and removes five types;
`DuetTelemetry` replaces the opt-out gate with an enabled flag the app owns,
and stops shipping a consent store. `DuetDiagnostics` is untouched.

| was | is |
| --- | --- |
| `AppServicesWorker()` | `InboundAppServicesWorker()` |
| `AppServicesWorking` | `InboundAppServicesWorking` |
| `NotificationCenterAppLifecycle(center:)` | `InboundAppServicesWorker()` |
| `AppActionsProviding` | compose the narrow ports (`URLOpening`, `PasteboardReading`, `PasteboardWriting`, `HapticFeedbackProviding`) |
| `SystemAppActions()`, `SystemAudioSession()` | `OutboundAppServicesWorker()` |
| `DefaultHapticFeedback()` | `OutboundAppServicesWorker()`, assigned to `\.hapticFeedback` by the composition root |
| `@Environment(\.hapticFeedback) … hapticFeedback.impactLight()` | `hapticFeedback?.impactLight()` |
| `CompositeAnalytics(sinks:initiallyOptedOut:)` | `AnalyticsTrackingWorker(sinks:isEnabled:)` |
| `NoOpAnalytics()` | `AnalyticsTrackingWorker(sinks: [])` |
| `analytics.setOptedOut(true)` | `analytics.setEnabled(false)` |
| `AnalyticsConsentStoring`, `UserDefaultsAnalyticsConsentStore` | declare and implement them in the app |

Take this version with `scripts/generate-mocks.sh`, not `--check`: the
fingerprint in a generated file records a path and a SHA-256 per scanned
input, and this cut renames files and changes contents in both
`DuetAppServices` and `DuetTelemetry`. Re-pin `duet` to 0.4.0 in the same
commit — the manifest here pins it exactly, and a consumer's generation lane
clones the pin.

### Added — `AppLifecycleObserving`, the app's own transitions as a publisher

`AppLifecycleEvent` carries the four transitions an app branches on
(`didBecomeActive`, `willResignActive`, `didEnterBackground`,
`willEnterForeground`), and `AppLifecycleObserving` publishes them. It sits
on the inbound side beside the URL and notification handlers and is consumed
differently: every subscriber gets every event, so there is no priority and
nothing to claim. The port is annotated `sourcery: CreateMock`, so a
consumer's generation lane emits the double.

`InboundAppServicesWorker` implements it. `init` takes the notification
centre to observe and a `[Notification.Name: AppLifecycleEvent]` map, both
defaulted — `.default` and UIKit's four names, so an app constructs the
worker with no arguments. The map being a parameter is what puts the mapping
on every lane this package builds on — its logical tests run on the host lane
over a private `NotificationCenter()` — and lets a host whose lifecycle
notifications carry other names use the same worker. `appLifecycle` is
`nonisolated` on the otherwise main-actor-isolated worker and builds its
merge per subscription, so an off-main subscriber reads it without a hop.

### Added — the two permission prompts, as platform-neutral ports

`AppTrackingAuthorizationRequesting.requestTrackingAuthorizationIfNeeded()`
and `PushNotificationAuthorizationRequesting.requestPushAuthorizationIfNeeded()`
name no framework type in their signatures, so a feature that asks for a
permission compiles and runs its logical tests on the host lane, over the
generated doubles, and the system alert stays behind the seam. The push port
covers the registration that produces the APNS device token
`InboundAppServicesWorker` dispatches.

### Added — both analytics ports carry `sourcery: CreateMock`

`AnalyticsTracking` and `AnalyticsTrackingWorking` are unconditional and name
no framework type, so a consumer's generation lane emits
`AnalyticsTrackingMock` and `AnalyticsTrackingWorkingMock` into its own test
target — recorders with `trackArgs`, `identifyArgs`, `resetCallCount`,
`setEnabledArgs` and a settable `isEnabled`. Take the worker-shaped one to
stand in for a vendor sink under `AnalyticsTrackingWorker(sinks:)`; take the
narrow one wherever a feature holds the port. A consumer that hand-wrote a
recording sink deletes it and takes the generated double on its next
regeneration. This package's own fan-out tests run on
`AnalyticsTrackingWorkingMock`.

### Added — `OutboundAppServicesWorker`, the outbound half of the boundary

`OutboundAppServicesWorking` composes `URLOpening`, `PasteboardReading`,
`PasteboardWriting`, `HapticFeedbackProviding`, `AudioSessionConfiguring` and
the two prompts; `OutboundAppServicesWorker` implements all of them over the
system singletons and is a `Working`, so the composition root adopts it with
the same bracket as the inbound worker and forwards it down the graph as
narrow per-capability ports. iOS-bound, and hand-written doubles are
unnecessary: each narrow port it carries has its own generated mock.

### Changed — every implementation in `DuetAppServices` lives in a worker

The module ships two concrete types, `InboundAppServicesWorker` and
`OutboundAppServicesWorker`, and each holds every implementation of the ports
its composite carries. A system call that carries a threading rule
(`UIApplication.open(_:)` and the impact generators are main-thread API) has
one home, and the isolation each call establishes is stated at the call.

- `AppServicesWorker` is `InboundAppServicesWorker`, and `AppServicesWorking`
  is `InboundAppServicesWorking`. The composite now also carries
  `AppLifecycleObserving` and `AppServiceHandling` — the composed URL and
  notification dispatch surface an app's scene and app delegates store.
- `NotificationCenterAppLifecycle` is removed; `InboundAppServicesWorker`
  publishes `appLifecycle`.
- `SystemAppActions` and `SystemAudioSession` are removed;
  `OutboundAppServicesWorker` implements their members directly.
- `AppActionsProviding` is removed. `OutboundAppServicesWorking` composes the
  four narrow ports it stood for, and an app that wants its own composite
  composes the narrow ports too.
- `DefaultHapticFeedback` is removed, and `\.hapticFeedback` is
  `HapticFeedbackProviding?` with a `nil` default. The composition root
  constructs `OutboundAppServicesWorker`, adopts it, and assigns it on the
  root view (`.environment(\.hapticFeedback, outboundAppServices)`); a call
  site spells the optionality, `hapticFeedback?.impactLight()`. An app that
  took the old default fired haptics from a value nothing owned and nothing
  tore down — assign the adopted worker and the generator calls run on the
  instance whose lifetime is the mount's.

Sources are laid out by direction: `Inbound/` and `Outbound/` each hold their
worker, and a `Protocols/` directory beside it with one port per file.

### Changed — `AnalyticsTracking` carries an enabled flag, and the app owns consent

The port declares `var isEnabled: Bool { get }` and
`func setEnabled(_ enabled: Bool)` in place of `setOptedOut(_:)`. One
polarity, and the read is a separate member from the write because the two
answer different questions: `setEnabled(_:)` pushes a value down to every
sink, `isEnabled` folds back what the sinks report, and with no sink wired
the two do not agree — a `{ get set }` property would have accepted `true`
and read back `false`.

`AnalyticsConsentStoring` and `UserDefaultsAnalyticsConsentStore` are removed.
Where the user's choice is persisted, which Settings row changes it, and
whether an analytics worker is constructed at all are app decisions, and an
app that wants the shipped behaviour back declares the two-member protocol and
its `UserDefaults` implementation in its own module: the store read
`analytics.sharing_enabled`, treated an absent key as enabled, and published
on `UserDefaults.didChangeNotification`. Default-on is only compliant when a
visible Settings disclosure names the vendor — ship that row with the vendor.

Migration at the composition root is two lines: drop the store subscription
that translated `isEnabled` into `setOptedOut(!$0)`, and call
`analytics.setEnabled(_:)` from wherever the app now holds the choice.

### Changed — the analytics fan-out is a worker, and holds no state

`CompositeAnalytics` is `AnalyticsTrackingWorker`, conforming to the new
`AnalyticsTrackingWorking: AnalyticsTracking, Working`. It stores
`let sinks: [any AnalyticsTrackingWorking]` and nothing else — no gate, no
lock, no unchecked `Sendable` conformance — so it is compiler-checked
`Sendable` rather than asserted to be. Each sink decides whether an event
leaves the device, which is where the vendor SDK's own opt-out switch already
lives; `isEnabled` folds the sinks with OR, so it reports "something is
egressing" rather than under-reporting.

`run()` parks. The composition root adopts each sink worker in its own right —
the fan-out does not bracket its sinks' lifetimes.

Constructing it seeds every sink through `setEnabled(_:)` before the
initializer returns, so no sink egresses in the window between composition and
the first flip.

A sink is now `Sendable`, which the compiler enforces: a vendor sink cannot
hold the flag as a plain `var`. Push `setEnabled(_:)` straight to the SDK's own
switch and read that switch back in `isEnabled`, or hold the flag in an
`OSAllocatedUnfairLock<Bool>` where an SDK exposes no readable one.

### Changed — the `DuetTelemetry` target takes `DuetShells`

`Working` is declared there, and `AnalyticsTrackingWorking` refines it. The
contract consumers gate on is unchanged in substance and restated in
`CONTRIBUTING.md` as what it always guaranteed: `DuetTelemetry`'s target
dependencies stay inside the `duet` package, so a consumer linking only
`DuetTelemetry` resolves this package and `duet` and nothing else. No new
package enters any consumer's graph — `duet` is already in all of them.

### Changed — the framework pin moves to `duet` 0.4.0

`Relay.bindSink(owner:)` is the surface the bump adds; `duet` 0.4.0 changes
no existing declaration, so the package compiles and its 26 tests pass with
no source edit. The generated mocks re-pin because the fingerprint records a
SHA-256 per scanned input and `Relay.swift` moved — `ServicesMocks.swift`
carries the new hash and no other line.

### Removed — `NoOpAnalytics`

`AnalyticsTrackingWorker(sinks: [])` is the same behaviour: every call is
accepted and dropped, and `isEnabled` reads `false`. Wire that in a
composition root that has no vendor yet.

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
