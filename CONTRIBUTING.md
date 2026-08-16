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
  port (protocol), a default implementation, a fake for consumers' tests,
  and logical tests here. Vendor SDKs never enter this package's dependency
  graph — a backend plugs in through a port, in the consumer's own code.
- **`Telemetry` declares no target dependencies.** Consumers gate on that
  emptiness; a dependency added to the `Telemetry` target is a breaking
  change, not an implementation detail.
- **Files under `Generated/` are build products.** Change the annotated
  protocol and re-run `scripts/generate-mocks.sh`; CI fails on drift
  (`--check`). Never hand-edit a generated file.
- **A release cut sets the version in the commit that gets tagged** (the
  family convention — see the `duet` repo's CONTRIBUTING).
- **Licensing**: MIT, inbound = outbound; submitting a PR means your
  contribution is licensed under the [MIT License](LICENSE).
