// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import DuetTelemetry
import DuetTesting
import XCTest

/// Fan-out receipts. The worker holds no state of its own, so every property
/// under test is a relationship between what the caller does and what each
/// sink sees: the calls reach every sink, the constructor seeds the flag
/// before it returns, `isEnabled` folds the sinks with OR, and `run()` parks
/// without driving the sinks' own lifecycles.
final class AnalyticsTests: XCTestCase {

  private let sample = TrackedEvent(subject: "Item", verb: .created)

  /// A sink that mirrors the flag the way a vendor SDK does — the write lands
  /// on the switch the read then reports.
  private func makeSink() -> AnalyticsTrackingWorkingMock {
    let sink = AnalyticsTrackingWorkingMock()
    sink.setEnabledHandler = { [unowned sink] enabled in sink.isEnabled = enabled }
    return sink
  }

  func testEveryCallReachesEverySink() {
    let a = makeSink()
    let b = makeSink()
    let worker = AnalyticsTrackingWorker(sinks: [a, b])

    worker.track(event: sample)
    worker.identify(uid: "uid-1")
    worker.reset()
    worker.setEnabled(false)

    for sink in [a, b] {
      XCTAssertEqual(sink.trackArgs, [sample])
      XCTAssertEqual(sink.identifyArgs, ["uid-1"])
      XCTAssertEqual(sink.resetCallCount, 1)
      // The constructor's default seed, then the flip.
      XCTAssertEqual(sink.setEnabledArgs, [true, false])
    }
  }

  func testTheConstructorSeedsEachSinkBeforeItReturns() {
    let sink = makeSink()
    _ = AnalyticsTrackingWorker(sinks: [sink], isEnabled: false)

    // The seed reaches the SDK at composition, so nothing egresses in the
    // window between construction and the first flip.
    XCTAssertEqual(sink.setEnabledArgs, [false])
    XCTAssertFalse(sink.isEnabled)
  }

  func testIsEnabledFoldsTheSinksWithOr() {
    let a = makeSink()
    let b = makeSink()
    let worker = AnalyticsTrackingWorker(sinks: [a, b], isEnabled: false)
    XCTAssertFalse(worker.isEnabled)

    // Sinks disagree only when a caller reaches one directly. OR reports
    // "something is egressing", which is the safe direction for a readback.
    a.setEnabled(true)
    XCTAssertTrue(worker.isEnabled)

    worker.setEnabled(false)
    XCTAssertFalse(worker.isEnabled)
  }

  func testTheEmptyFanOutAcceptsEveryCallAndReportsDisabled() {
    let worker = AnalyticsTrackingWorker(sinks: [])

    worker.track(event: sample)
    worker.identify(uid: "uid")
    worker.reset()
    worker.setEnabled(true)

    // The working default before a vendor is picked: accepted and dropped.
    XCTAssertFalse(worker.isEnabled)
  }

  func testRunParksAndLeavesEachSinkItsOwnLifecycle() async {
    let sink = makeSink()
    let worker = AnalyticsTrackingWorker(sinks: [sink])
    let tester = WorkerTester(worker)
    tester.start()

    await tester.finish()

    // The composition root adopts each sink in its own right; the fan-out
    // does not bracket them.
    XCTAssertEqual(sink.runCallCount, 0)
  }
}
