// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

pluginManagement {
  repositories {
    gradlePluginPortal()
    mavenCentral()
    google()
  }
}

dependencyResolutionManagement {
  repositories {
    // Family iteration only: -PduetMavenLocal=1 resolves dev.modaal.* from
    // mavenLocal AHEAD of the published repository (a framework checkout's
    // `publishToMavenLocal` snapshot). Default resolution is hermetic — the
    // released artifacts below are the only source.
    if (providers.gradleProperty("duetMavenLocal").orNull == "1") {
      mavenLocal()
    }
    // The family's static Maven host — where `dev.modaal.duet:kernel` and
    // `dev.modaal.duet:shells-compose` resolve from, and where this build's
    // own artifact publishes to. The content filter keeps Gradle from probing
    // it for anything outside dev.modaal.*.
    maven {
      url = uri("https://modaal-agent.github.io/maven")
      content { includeGroupByRegex("""dev\.modaal(\..*)?""") }
    }
    mavenCentral()
    google()
  }
}

// The KMP half of duet-services (the Swift half lives in ../swift, SPM; the
// twin contract's fixtures in ../contracts bind both). Maven coordinate:
// dev.modaal.duet.services:telemetry.
rootProject.name = "duet-services"

include(":telemetry")
