# duet-services

[![ci](https://github.com/modaal-agent/duet-services/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/modaal-agent/duet-services/actions/workflows/ci.yml)

The services, telemetry and theming layer for [Duet](https://github.com/modaal-agent/duet)-family
apps. Four Swift library products, each consumed independently, and two
Kotlin Multiplatform artifacts. Three of the Swift products and the
`telemetry` artifact resolve `duet`; `DuetTheming` declares no dependencies at
all, and the `theming` artifact resolves `kotlinx-coroutines` and nothing
else:

| product | carries |
| --- | --- |
| `DuetDiagnostics` | the structured-logging port (`DiagnosticsWorking`) and its `os.Logger`-backed worker, with crash-reporter hooks as the one backend seam |
| `DuetAppServices` | both halves of the app-services boundary: the inbound URL/notification registry worker and the app-lifecycle publisher, and the outbound worker over the system-integration ports (URL opening, pasteboard, haptics, audio session, and the tracking and push-permission prompts) |
| `DuetTelemetry` | the semantic-event grammar substrate — `TrackedEvent`/`TrackedVerb`/`TrackedParam` — the `AnalyticsTracking` port and its worker-shaped refinement `AnalyticsTrackingWorking`, and `AnalyticsTrackingWorker`, the SDK-free fan-out that pushes one enabled flag and one event stream to every vendor sink |
| `DuetTheming` | the theme engine an app's catalog plugs into: `Theme`/`Themed`/`Assetable` for declaring which color, font, image and gradient each theme has, `Appearance<T>` for covering light and dark in one entry, `ThemeProvider` for resolving a key and persisting the user's choice, and `ThemeScope`/`ThemedHostingController` for publishing it to a SwiftUI tree. iOS only |

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

`DuetTheming` goes one step further and declares **no target dependencies at
all**, not even a `duet` product: an app that wants a theme engine resolves
this package and nothing else to get one. It imports UIKit and SwiftUI, so it
is iOS-only — every file is `#if os(iOS)` whole-file, and the package's
`ios` CI lane is where it compiles and its suite runs.

`DuetTelemetry` has a Kotlin twin, `dev.modaal.duet.services:telemetry` — a
Kotlin Multiplatform artifact (jvm, iosArm64, iosSimulatorArm64, macosArm64)
published from the same release tags to the family's Maven repository. Its
commonMain carries the same grammar, encoding rule and tracking port; its
jvm side carries the same worker-typed sink surface. The two halves encode
identically by test: the fixtures under `contracts/telemetry-twin/` are
written by the Kotlin suite's encoders and decoded by the Swift suite, so a
dual-language app can declare an event once — verbs keep their stored
display spelling across the boundary — and convert crossing values
losslessly. Its dependency rule is the Swift product's: the family plus
`kotlinx-serialization`, nothing else.

A second Kotlin artifact, `dev.modaal.duet.services:theming`, carries the
platform-free theming engine — the same targets, published from the same
release tags. It holds the value types a palette entry takes — `ColorToken`,
`FontToken` and `GradientToken`, each carrying its value per appearance — the
role sets a resolved theme fills (every slot on Material's `ColorScheme` and
every slot on its `Typography`, so an app binds all of them and none falls
back to a Material default), the `DuetThemeSpec` seam an app implements over
its own token vocabulary, and the appearance-selection store.
The module compiles no Compose and names no platform colour class: an app's
palette is common code, and resolution is native — under Compose a layer in
the app's own tree turns a `ResolvedPalette` into a `ColorScheme` and a
`DuetThemeSpec` into a `Typography`; on Apple the app's own engine reads the
same values. The vocabulary stays the app's: `DuetThemeSpec` is an interface
over the app's tokens, so adding, renaming or dropping a semantic token needs
no artifact release. Its dependency rule is narrower than the telemetry
artifact's — `kotlinx-coroutines`, for the `StateFlow` the appearance store
publishes, and nothing else.

`DuetTheming` and the `theming` artifact are the two languages' theme
engines, and they are independent products: each resolves the app's own
palette natively, in the idiom of its platform — asset keys over a `Themed`
catalog on the Swift side, roles over a `DuetThemeSpec` on the Kotlin side.
Unlike the telemetry halves, they exchange no wire form, so an app links
whichever halves its platforms need and declares its palette values in each.

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

**A theme is a catalog the app declares, registered by two conformances.**
Asset keys are the app's own enums; one `Themed` subclass per theme declares
what each key resolves to; `Theme: Themeable` maps a theme to its catalog, and
`ThemeDefaults: ThemeDefaulting` names the theme an unhosted tree — an Xcode
preview, a test host — renders with:

```swift
enum ColorAsset: ColorAssetable { case background, accent }

final class DefaultThemed: Themed, Assetable {
  typealias _ColorAsset = ColorAsset
  typealias _FontAsset = EmptyAsset
  typealias _ImageAsset = EmptyAsset
  typealias _GradientAsset = EmptyAsset

  func colorSet(for asset: ColorAsset) -> ColorSet {
    switch asset {
    case .background: ColorSet(.auto(light: .white, dark: .black))
    case .accent:     ColorSet(.static(.systemBlue))
    }
  }
}

extension Theme {
  static let main = Theme(key: "main")
}

extension Theme: Themeable {
  public func themed() -> Themed { DefaultThemed() }
}

extension ThemeDefaults: ThemeDefaulting {
  public func defaultTheme() -> Theme { .main }
}
```

Both conformances are resolved by cast, so an app that declares neither traps
at its first lookup rather than failing to compile — write them beside each
other, in one file of the app target. An asset family the app has no keys for
is declared `EmptyAsset`, whose supplied implementation traps if a lookup ever
reaches it. `Appearance<T>` covers light and dark in one entry: `.static`,
`.auto(light:dark:)`, or `.dynamic` from the trait collection. For `UIColor`,
`.auto` and `.dynamic` resolve to a dynamic `UIColor` while the preferred
appearance is `.system`, so a color already handed to a view keeps following
the system setting.

**The provider is published once per SwiftUI tree, at the hosting root.** A
SwiftUI environment value does not cross a UIKit boundary, so every hosting
root takes the provider: subclass `ThemedHostingController` and hand it one,
or wrap a single tree in `ThemeScope(provider) { ... }`. A view then reads
`@Environment(\.theme)` and calls `theme.color(for: ColorAsset.accent)`; no
view takes a theming parameter, however deeply nested, and no view model
carries one on its behalf. Set hosted content through `themedRootView` —
assigning `rootView` is a compile error by design.

```swift
let themeProvider = ThemeProvider(
  persistentStorage: ThemePersistentStorage(),
  defaultTheme: .main,
  defaultPreferredAppearance: .system)
```

`ThemeProvider` is read and written from the main actor and is not
observable: `setTheme(with:)` and `setPreferredAppearance(with:)` update state
and write through `ThemeProviderPersisting` — `ThemePersistentStorage`, the
supplied implementation, stores JSON in `UserDefaults.standard` — and views
that read the provider re-render when the app invalidates them. Substitute an
app group's defaults, or an in-memory double in tests, by conforming to the
same port.

## Consuming

Reference this package by a version-pinned URL. The module names are the
import names:

```swift
import DuetAppServices
import DuetDiagnostics
import DuetTelemetry
import DuetTheming
```

The Kotlin artifact resolves from the family's Maven repository — one
repository block covers every `dev.modaal.*` artifact:

```kotlin
repositories {
  maven {
    url = uri("https://modaal-agent.github.io/maven")
    content { includeGroupByRegex("""dev\.modaal(\..*)?""") }
  }
}
dependencies {
  api("dev.modaal.duet.services:telemetry:<version>")
  api("dev.modaal.duet.services:theming:<version>")
}
```

Android consumers resolve each artifact's `-jvm` variant, which Gradle
selects from the root publication's module metadata — the coordinates above
are the only ones a build file names.

## Layout

The Swift half lives under `swift/`, with the manifest at the repository
root — SwiftPM resolves a `.package(url:)` against the root only, and the
root stays free for the other language halves.

- `swift/Sources/{DuetDiagnostics,DuetAppServices,DuetTelemetry,DuetTheming,DuetAppServicesTestSupport}`
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
- `swift/Tests/ThemingTests` — what the theming layer publishes: the provider
  handed to a hosting root reaches every view in the tree it hosts. The tests
  mount real SwiftUI trees under a `UIWindow`, so they need a simulator host —
  `scripts/test-ios.sh` builds every target for the simulator and runs them,
  and CI's `ios` job runs that same script.
- `kotlin/` — the Kotlin half: the `:telemetry` and `:theming` KMP modules,
  the Gradle wrapper, and `kotlin/scripts/publish-maven.sh`, the staging/
  atomicity/immutability gate the tag-triggered publish workflow runs.
- `contracts/telemetry-twin/` — the twin contract's fixtures: committed
  build products of the Kotlin suite (regenerate with
  `cd kotlin && ./gradlew :telemetry:jvmTest -PregenFixtures=1`), read by
  both languages' suites in CI.
