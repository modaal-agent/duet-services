// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertSame

/** An app's own families, as a token generator emits them. */
private enum class SemanticFontFamily : FontFamilyToken {
  Display,
  Sans,
}

/** A face a resolver picks, standing in for a platform font family. */
private enum class Face { BrandDisplay, SystemSans, SystemSerif, SystemMono }

class FontFamilyTokenTest {

  @Test
  fun theEnginesNamedFamiliesAreItsEnumEntries() {
    assertSame(DuetFontFamily.Serif, FontFamilyToken.Serif)
    assertSame(DuetFontFamily.Sans, FontFamilyToken.Sans)
    assertSame(DuetFontFamily.Mono, FontFamilyToken.Mono)
  }

  @Test
  fun aTokenOnAnEngineFamilyResolvesThroughAnExhaustiveSwitch() {
    val token = FontToken(FontFamilyToken.Mono, weight = 400, sizeSp = 13.0, lineHeightSp = 18.0)
    val face = when (token.family as DuetFontFamily) {
      DuetFontFamily.Serif -> Face.SystemSerif
      DuetFontFamily.Sans -> Face.SystemSans
      DuetFontFamily.Mono -> Face.SystemMono
    }
    assertEquals(Face.SystemMono, face)
  }

  @Test
  fun anAppDeclaredFamilyResolvesThroughTheAppsOwnSwitch() {
    val title = FontToken(SemanticFontFamily.Display, weight = 600, sizeSp = 34.0, lineHeightSp = 41.0)
    val body = FontToken(SemanticFontFamily.Sans, weight = 400, sizeSp = 17.0, lineHeightSp = 22.0)
    fun resolve(token: FontToken): Face = when (token.family as SemanticFontFamily) {
      SemanticFontFamily.Display -> Face.BrandDisplay
      SemanticFontFamily.Sans -> Face.SystemSans
    }
    assertEquals(Face.BrandDisplay, resolve(title))
    assertEquals(Face.SystemSans, resolve(body))
  }
}
