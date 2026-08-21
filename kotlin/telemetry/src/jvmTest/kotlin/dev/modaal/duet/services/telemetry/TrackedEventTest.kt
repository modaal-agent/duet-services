// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.telemetry

import dev.modaal.duet.kernel.serialization.CanonicalJson
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlinx.serialization.json.Json

/** A verb this artifact does not declare, added the way an app adds one. */
private val Archived = TrackedVerb("Archived")

/**
 * The logical pins for the grammar's DERIVED surface: fixtures record
 * grammar VALUES; the vendor-facing name and property bag are derived, so
 * the encoding rule is pinned here — exact strings — and the wire form is
 * pinned as the canonical bytes the Swift twin's own test pins.
 */
class TrackedEventTest {

  private val json = Json { encodeDefaults = true }

  @Test
  fun encodedNameIsSubjectSpaceVerb() {
    assertEquals("Item Created", TrackedEvent("Item", TrackedVerb.Created).encodedName())
    assertEquals("Item Load Failed", TrackedEvent("Item Load", TrackedVerb.Failed).encodedName())
    // A multi-word token splices verbatim.
    assertEquals("Session Signed Out", TrackedEvent("Session", TrackedVerb.SignedOut).encodedName())
  }

  /**
   * The extension point: a verb this artifact never declared behaves like
   * one it did — encoded, decoded and compared the same way.
   */
  @Test
  fun anAppDeclaredVerbIsAFirstClassVerb() {
    val event = TrackedEvent("Report", Archived)

    assertEquals("Report Archived", event.encodedName())

    val encoded = json.encodeToString(TrackedEvent.serializer(), event)
    assertEquals(event, json.decodeFromString(TrackedEvent.serializer(), encoded))
  }

  /**
   * The wire form is the bare token, and the token survives a decode
   * unchanged — it is also the vendor-facing spelling, so there is no
   * second storage to drift.
   */
  @Test
  fun theTokenIsTheWireFormAndSurvivesADecode() {
    val encoded = json.encodeToString(TrackedVerbSerializer, TrackedVerb.SignedOut)
    assertEquals("\"Signed Out\"", encoded)
    assertEquals(TrackedVerb.SignedOut, json.decodeFromString(TrackedVerbSerializer, encoded))
  }

  /**
   * Identity is the token: two spellings of one verb are one verb, whichever
   * declaration minted them.
   */
  @Test
  fun verbIdentityIsTheToken() {
    assertEquals(TrackedVerb.Completed, TrackedVerb("Completed"))
    assertEquals(1, setOf(TrackedVerb("Completed"), TrackedVerb.Completed).size)
    assertNotEquals(TrackedVerb.Created, TrackedVerb("Completed"))
  }

  @Test
  fun encodedPropertiesFlattenTheParamList() {
    val event =
      TrackedEvent(
        "Item",
        TrackedVerb.Created,
        listOf(
          TrackedParam.bool("has_description", true),
          TrackedParam.int("photo_count", 2),
          TrackedParam.string("from", "capture"),
          TrackedParam.double("duration_s", 1.5),
        ))
    val bag = event.encodedProperties()
    assertEquals(4, bag.size)
    assertEquals(true, bag["has_description"])
    assertEquals(2, bag["photo_count"])
    assertEquals("capture", bag["from"])
    assertEquals(1.5, bag["duration_s"])
  }

  @Test
  fun wireFormIsTheCanonicalCaseEnvelope() {
    // The exact bytes feature fixtures embed for a `Track` effect's event —
    // a contract, pinned: subject/verb/params product, params as case sums.
    // The Swift twin's test pins this same string over its own encoder.
    val event =
      TrackedEvent(
        "Item Load",
        TrackedVerb.Failed,
        listOf(
          TrackedParam.string("reason", "offline"),
          TrackedParam.bool("retried", false),
        ))
    val canonical =
      CanonicalJson.canonicalString(json.encodeToJsonElement(TrackedEvent.serializer(), event))
    assertEquals(
      "{\"params\":[{\"case\":\"string\",\"value\":{\"key\":\"reason\",\"value\":\"offline\"}}," +
        "{\"case\":\"bool\",\"value\":{\"key\":\"retried\",\"value\":false}}]," +
        "\"subject\":\"Item Load\",\"verb\":\"Failed\"}",
      canonical)
    assertEquals(event, json.decodeFromString(TrackedEvent.serializer(), canonical))
  }
}
