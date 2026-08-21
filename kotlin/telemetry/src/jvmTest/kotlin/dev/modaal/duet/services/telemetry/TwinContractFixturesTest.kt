// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.telemetry

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.fail
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * The twin contract's Kotlin half — serialized equivalence at the substrate
 * tier, the same discipline the kernel pins with its cross-language
 * fixtures.
 *
 * This test DECLARES the sample events (so the Kotlin declaration's stored
 * display name is the one spelling source), renders each through this
 * module's encoders, and asserts the committed fixtures under
 * `contracts/telemetry-twin/` carry exactly those bytes. The Swift
 * `TelemetryTests` decode the same files and assert their own
 * `encodedName()` and property bag agree — a verb spelling declared once
 * must survive both languages' encoders.
 *
 * Regenerate after a deliberate grammar change with
 * `./gradlew :telemetry:jvmTest -PregenFixtures=1`, and commit the diff.
 */
class TwinContractFixturesTest {

  private val json =
    Json {
      encodeDefaults = true
      prettyPrint = true
    }

  /** The sample set. Each fixture exercises one crossing the contract names. */
  private val samples: Map<String, TrackedEvent> =
    mapOf(
      // The degenerate event: no params, a starter verb.
      "empty-params" to TrackedEvent("Profile", TrackedVerb.Viewed),
      // The display-name crossing: a multi-word token splices verbatim.
      "multiword-verb" to TrackedEvent("Session", TrackedVerb.SignedOut),
      // The open vocabulary: a verb no artifact declares.
      "app-minted-verb" to TrackedEvent("Report", TrackedVerb("Archived")),
      // All four param cases in one bag.
      "param-cases" to
        TrackedEvent(
          "Item",
          TrackedVerb.Created,
          listOf(
            TrackedParam.bool("has_description", true),
            TrackedParam.int("photo_count", 2),
            TrackedParam.string("from", "capture"),
            TrackedParam.double("duration_s", 1.5),
          )),
      // The canonical case envelope, multi-word subject.
      "envelope" to
        TrackedEvent(
          "Item Load",
          TrackedVerb.Failed,
          listOf(
            TrackedParam.string("reason", "offline"),
            TrackedParam.bool("retried", false),
          )),
    )

  private val fixturesDir = File(System.getProperty("duet.contractFixtures"))
  private val regen = System.getProperty("duet.regenFixtures") == "1"

  @Test
  fun committedFixturesCarryTheKotlinEncodersOutput() {
    val rendered = samples.mapValues { (_, event) -> render(event) }

    if (regen) {
      fixturesDir.mkdirs()
      rendered.forEach { (name, text) -> fixtureFile(name).writeText(text) }
    }

    // The set is closed both ways: a sample with no committed file and a
    // committed file with no sample both fail.
    val onDisk =
      fixturesDir
        .listFiles { file -> file.name.endsWith(".fixture.json") }
        .orEmpty()
        .map { it.name.removeSuffix(".fixture.json") }
        .toSet()
    assertEquals(samples.keys, onDisk, "fixture set out of step with the sample declarations")

    rendered.forEach { (name, text) ->
      assertEquals(text, fixtureFile(name).readText(), "fixture $name drifted — regenerate")
    }
  }

  private fun fixtureFile(name: String): File = fixturesDir.resolve("$name.fixture.json")

  /**
   * One fixture document: the serialized event, then the two derived
   * surfaces the Swift reader re-derives and compares.
   */
  private fun render(event: TrackedEvent): String {
    val document =
      buildJsonObject {
        put("event", json.encodeToJsonElement(TrackedEvent.serializer(), event))
        put("encodedName", JsonPrimitive(event.encodedName()))
        put(
          "encodedProperties",
          buildJsonObject {
            event.encodedProperties().forEach { (key, value) ->
              val primitive =
                when (value) {
                  is String -> JsonPrimitive(value)
                  is Int -> JsonPrimitive(value)
                  is Boolean -> JsonPrimitive(value)
                  is Double -> JsonPrimitive(value)
                  else -> fail("non-primitive property bag value for $key")
                }
              put(key, primitive)
            }
          })
      }
    return json.encodeToString(JsonElement.serializer(), document) + "\n"
  }
}
