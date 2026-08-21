// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

/**
 * A spec over a two-entry vocabulary, standing in for an app's palette: the
 * point is that the engine reads through `DuetThemeSpec` and never sees the
 * app's own token type.
 */
private class TestSpec : DuetThemeSpec {
  val background = ColorToken.auto(light = 0xFFFFFFFF, dark = 0xFF000000)
  val brand = ColorToken.fixed(0xFF3366CC)
  val body = FontToken(FontFamilyToken.Sans, weight = 400, sizeSp = 17.0, lineHeightSp = 22.0)

  override fun color(role: DuetColorRole): ColorToken =
    if (role == DuetColorRole.Background) background else brand

  override fun font(role: DuetFontRole): FontToken = body
}

class ThemeResolutionTest {

  @Test
  fun anAutoTokenTakesItsValuePerAppearance() {
    val token = ColorToken.auto(light = 0xFF14130F, dark = 0xFFECE9E0)
    assertEquals(0xFF14130F, token.value(ResolvedAppearance.Light))
    assertEquals(0xFFECE9E0, token.value(ResolvedAppearance.Dark))
    assertNotEquals(token.light, token.dark)
  }

  @Test
  fun aFixedTokenIsAppearanceIndependent() {
    val token = ColorToken.fixed(0x80000000)
    assertEquals(0x80000000, token.value(ResolvedAppearance.Light))
    assertEquals(0x80000000, token.value(ResolvedAppearance.Dark))
  }

  /** The whole truth table: `System` is the only case that reads the platform. */
  @Test
  fun systemIsTheOnlySelectionThatReadsThePlatform() {
    assertEquals(ResolvedAppearance.Light, Appearance.Light.resolved(systemIsDark = false))
    assertEquals(ResolvedAppearance.Light, Appearance.Light.resolved(systemIsDark = true))
    assertEquals(ResolvedAppearance.Dark, Appearance.Dark.resolved(systemIsDark = false))
    assertEquals(ResolvedAppearance.Dark, Appearance.Dark.resolved(systemIsDark = true))
    assertEquals(ResolvedAppearance.Light, Appearance.System.resolved(systemIsDark = false))
    assertEquals(ResolvedAppearance.Dark, Appearance.System.resolved(systemIsDark = true))
  }

  @Test
  fun aResolvedPaletteReadsThroughTheSpecAtItsAppearance() {
    val spec = TestSpec()
    val dark = spec.resolve(ResolvedAppearance.Dark)
    assertEquals(ResolvedAppearance.Dark, dark.appearance)
    assertEquals(0xFF000000, dark.color(DuetColorRole.Background))
    assertEquals(0xFF3366CC, dark.color(DuetColorRole.Primary))
    assertEquals(0xFFFFFFFF, spec.resolve(ResolvedAppearance.Light).color(DuetColorRole.Background))
  }

  /**
   * Every role resolves — a spec cannot leave a slot to a platform default,
   * because the interface has no partial form.
   */
  @Test
  fun everyRoleResolvesToAValue() {
    val palette = TestSpec().resolve(ResolvedAppearance.Light)
    DuetColorRole.entries.forEach { role -> assertNotEquals(0L, palette.color(role)) }
  }

  @Test
  fun theInMemoryStoreDefersToTheSystemUntilTheAppSelects() {
    val store = InMemoryAppearanceStore()
    assertEquals(Appearance.System, store.selection.value)
    store.select(Appearance.Dark)
    assertEquals(Appearance.Dark, store.selection.value)
  }
}
