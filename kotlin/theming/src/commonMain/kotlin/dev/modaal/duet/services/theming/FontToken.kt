// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

/**
 * Which face a token is set in. The token names a family, never a file: font
 * resources are app-owned (`R.font.*` under Compose, a bundle registration on
 * Apple), and the app hands the resolution layer a resolver.
 */
enum class FontFamilyToken {
  Serif,
  Sans,
  Mono,
}

/**
 * One typography entry, in the terms every resolver needs: a family, a weight,
 * a size, a line height, tracking as a fraction of the em, and the
 * variable-font axes a cut is pinned at.
 *
 * The axes are load-bearing, not decoration. A variable face addressed by
 * weight alone renders at the default optical size — no error, visibly wrong
 * glyphs. Carrying the axes in the token is what lets one declaration drive
 * every platform's resolver.
 */
class FontToken(
  val family: FontFamilyToken,
  val weight: Int,
  val sizeSp: Double,
  val lineHeightSp: Double,
  val trackingEm: Double = 0.0,
  /** `opsz`, on families that carry it. */
  val opticalSize: Double? = null,
  /** `SOFT`, on families that carry it. */
  val softness: Double? = null,
  /** `wdth`, on families that carry it. */
  val width: Double? = null,
)
