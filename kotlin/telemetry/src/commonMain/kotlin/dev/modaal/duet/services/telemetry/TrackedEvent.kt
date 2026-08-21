// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.telemetry

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * The event GRAMMAR — a vocabulary, not a catalog. Every analytics event in
 * the app is one [TrackedEvent]: a subject, a verb from the app's verb
 * vocabulary, and an ordered list of primitive params. Features declare their
 * own named events from this grammar (one builder per event, in a
 * `<Feature>Events` object next to the feature) and reducers emit them as
 * `Track` effects, so which event fires on which transition — params
 * included — is fixture-gated.
 *
 * Params are primitives only (string/int/bool/double). That constraint is
 * also the privacy rule: values are behavioral metadata — counts, flags,
 * enum names, durations — NEVER user content, names, emails, or free text.
 * A list or date enters as a string through an encoding stated at the call
 * site (e.g. sorted comma-join, ISO-8601).
 *
 * The Swift twin is `DuetTelemetry.TrackedEvent`, and the two halves encode
 * identically — the fixtures under `contracts/telemetry-twin/` pin it: a
 * dual-language app's converter can carry a Kotlin-minted event into the
 * native Swift substrate losslessly because the shapes agree by test.
 */
@Serializable
data class TrackedEvent(
  val subject: String,
  val verb: TrackedVerb,
  val params: List<TrackedParam> = emptyList(),
)

/**
 * A verb — one token from the app's verb vocabulary.
 *
 * The vocabulary is the APP's, not this artifact's: the verbs below are the
 * ones most apps start from, and an app adds its own in one line, wherever
 * it needs them:
 *
 * ```kotlin
 * val Shared = TrackedVerb("Shared")
 * val Regenerated = TrackedVerb("Regenerated")
 * ```
 *
 * An open token type rather than an enum, and that is the whole reason: an
 * enum's entries are fixed by the module that declares them, so a linked
 * grammar would cap every app's taxonomy at this file's list. What the app
 * gives up is the compiler's exhaustiveness check over verbs, which nothing
 * in the grammar branches on.
 *
 * Adding a verb stays a taxonomy decision — a new vendor-facing name family
 * every dashboard then keys on — reviewed like one, not a call-site
 * convenience. Reach for an existing verb first.
 *
 * [rendered] is the token, and the token is the whole story: the identity
 * (equality and hashing), the wire form (a verb encodes as the bare string —
 * TelemetrySerializers.kt), and the vendor-facing spelling ([encodedName]
 * splices it after the subject). Mint it spelled exactly as a dashboard
 * should read it — `TrackedVerb("Signed Out")`. A dual-language app's
 * converter crosses this stored display name, so both languages spell one
 * event one way because ONE declaration is the source — there is no
 * derivation to keep in step.
 */
@Serializable(with = TrackedVerbSerializer::class)
data class TrackedVerb(
  /** The token — Title Case, spelled as displayed (`"Signed Out"`). */
  val rendered: String
) {
  init {
    require(rendered.isNotEmpty()) { "a verb token must not be empty" }
  }

  companion object {
    // The starter vocabulary — the verbs an app is likeliest to need on day
    // one. Not a closed set: an app adds to it with a declaration of its own
    // (above) and simply does not name the ones it has no use for.
    val Viewed = TrackedVerb("Viewed")
    val Opened = TrackedVerb("Opened")
    val Started = TrackedVerb("Started")
    val Completed = TrackedVerb("Completed")
    val Failed = TrackedVerb("Failed")
    val Created = TrackedVerb("Created")
    val Edited = TrackedVerb("Edited")
    val Deleted = TrackedVerb("Deleted")
    val Toggled = TrackedVerb("Toggled")
    val SignedOut = TrackedVerb("Signed Out")
  }
}

/**
 * One typed param. Keys are snake_case literals, stated at the builder. Four
 * cases, one serializer registry (TelemetrySerializers.kt), forever — a new
 * EVENT never touches serialization.
 */
@Serializable(with = TrackedParamSerializer::class)
sealed interface TrackedParam {
  val key: String

  @Serializable
  @SerialName("string")
  data class StringParam(override val key: String, val value: String) : TrackedParam

  @Serializable
  @SerialName("int")
  data class IntParam(override val key: String, val value: Int) : TrackedParam

  @Serializable
  @SerialName("bool")
  data class BoolParam(override val key: String, val value: Boolean) : TrackedParam

  @Serializable
  @SerialName("double")
  data class DoubleParam(override val key: String, val value: Double) : TrackedParam

  companion object {
    fun string(key: String, value: String): TrackedParam = StringParam(key, value)

    fun int(key: String, value: Int): TrackedParam = IntParam(key, value)

    fun bool(key: String, value: Boolean): TrackedParam = BoolParam(key, value)

    fun double(key: String, value: Double): TrackedParam = DoubleParam(key, value)
  }
}

/**
 * The vendor-facing event name — ONE encoding rule for every platform and
 * every sink: `"Subject Verb"`, Title Case, the verb token verbatim. Pinned
 * by a logical test (fixtures record grammar VALUES; the name is derived).
 */
fun TrackedEvent.encodedName(): String = "$subject ${verb.rendered}"

/**
 * The vendor-facing property bag — the ordered param list flattened to
 * key/value pairs. Sinks hand this to their SDK verbatim.
 */
fun TrackedEvent.encodedProperties(): Map<String, Any> =
  params.associate { param ->
    param.key to
      when (param) {
        is TrackedParam.StringParam -> param.value
        is TrackedParam.IntParam -> param.value
        is TrackedParam.BoolParam -> param.value
        is TrackedParam.DoubleParam -> param.value
      }
  }
