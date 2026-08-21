// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

plugins {
  alias(libs.plugins.kotlin.multiplatform)
  alias(libs.plugins.kotlin.serialization)
  `maven-publish`
}

// dev.modaal.duet.services:telemetry — the Kotlin half of the telemetry
// substrate, the Swift `DuetTelemetry` product's twin. commonMain carries the
// event grammar (TrackedEvent/TrackedVerb/TrackedParam), the one vendor-name
// encoding rule, the serializers, and the tracking port; jvmMain adds the
// worker-typed sink surface (`Working` lives in dev.modaal.duet:shells-compose,
// a JVM module — the Apple side of a dual-language app types its sinks on the
// native Swift substrate and converts crossing events app-side, so the
// fan-out worker has no Apple consumer). The twin-contract fixtures in
// ../../contracts/telemetry-twin pin serialized equivalence between the two
// halves: this module's tests write them, the Swift TelemetryTests decode
// them.
//
// Dependency rule (the Swift product's, held on this side too): external
// dependencies stay inside the dev.modaal.duet family plus
// kotlinx-serialization. A consumer that links only this artifact resolves
// the family and nothing else, and consumers that audit their dependency
// closure gate on that.
kotlin {
  jvmToolchain(21)

  jvm()
  macosArm64()
  iosArm64()
  iosSimulatorArm64()

  sourceSets {
    commonMain.dependencies {
      api(libs.duet.kernel)
      implementation(libs.kotlinx.serialization.json)
    }
    jvmMain.dependencies {
      // Carries `Working`, which AnalyticsTrackingWorking refines.
      api(libs.duet.shells.compose)
    }
    jvmTest.dependencies {
      implementation(kotlin("test"))
      implementation(libs.kotlinx.coroutines.test)
      implementation(libs.kotlinx.serialization.json)
    }
  }
}

tasks.withType<Test>().configureEach {
  useJUnitPlatform()
  // The twin-contract fixture home, resolved from the repo root so the Kotlin
  // writer and the Swift reader bind the same committed files. Declared as an
  // INPUT so editing a committed fixture re-runs the check — without this the
  // fixtures sit outside the task's fingerprint and a stale run stays
  // up-to-date over a drifted file.
  val fixtures = rootDir.resolve("../contracts/telemetry-twin")
  systemProperty("duet.contractFixtures", fixtures.absolutePath)
  inputs
    .dir(fixtures)
    .withPropertyName("twinContractFixtures")
    .withPathSensitivity(PathSensitivity.RELATIVE)
}
