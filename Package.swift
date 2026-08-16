// swift-tools-version:5.9

// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import PackageDescription

// The services and telemetry layer for duet-family apps. Four products, each
// consumed independently:
//
//   Diagnostics   the structured-logging port and its worker
//   Analytics     the consent store (defaults-backed, default-on)
//   AppServices   the inbound-URL/notification registry worker and the
//                 system-integration ports (audio session, haptics,
//                 pasteboard, system actions)
//   Telemetry     the semantic-event grammar substrate: the event product
//                 type, the tracking port, the SDK-free fan-out and no-op
//                 sinks. Its target depends on nothing — a consumer that
//                 links only Telemetry adds no third-party code to its
//                 resolved graph beyond this package and `duet`.
//
// The service modules follow the worker-seam shape (port + default + fake +
// logical tests); an app picks a vendor by conforming to a port in one file,
// never by a dependency declared here.

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
    .library(name: "Diagnostics", targets: ["Diagnostics"]),
    .library(name: "Analytics", targets: ["Analytics"]),
    .library(name: "AppServices", targets: ["AppServices"]),
    .library(name: "Telemetry", targets: ["Telemetry"]),
  ],
  dependencies: [
    // The duet framework, as a sibling checkout while the family is
    // private. THE SINGLE SWAP POINT at publication:
    //   .package(name: "modaal-agent-duet",
    //            url: "https://github.com/modaal-agent/duet.git",
    //            exact: "<published tag>")
    // (keep `name:` so the product references below survive the swap).
    .package(name: "modaal-agent-duet", path: "../modaal-agent-duet")
  ],
  targets: [
    .target(
      name: "Diagnostics",
      dependencies: [
        .product(name: "DuetShells", package: "modaal-agent-duet")
      ],
      swiftSettings: strictConcurrency
    ),
    .target(
      name: "Analytics",
      dependencies: [],
      swiftSettings: strictConcurrency
    ),
    .target(
      name: "AppServices",
      dependencies: [
        .product(name: "DuetShells", package: "modaal-agent-duet")
      ],
      swiftSettings: strictConcurrency
    ),
    // Dependency-free by contract (see the product note above): consumers
    // gate on this emptiness, so a dependency added here is a breaking
    // change to their dependency-audit posture, not an implementation detail.
    .target(
      name: "Telemetry",
      dependencies: [],
      swiftSettings: strictConcurrency
    ),
    .testTarget(
      name: "ServicesTests",
      dependencies: [
        .target(name: "Diagnostics"),
        .target(name: "Analytics"),
        .target(name: "AppServices"),
        .product(name: "DuetTesting", package: "modaal-agent-duet"),
      ],
      swiftSettings: strictConcurrency
    ),
    .testTarget(
      name: "TelemetryTests",
      dependencies: [
        .target(name: "Telemetry")
      ],
      swiftSettings: strictConcurrency
    ),
  ]
)
