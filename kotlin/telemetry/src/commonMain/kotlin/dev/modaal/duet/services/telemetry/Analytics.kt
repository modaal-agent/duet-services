// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.telemetry

/**
 * The grammar-typed analytics port — the ONE sink interface. Features and
 * workers depend on this, never on a vendor SDK: when the app picks a vendor
 * (Amplitude, PostHog, …), it adds ONE new file implementing a sink, and that
 * file is the ONLY file that imports the SDK. Sinks render events through
 * [encodedName] and [encodedProperties] — the grammar owns the taxonomy;
 * sinks own transport.
 *
 * Consent is the app's to hold. This port carries the flag and nothing else:
 * where the user's choice is persisted, which screen changes it, and whether
 * an analytics worker is constructed at all are decisions the app makes in
 * its own tree.
 *
 * The Swift twin is `DuetTelemetry.AnalyticsTracking`, member for member.
 */
interface AnalyticsTracking {
  /**
   * `true` while at least one sink is permitted to egress. This answers "is
   * anything being sent right now", not "what did the user choose" — bind a
   * Settings toggle to the app's own consent storage, not to this.
   */
  val isEnabled: Boolean

  /**
   * Permit or stop egress, at every sink. The read and the write are
   * separate members because they answer different questions: this pushes a
   * value down, [isEnabled] folds back what the sinks report, and with no
   * sink wired the two do not agree.
   */
  fun setEnabled(enabled: Boolean)

  /**
   * Emit a typed event. A no-op while egress is stopped and while no sink is
   * wired.
   */
  fun track(event: TrackedEvent)

  /**
   * Associate subsequent events with the signed-in user (a pseudonymous
   * identifier — never an email or a display name). Call on sign-in.
   */
  fun identify(uid: String)

  /** Clear the user association. Call on sign-out. */
  fun reset()
}

/**
 * The Dependency-side seam: a feature's Dependency extends this interface to
 * consume the app's one sink, and the composition root implements it ONCE —
 * every feature's conformance is then satisfied by the same member.
 */
interface AnalyticsProviding {
  val analytics: AnalyticsTracking
}
