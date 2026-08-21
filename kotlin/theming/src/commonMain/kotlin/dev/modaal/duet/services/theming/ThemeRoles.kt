// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.theming

/**
 * The colour slots a resolved theme fills: every slot on Material's
 * `ColorScheme`, so no value in a resolved scheme comes from Material's
 * baseline.
 *
 * The list is Material's own, because resolution under Compose is Material
 * idiom — the app tree reads `MaterialTheme.colorScheme`, and a role
 * vocabulary invented here would only add a translation table. What this
 * engine changes is the SOURCE: every slot binds to one of the app's semantic
 * tokens, so a value has one home.
 *
 * A binding is an exhaustive `when` in app code, so a role added here fails an
 * app's compile until it has a token.
 *
 * Totality is what the role set buys. `ColorScheme.copy` takes a default for
 * every slot and reports nothing, so an unbound slot resolves to a Material
 * default silently. Measured on one adopting app: `Scrim`, `InverseSurface`
 * and `InverseOnSurface` were read at eleven call sites while no scheme set
 * them, so three colours on screen came from Material defaults and the rest
 * from the design system.
 *
 * The list is Material 1.3.2's thirty-six. A Material version that adds a slot
 * needs a role added here; the gap surfaces in the consuming app's Compose
 * resolution layer, at its compose-BOM bump.
 */
enum class DuetColorRole {
  Primary,
  OnPrimary,
  PrimaryContainer,
  OnPrimaryContainer,
  InversePrimary,
  Secondary,
  OnSecondary,
  SecondaryContainer,
  OnSecondaryContainer,
  Tertiary,
  OnTertiary,
  TertiaryContainer,
  OnTertiaryContainer,
  Background,
  OnBackground,
  Surface,
  OnSurface,
  SurfaceVariant,
  OnSurfaceVariant,
  SurfaceTint,
  InverseSurface,
  InverseOnSurface,
  Error,
  OnError,
  ErrorContainer,
  OnErrorContainer,
  Outline,
  OutlineVariant,
  Scrim,
  SurfaceBright,
  SurfaceDim,
  SurfaceContainer,
  SurfaceContainerHigh,
  SurfaceContainerHighest,
  SurfaceContainerLow,
  SurfaceContainerLowest,
}

/** The typography slots a resolved theme fills — Material's fifteen, for the same reason. */
enum class DuetFontRole {
  DisplayLarge,
  DisplayMedium,
  DisplaySmall,
  HeadlineLarge,
  HeadlineMedium,
  HeadlineSmall,
  TitleLarge,
  TitleMedium,
  TitleSmall,
  BodyLarge,
  BodyMedium,
  BodySmall,
  LabelLarge,
  LabelMedium,
  LabelSmall,
}
