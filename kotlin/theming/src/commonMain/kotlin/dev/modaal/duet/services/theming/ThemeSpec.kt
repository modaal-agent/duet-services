// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

/**
 * What an app hands the resolution layer: a value for every colour role and
 * every typography role.
 *
 * An app implements this over its own token vocabulary — `color(Background)`
 * returns the `ColorToken` its palette holds for `backgroundPrimary`. The
 * engine never sees the app's enum, which is what keeps the vocabulary open:
 * an app adds, renames or drops semantic tokens without an engine release.
 */
interface DuetThemeSpec {
  fun color(role: DuetColorRole): ColorToken

  fun font(role: DuetFontRole): FontToken
}

/**
 * The palette resolved for one appearance, readable with nothing in scope.
 *
 * A widget host renders outside any composition — Glance draws through
 * `RemoteViews` in a separate process — so it cannot read `MaterialTheme`. A
 * surface that resolves to plain `0xAARRGGBB` values is what lets the home
 * screen and the app carry the same palette instead of two copies of it.
 */
class ResolvedPalette(
  private val spec: DuetThemeSpec,
  val appearance: ResolvedAppearance,
) {
  fun color(role: DuetColorRole): Long = spec.color(role).value(appearance)
}

fun DuetThemeSpec.resolve(appearance: ResolvedAppearance): ResolvedPalette =
  ResolvedPalette(this, appearance)

/** Answers [Appearance.System] with the platform's current setting. */
fun Appearance.resolved(systemIsDark: Boolean): ResolvedAppearance =
  when (this) {
    Appearance.Light -> ResolvedAppearance.Light
    Appearance.Dark -> ResolvedAppearance.Dark
    Appearance.System -> if (systemIsDark) ResolvedAppearance.Dark else ResolvedAppearance.Light
  }
