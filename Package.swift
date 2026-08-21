// swift-tools-version:5.9

// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import PackageDescription

// The services and telemetry layer for duet-family apps. Every product carries
// the `Duet` prefix: a SwiftPM product name is global to the resolved graph and
// a module name is global to the file that imports it, so an app is free to
// name its own library `AppServices` or its own protocol `Diagnostics` without
// colliding with this package.
//
// Three products, each consumed independently:
//
//   DuetDiagnostics   the structured-logging port and its worker
//   DuetAppServices   the two app-services workers — inbound (URL and
//                     notification registry, lifecycle transitions) and
//                     outbound (URL opening, pasteboard, haptics, audio
//                     session, permission prompts) — and their ports
//   DuetTelemetry     the semantic-event grammar substrate — the event product
//                     type, the tracking port, the SDK-free fan-out and no-op
//                     sinks — plus the consent store that gates egress from
//                     them. Its target depends on nothing: a consumer that
//                     links only DuetTelemetry adds no third-party code to its
//                     resolved graph beyond this package and `duet`.
//
// plus DuetAppServicesTestSupport, the TestSupport library carrying the one
// hand-written double (`FakeAudioSession` — its port is iOS-only, so no
// mock can be generated for it). Only TEST targets link a TestSupport
// product; production targets never declare one, which is what keeps the
// double out of release binaries and out of the products' API surface.
// Every unconditional port is annotated `sourcery: CreateMock` instead:
// consumers generate their doubles into their own test targets.
//
// The service modules follow the worker-seam shape (port + default + logical
// tests, with shared doubles in the product's TestSupport library); an app
// picks a vendor by conforming to a port in one file, never by a dependency
// declared here.
//
// The manifest sits at the REPO ROOT with sources under `swift/` — the shape
// the `duet` repo uses. SwiftPM resolves `.package(url:)` against the
// repository root only, and the root stays free for the Kotlin half.

// Complete concurrency checking under the Swift 5 language mode, matching the
// `duet` framework's posture: `Sendable` conformances and actor isolation are
// compiler-checked in every module.
let strictConcurrency: [SwiftSetting] = [
  .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
  name: "duet-services",
  // iOS for the app graph; macOS so consumers' host-lane `swift test` runs
  // build the platform-neutral halves as plain host code (platform-bound
  // defaults are whole-file-guarded).
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
  ],
  products: [
    .library(name: "DuetDiagnostics", targets: ["DuetDiagnostics"]),
    .library(name: "DuetAppServices", targets: ["DuetAppServices"]),
    .library(name: "DuetAppServicesTestSupport", targets: ["DuetAppServicesTestSupport"]),
    .library(name: "DuetTelemetry", targets: ["DuetTelemetry"]),
  ],
  dependencies: [
    // The duet framework, pinned EXACTLY: pre-1.0 minors are breaking by
    // family convention, so an upgrade is a deliberate re-pin commit rather
    // than a floating range.
    .package(url: "https://github.com/modaal-agent/duet.git", exact: "0.4.0")
  ],
  targets: [
    .target(
      name: "DuetDiagnostics",
      dependencies: [
        .product(name: "DuetShells", package: "duet")
      ],
      path: "swift/Sources/DuetDiagnostics",
      swiftSettings: strictConcurrency
    ),
    .target(
      name: "DuetAppServices",
      dependencies: [
        .product(name: "DuetShells", package: "duet")
      ],
      path: "swift/Sources/DuetAppServices",
      swiftSettings: strictConcurrency
    ),
    // The one shared hand-written double (see the product note above). Its
    // compile gate is the iOS package build: the macOS host lane compiles
    // the target to nothing, `#if os(iOS)` whole-file.
    .target(
      name: "DuetAppServicesTestSupport",
      dependencies: [
        .target(name: "DuetAppServices")
      ],
      path: "swift/Sources/DuetAppServicesTestSupport",
      swiftSettings: strictConcurrency
    ),
    // Dependency-free by contract (see the product note above): consumers
    // gate on this emptiness, so a dependency added here is a breaking
    // change to their dependency-audit posture, not an implementation detail.
    .target(
      name: "DuetTelemetry",
      dependencies: [],
      path: "swift/Sources/DuetTelemetry",
      swiftSettings: strictConcurrency
    ),
    // Links DuetTelemetry for the generated mocks alone: the generator emits
    // every annotated port in this package into one file in this target, and
    // `AnalyticsConsentStoringMock` names types from DuetTelemetry. The
    // consent store's own logical tests live in TelemetryTests.
    .testTarget(
      name: "ServicesTests",
      dependencies: [
        .target(name: "DuetDiagnostics"),
        .target(name: "DuetAppServices"),
        .target(name: "DuetTelemetry"),
        .product(name: "DuetTesting", package: "duet"),
      ],
      path: "swift/Tests/ServicesTests",
      swiftSettings: strictConcurrency
    ),
    .testTarget(
      name: "TelemetryTests",
      dependencies: [
        .target(name: "DuetTelemetry")
      ],
      path: "swift/Tests/TelemetryTests",
      swiftSettings: strictConcurrency
    ),
  ]
)
