// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * The role sets are the artifact's public vocabulary: an app's binding is an
 * exhaustive `when` over them, so adding or dropping a role breaks every
 * adopting app's compile. The counts are pinned so that a change to either
 * set is a deliberate edit here rather than a side effect of a Material
 * version bump — the resolution layer, which maps role to Material slot
 * one-for-one, is the other end of the same contract.
 */
class ThemeRolesTest {

  @Test
  fun colorRolesAreMaterialsThirtySixSlots() {
    assertEquals(36, DuetColorRole.entries.size)
  }

  @Test
  fun fontRolesAreMaterialsFifteenSlots() {
    assertEquals(15, DuetFontRole.entries.size)
  }

  /** Ordinals are not the contract, but duplicates in the source would be. */
  @Test
  fun roleNamesAreDistinct() {
    assertEquals(
      DuetColorRole.entries.size,
      DuetColorRole.entries.map { it.name }.toSet().size,
    )
    assertEquals(
      DuetFontRole.entries.size,
      DuetFontRole.entries.map { it.name }.toSet().size,
    )
  }
}
