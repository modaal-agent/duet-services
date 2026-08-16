// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Telemetry
import XCTest

/// Recorder sink for the fan-out receipts (hand-written — this package has
/// no mock pipeline, and the recorder is four assignments).
private final class RecordingSink: AnalyticsTracking {
  private(set) var tracked: [TrackedEvent] = []
  private(set) var identified: [String] = []
  private(set) var resets = 0
  private(set) var optOuts: [Bool] = []

  func track(event: TrackedEvent) { tracked.append(event) }
  func identify(uid: String) { identified.append(uid) }
  func reset() { resets += 1 }
  func setOptedOut(_ optedOut: Bool) { optOuts.append(optedOut) }
}

final class AnalyticsTests: XCTestCase {

  private let sample = TrackedEvent(subject: "Item", verb: .created)

  func testCompositeFansEveryCallToEachSink() {
    let a = RecordingSink()
    let b = RecordingSink()
    let composite = CompositeAnalytics(sinks: [a, b])

    composite.track(event: sample)
    composite.identify(uid: "uid-1")
    composite.reset()

    for sink in [a, b] {
      XCTAssertEqual(sink.tracked, [sample])
      XCTAssertEqual(sink.identified, ["uid-1"])
      XCTAssertEqual(sink.resets, 1)
    }
  }

  func testOptOutGatesTrackButNotIdentityHygiene() {
    let sink = RecordingSink()
    let composite = CompositeAnalytics(sinks: [sink], initiallyOptedOut: true)

    composite.track(event: sample)
    XCTAssertTrue(sink.tracked.isEmpty)

    // identify/reset pass through — the gate must not strand a stale user
    // association across a sign-out while opted out.
    composite.identify(uid: "uid-2")
    composite.reset()
    XCTAssertEqual(sink.identified, ["uid-2"])
    XCTAssertEqual(sink.resets, 1)

    composite.setOptedOut(false)
    composite.track(event: sample)
    XCTAssertEqual(sink.tracked.count, 1)
    // The construction-time seed and the flip are both forwarded, so vendor
    // SDKs stop their own background egress too.
    XCTAssertEqual(sink.optOuts, [true, false])
  }

  func testNoOpAnalyticsAcceptsTheWholeSurface() {
    let analytics = NoOpAnalytics()
    analytics.track(event: sample)
    analytics.identify(uid: "uid")
    analytics.reset()
    analytics.setOptedOut(true)
  }
}
