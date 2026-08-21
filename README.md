# duet-services

[![ci](https://github.com/modaal-agent/duet-services/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/modaal-agent/duet-services/actions/workflows/ci.yml)

The services and telemetry layer for [Duet](https://github.com/modaal-agent/duet)-family
apps; depends on `duet`. Three library products, each consumed independently:

| product | carries |
| --- | --- |
| `DuetDiagnostics` | the structured-logging port (`DiagnosticsWorking`) and its `os.Logger`-backed worker, with crash-reporter hooks as the one backend seam |
| `DuetAppServices` | both halves of the app-services boundary: the inbound URL/notification registry worker and the app-lifecycle publisher, and the outbound worker over the system-integration ports (URL opening, pasteboard, haptics, audio session, and the tracking and push-permission prompts) |
| `DuetTelemetry` | the semantic-event grammar substrate — `TrackedEvent`/`TrackedVerb`/`TrackedParam` — the `AnalyticsTracking` port and its worker-shaped refinement `AnalyticsTrackingWorking`, and `AnalyticsTrackingWorker`, the SDK-free fan-out that pushes one enabled flag and one event stream to every vendor sink |

Every product carries the `Duet` prefix. A SwiftPM product name is global to
the resolved graph and a module name is global to the file that imports it,
so the prefix is what lets an app name its own library `AppServices`, or its
own protocol `Diagnostics`, and still link this package.

The service modules follow the worker-seam shape — port + default + logical
tests — and ship ready to adopt on a `StoreHost` at the composition root.
Test doubles are generated, not shipped: every unconditional port is
annotated `sourcery: CreateMock`, so a consumer's mock-generation lane emits
the doubles into its own test target. The one exception is the iOS-only
audio-session port, whose hand-written `FakeAudioSession` ships in the
`DuetAppServicesTestSupport` library — a product only test targets link. No vendor SDK is declared anywhere in this package: an app picks its
analytics or crash backend by conforming to a port in one file of its own.

`DuetTelemetry` is **third-party-free by contract**: a package that links
only `DuetTelemetry` resolves this package and `duet` and nothing else.
Consumers that audit their dependency closure gate on that.

The contracts an adopting app works with directly:

**The verb vocabulary is the app's.** `TrackedVerb` is a token type, not a
closed enum, and the verbs it declares are a starting point. An app adds its
own wherever it needs them — in a feature package, or app-side — and they are
first-class from that line on:

```swift
public extension TrackedVerb {
  static let shared = TrackedVerb("Shared")
}
```

`rawValue` is the token, and the token is the whole story: identity, wire
form, and the vendor-facing spelling (`encodedName()` splices it after the
subject) — mint it spelled exactly as a dashboard should read it
(`TrackedVerb("Signed Out")`).

**A vendor sink is a worker, and consent is the app's.** Conform one file to
`AnalyticsTrackingWorking`, import the SDK there and nowhere else, and adopt
it on the host. Wire the sinks into `AnalyticsTrackingWorker(sinks:isEnabled:)`
and hand the fan-out down the graph as `AnalyticsTracking`:

```swift
let analytics = AnalyticsTrackingWorker(sinks: [amplitude, postHog],
                                        isEnabled: userChoice)
host.adopt(analytics)
```

`setEnabled(_:)` reaches every sink; `isEnabled` reports whether any sink is
still egressing. Neither one persists anything — where the user's choice is
stored, which Settings row changes it, and whether an analytics worker is
constructed at all are the app's to decide. `AnalyticsTrackingWorker(sinks: [])`
is the working default until a vendor is picked: every call is accepted and
dropped.

A sink is `Sendable`, so it cannot hold the flag as a plain `var`. Push
`setEnabled(_:)` straight to the SDK's own opt-out switch and read that switch
back in `isEnabled` — the flag has to reach the SDK regardless, so it stops
its own background egress.

**`InboundAppServicesWorker` buffers inbound events until registration completes.**
Handlers register asynchronously (from the ingress worker's `run()`, started
by `StoreHost.adopt` on its own task) while a scene's cold-launch drain is
synchronous, so the worker holds inbound URLs and the APNS device token until
the registrar calls `handlersDidRegister()`, then dispatches them against the
complete, priority-ordered registry. **The app's ingress worker must make that
call** — without it a launch-tapped universal link waits in the buffer instead
of reaching a handler.

**The boundary has two workers, and the composition root adopts both.**
`InboundAppServicesWorker` takes what the system sends the app — inbound URLs,
the APNS device token and payloads, and the four lifecycle transitions, which
it publishes on `appLifecycle`. `OutboundAppServicesWorker` carries what the
app asks of the system — opening a URL, the pasteboard, haptics, the audio
session, and the tracking and push-permission prompts. Adopt each on the host
(`host.adopt(...)`) and forward it down the graph as narrow per-capability
ports, so a node that opens a URL takes `URLOpening` and its double implements
one method.

Every implementation in this module lives in one of those two workers. A
capability arrives as a narrow port beside `URLOpening` or `URLHandling`,
composed into `OutboundAppServicesWorking` or `InboundAppServicesWorking` and
implemented in the worker behind it — not as a separate class the worker
forwards to.

**The SwiftUI haptics value is assigned, not defaulted.** `\.hapticFeedback`
is `HapticFeedbackProviding?` and defaults to `nil`, because the adopted
`OutboundAppServicesWorker` is this module's only implementation. Construct
it, adopt it, and assign it on the root view:

```swift
let outboundAppServices = OutboundAppServicesWorker()
host.adopt(outboundAppServices)
rootView.environment(\.hapticFeedback, outboundAppServices)
```

A view spells the optionality — `hapticFeedback?.impactLight()` — which fires
in the app and does nothing in a preview, where there is no composition root
and so no worker to reach.

## Consuming

Reference this package by a version-pinned URL. The module names are the
import names:

```swift
import DuetAppServices
import DuetDiagnostics
import DuetTelemetry
```

## Layout

The Swift half lives under `swift/`, with the manifest at the repository
root — SwiftPM resolves a `.package(url:)` against the root only, and the
root stays free for the other language halves.

- `swift/Sources/{DuetDiagnostics,DuetAppServices,DuetTelemetry,DuetAppServicesTestSupport}`
  — one directory per product, named for it.
- `swift/Sources/DuetAppServices/{Inbound,Outbound}` — one directory per
  direction, each holding its worker and a `Protocols/` directory with one
  port per file.
- `swift/Tests/ServicesTests` — the logical tests for the diagnostics and
  app-services modules, over generated mocks
  (`swift/Tests/ServicesTests/Generated/` — build products, regenerated by
  `scripts/generate-mocks.sh`, never hand-edited).
- `swift/Tests/TelemetryTests` — the grammar substrate's encoding-rule pins,
  compiled against `DuetTelemetry` alone.
