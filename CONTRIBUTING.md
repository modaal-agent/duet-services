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
- **A release cut sets the version in the commit that gets tagged** (the
  family convention — see the `duet` repo's CONTRIBUTING).
- **Licensing**: MIT, inbound = outbound; submitting a PR means your
  contribution is licensed under the [MIT License](LICENSE).
