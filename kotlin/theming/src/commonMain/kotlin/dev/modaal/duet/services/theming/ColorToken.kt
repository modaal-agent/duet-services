// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

/**
 * One palette entry: the value a semantic token takes in each appearance, as
 * `0xAARRGGBB`.
 *
 * The type carries no platform colour class. An app's palette is common code
 * — a table of values, read by whichever resolver the platform runs — so an
 * entry has to be expressible in common. Resolution stays native:
 * trait-collection dynamics on Apple, `isSystemInDarkTheme` under Compose.
 */
class ColorToken private constructor(val light: Long, val dark: Long) {

  fun value(appearance: ResolvedAppearance): Long =
    when (appearance) {
      ResolvedAppearance.Light -> light
      ResolvedAppearance.Dark -> dark
    }

  companion object {
    /** Separate values per appearance. */
    fun auto(light: Long, dark: Long): ColorToken = ColorToken(light, dark)

    /** One value in both appearances. */
    fun fixed(value: Long): ColorToken = ColorToken(value, value)
  }
}
