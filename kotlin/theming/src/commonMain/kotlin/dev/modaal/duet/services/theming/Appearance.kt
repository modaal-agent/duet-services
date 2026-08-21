// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** What the user picked. [System] defers to the platform setting. */
enum class Appearance {
  Light,
  Dark,
  System,
}

/** What a palette resolves against, after [Appearance.System] is answered. */
enum class ResolvedAppearance {
  Light,
  Dark,
}

/**
 * The persistence seam. The engine reads the selection and never stores it:
 * an app backs this with DataStore, `NSUserDefaults`, or whatever its
 * settings surface already uses, and the resolution layer recomposes off the
 * flow.
 */
interface AppearanceStore {
  val selection: StateFlow<Appearance>

  fun select(appearance: Appearance)
}

/** The default for an app with no appearance setting of its own. */
class InMemoryAppearanceStore(initial: Appearance = Appearance.System) : AppearanceStore {
  private val state = MutableStateFlow(initial)

  override val selection: StateFlow<Appearance> = state.asStateFlow()

  override fun select(appearance: Appearance) {
    state.value = appearance
  }
}
