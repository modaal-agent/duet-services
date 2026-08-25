// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

plugins {
  alias(libs.plugins.kotlin.multiplatform)
  `maven-publish`
}

// dev.modaal.duet.services:theming — the platform-free theming engine: the
// value types a palette entry takes (`ColorToken`, `FontToken`), the colour
// and typography role sets a resolved theme fills, the `DuetThemeSpec` seam an
// app implements over its own token vocabulary, and the appearance selection
// store.
//
// No Compose and no platform colour class in the module. An app's palette is
// common code that depends on these types, so they cannot carry a platform.
// Resolution is native and lives in the consuming app: under Compose, a layer
// that turns a `ResolvedPalette` into a Material `ColorScheme` and a
// `DuetThemeSpec` into a `Typography`; on Apple, the app's own theming engine.
//
// Android consumers resolve the `-jvm` variant, the route the telemetry
// artifact's Android consumers already take. No android variant is published,
// and the module builds with no Android SDK on the host.
//
// Dependency rule: `kotlinx-coroutines`, for the `StateFlow` the appearance
// store publishes, and nothing else — not even the rest of the family. A
// consumer that links only this artifact resolves this artifact and
// coroutines.
kotlin {
  jvmToolchain(25)

  jvm()
  macosArm64()
  iosArm64()
  iosSimulatorArm64()

  sourceSets {
    commonMain.dependencies {
      api(libs.kotlinx.coroutines.core)
    }
    jvmTest.dependencies {
      implementation(kotlin("test"))
    }
  }
}

tasks.withType<Test>().configureEach {
  useJUnitPlatform()
}
