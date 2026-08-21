// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

package dev.modaal.duet.services.telemetry

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest

/**
 * A sink that mirrors the flag the way a vendor SDK does — the write lands
 * on the switch the read then reports.
 */
private class RecordingSink : AnalyticsTrackingWorking {
  val tracked = mutableListOf<TrackedEvent>()
  val identified = mutableListOf<String>()
  var resets = 0
  val enabledWrites = mutableListOf<Boolean>()
  var runCalls = 0

  private var enabled = true

  override val isEnabled: Boolean
    get() = enabled

  override fun setEnabled(enabled: Boolean) {
    enabledWrites += enabled
    this.enabled = enabled
  }

  override fun track(event: TrackedEvent) {
    tracked += event
  }

  override fun identify(uid: String) {
    identified += uid
  }

  override fun reset() {
    resets += 1
  }

  override suspend fun run() {
    runCalls += 1
  }
}

/**
 * Fan-out receipts, the Swift twin's member for member. The worker holds no
 * state of its own, so every property under test is a relationship between
 * what the caller does and what each sink sees: the calls reach every sink,
 * the constructor seeds the flag before it returns, [isEnabled] folds the
 * sinks with OR, and `run()` parks without driving the sinks' own
 * lifecycles.
 */
class AnalyticsWorkerTest {

  private val sample = TrackedEvent("Item", TrackedVerb.Created)

  @Test
  fun everyCallReachesEverySink() {
    val a = RecordingSink()
    val b = RecordingSink()
    val worker = AnalyticsTrackingWorker(sinks = listOf(a, b))

    worker.track(sample)
    worker.identify("uid-1")
    worker.reset()
    worker.setEnabled(false)

    for (sink in listOf(a, b)) {
      assertEquals(listOf(sample), sink.tracked)
      assertEquals(listOf("uid-1"), sink.identified)
      assertEquals(1, sink.resets)
      // The constructor's default seed, then the flip.
      assertEquals(listOf(true, false), sink.enabledWrites)
    }
  }

  @Test
  fun theConstructorSeedsEachSinkBeforeItReturns() {
    val sink = RecordingSink()
    AnalyticsTrackingWorker(sinks = listOf(sink), isEnabled = false)

    // The seed reaches the SDK at composition, so nothing egresses in the
    // window between construction and the first flip.
    assertEquals(listOf(false), sink.enabledWrites)
    assertFalse(sink.isEnabled)
  }

  @Test
  fun isEnabledFoldsTheSinksWithOr() {
    val a = RecordingSink()
    val b = RecordingSink()
    val worker = AnalyticsTrackingWorker(sinks = listOf(a, b), isEnabled = false)
    assertFalse(worker.isEnabled)

    // Sinks disagree only when a caller reaches one directly. OR reports
    // "something is egressing", which is the safe direction for a readback.
    a.setEnabled(true)
    assertTrue(worker.isEnabled)

    worker.setEnabled(false)
    assertFalse(worker.isEnabled)
  }

  @Test
  fun theEmptyFanOutAcceptsEveryCallAndReportsDisabled() {
    val worker = AnalyticsTrackingWorker(sinks = emptyList())

    worker.track(sample)
    worker.identify("uid")
    worker.reset()
    worker.setEnabled(true)

    // The working default before a vendor is picked: accepted and dropped.
    assertFalse(worker.isEnabled)
  }

  @Test
  fun runParksAndLeavesEachSinkItsOwnLifecycle() = runTest {
    val sink = RecordingSink()
    val worker = AnalyticsTrackingWorker(sinks = listOf(sink))

    val job = launch { worker.run() }
    testScheduler.runCurrent()
    assertTrue(job.isActive)

    job.cancelAndJoin()

    // The composition root adopts each sink in its own right; the fan-out
    // does not bracket them.
    assertEquals(0, sink.runCalls)
  }
}
