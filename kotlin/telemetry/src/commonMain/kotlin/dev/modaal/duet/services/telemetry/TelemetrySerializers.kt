// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.telemetry

import dev.modaal.duet.kernel.serialization.CanonicalSumSerializer
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

// The grammar's wire forms, pinned to the Swift twin's (the fixtures under
// contracts/telemetry-twin/ hold both halves to them):
//
//   TrackedEvent  a plain product type — `@Serializable` field coding
//   TrackedVerb   the bare token string ("Signed Out") — the token is the
//                 identity, the wire form, and the vendor-facing spelling
//   TrackedParam  the canonical `{"case": …, "value": …}` envelope for the
//                 ONE sum in the grammar
//
// Four param cases, one registry, forever — a new EVENT never touches this
// file.

object TrackedVerbSerializer : KSerializer<TrackedVerb> {
  override val descriptor: SerialDescriptor =
    PrimitiveSerialDescriptor("TrackedVerb", PrimitiveKind.STRING)

  override fun serialize(encoder: Encoder, value: TrackedVerb) {
    encoder.encodeString(value.rendered)
  }

  override fun deserialize(decoder: Decoder): TrackedVerb = TrackedVerb(decoder.decodeString())
}

object TrackedParamSerializer :
  CanonicalSumSerializer<TrackedParam>(
    "TrackedParam",
    listOf(
      case(TrackedParam.StringParam::class, TrackedParam.StringParam.serializer()),
      case(TrackedParam.IntParam::class, TrackedParam.IntParam.serializer()),
      case(TrackedParam.BoolParam::class, TrackedParam.BoolParam.serializer()),
      case(TrackedParam.DoubleParam::class, TrackedParam.DoubleParam.serializer()),
    ))
