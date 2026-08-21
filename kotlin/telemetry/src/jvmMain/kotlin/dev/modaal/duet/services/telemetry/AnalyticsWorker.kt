// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.telemetry

import dev.modaal.duet.shells.Working
import dev.modaal.duet.shells.untilCancelled

// jvmMain, deliberately: `Working` lives in dev.modaal.duet:shells-compose, a
// JVM module, and the Apple side of a dual-language app types its sinks on
// the native Swift substrate (`DuetTelemetry`) — crossing events convert
// app-side — so the worker-typed sink surface has exactly one consuming
// platform.

/**
 * The port a vendor sink implements. A sink is a worker: the composition
 * root adopts it, and its egress runs inside the mount's lifetime.
 *
 * A sink's enabled flag belongs to the vendor SDK's own opt-out switch —
 * which is where the flag has to reach anyway, so the SDK stops its own
 * background egress — read back in [isEnabled]. Where an SDK exposes no
 * readable switch, hold the flag in a `@Volatile` field and mirror it to the
 * SDK.
 */
interface AnalyticsTrackingWorking : AnalyticsTracking, Working

/**
 * The sink fan-out, SDK-free: every call reaches every sink, so adding or
 * removing a vendor is a one-line change at the composition root. It stores
 * [sinks] and nothing else — no gate, no lock. Each sink decides for itself
 * whether an event leaves the device, which is where the vendor SDK's own
 * switch already lives.
 *
 * `AnalyticsTrackingWorker(sinks = emptyList())` is the working default
 * before a vendor is picked: every call is accepted and dropped, and
 * [isEnabled] reads `false`.
 *
 * @param sinks the vendor sinks to fan out to. Each is adopted by the
 *   composition root in its own right — this worker does not bracket their
 *   lifetimes.
 * @param isEnabled pushed into every sink before this constructor returns,
 *   so no sink egresses in the window between composition and the first
 *   flip. Pass the app's persisted choice.
 */
class AnalyticsTrackingWorker(
  private val sinks: List<AnalyticsTrackingWorking>,
  isEnabled: Boolean = true,
) : AnalyticsTrackingWorking {

  init {
    sinks.forEach { it.setEnabled(isEnabled) }
  }

  /**
   * `true` when ANY sink reports itself enabled. Sinks disagree only when a
   * caller sets one directly instead of through this worker, and for a
   * consent readback over-reporting egress is the safe direction.
   */
  override val isEnabled: Boolean
    get() = sinks.any { it.isEnabled }

  override fun setEnabled(enabled: Boolean) {
    sinks.forEach { it.setEnabled(enabled) }
  }

  override fun track(event: TrackedEvent) {
    sinks.forEach { it.track(event) }
  }

  override fun identify(uid: String) {
    sinks.forEach { it.identify(uid) }
  }

  override fun reset() {
    sinks.forEach { it.reset() }
  }

  /** Parks until the host cancels. The sinks run their own `run()`. */
  override suspend fun run() {
    untilCancelled()
  }
}
