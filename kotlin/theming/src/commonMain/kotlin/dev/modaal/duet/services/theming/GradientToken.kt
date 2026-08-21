// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

/**
 * One gradient entry: the stop list a semantic token takes in each appearance,
 * as `0xAARRGGBB` values in paint order.
 *
 * The type carries no platform gradient class, for the reason [ColorToken]
 * carries no colour class: an app's palette is common code, and each platform's
 * resolution layer turns a stop list into its own paint — a `Brush` under
 * Compose, a `Gradient` on Apple.
 *
 * A gradient is read from the app's palette by its own semantic token rather
 * than through [DuetThemeSpec], and there is no gradient role. The role sets
 * exist to fill Material's slots — thirty-six on `ColorScheme`, fifteen on
 * `Typography` — and Material carries no gradient among them, so a gradient
 * role would map to nothing. The Apple engine reaches the same value the other
 * way, resolving a gradient through the theme like any other asset kind.
 *
 * Direction is the call site's on both platforms: a stop list is the whole
 * value.
 */
class GradientToken private constructor(val light: List<Long>, val dark: List<Long>) {

  fun stops(appearance: ResolvedAppearance): List<Long> =
    when (appearance) {
      ResolvedAppearance.Light -> light
      ResolvedAppearance.Dark -> dark
    }

  companion object {
    /** Separate stop lists per appearance. */
    fun auto(light: List<Long>, dark: List<Long>): GradientToken = GradientToken(light, dark)

    /** One stop list in both appearances. */
    fun fixed(stops: List<Long>): GradientToken = GradientToken(stops, stops)
  }
}
