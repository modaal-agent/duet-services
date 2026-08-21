# Contributing

- **This repository is public.** Write every file, commit message, and
  generated artifact for a reader outside the project: no references to
  private repositories, internal planning documents, or the toolchains that
  consume this package — "a consuming app" or "a consuming toolchain",
  never which one.
- **Docs state the present rule, not the transition.** README sections and
  doc comments are forward-looking: state what the module does and the
  action the reader takes. Do not frame behavior as a replacement of past
  practice ("X replaces Y", "previously", "no longer"). Historical contrast
  belongs in `CHANGELOG.md` and commit messages, where the change itself is
  the subject.
- **The worker-seam shape is the API convention.** A service module ships a
  port (protocol), a default implementation, and logical tests here. Vendor
  SDKs never enter this package's dependency graph — a backend plugs in
  through a port, in the consumer's own code.
- **Every product name carries the `Duet` prefix.** A SwiftPM product name is
  global to the resolved graph and a module name is global to the file that
  imports it; a bare name like `AppServices` or `Diagnostics` collides with an
  app's own library or shadows its own type of that name. A new product is
  `Duet<Thing>`, and its source directory is named for it.
- **Test doubles never live in a product's `Sources/`, `#if DEBUG`
  included.** A DEBUG gate keeps a double out of release binaries, not out
  of the module's API surface or its compile graph. A double one test target
  uses lives in that test target; a shared double lives in the doubled
  product's `<Product>TestSupport` library, which only test targets link.
  Where the doubled port is unconditional and a consumer only needs a
  recording spy, annotate the port `sourcery: CreateMock` instead of
  hand-writing the double — the generation lane emits the spy here and in
  every consumer that runs one. Platform-conditional doubles stay
  hand-written in the TestSupport target, behind the port's own platform
  condition.
- **`DuetTelemetry`'s target dependencies stay inside the `duet` package.**
  A consumer that links only `DuetTelemetry` resolves this package and `duet`
  and nothing else, and consumers that audit their dependency closure gate on
  that. A third-party identity added to the `DuetTelemetry` target is a
  breaking change, not an implementation detail; a `duet` product is not,
  since it is already in every consumer's resolved graph.
- **Files under `Generated/` are build products.** Change the annotated
  protocol and re-run `scripts/generate-mocks.sh`; CI fails on drift
  (`--check` validates each file's fingerprint block — a stale input, a
  source file added after generation, or a hand-edit turns it red, with no
  Sourcery run). Never hand-edit a generated file.
- **`DuetTheming` declares no target dependencies.** Not a third-party one,
  and not a `duet` product either: an app that wants a theme engine resolves
  this package and nothing else to get one. A dependency added to that
  target changes what the product claims, so it is a breaking change rather
  than an implementation detail.
- **An iOS-only module is `#if os(iOS)` whole-file, and its suite runs on a
  simulator.** The `swift` CI job runs `swift test` on macOS, where a UIKit
  import does not compile: put the copyright header first, then `#if
  os(iOS)`, then the imports, so the host lane compiles the target to
  nothing. `scripts/test-ios.sh` is where those files are type-checked — it
  builds every target for a simulator destination — and where a suite that
  needs a UIKit runtime runs. Add a new simulator-hosted suite to that
  script's `-only-testing` list, and run the script before pushing; CI's
  `ios` job runs the same file.
- **Third-party source copied into this repository keeps its attribution.**
  Fourteen of the sixteen files in `swift/Sources/DuetTheming` carry a
  "Based on" line naming SwiftTheming, and `NOTICE` reproduces its MIT text
  and states that count. Editing one of those files keeps its line; adding
  or removing one updates the count in `NOTICE`.
- **The two language halves move together.** A grammar or port change in
  `swift/Sources/DuetTelemetry` lands with its Kotlin twin in
  `kotlin/telemetry` and a regenerated `contracts/telemetry-twin/` in the
  same commit — the fixtures are committed build products of the Kotlin
  suite (`cd kotlin && ./gradlew :telemetry:jvmTest -PregenFixtures=1`), and
  both CI jobs fail on drift. The Kotlin artifact holds the same dependency
  rule as `DuetTelemetry`: `dev.modaal.duet` artifacts plus
  `kotlinx-serialization`, nothing else.
- **A release cut sets the version in the commit that gets tagged** (the
  family convention — see the `duet` repo's CONTRIBUTING). One tag releases
  both halves: SwiftPM resolves the Swift products from the tag directly,
  and the publish workflow derives the Maven version from the same tag
  (`-PpublishVersion` — the `-SNAPSHOT` literal in `kotlin/build.gradle.kts`
  is the mavenLocal development default, never published).
- **Licensing**: MIT, inbound = outbound; submitting a PR means your
  contribution is licensed under the [MIT License](LICENSE).
