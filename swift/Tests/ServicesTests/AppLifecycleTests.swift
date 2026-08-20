// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import DuetAppServices
import Foundation
import XCTest

/// The lifecycle port's logical receipts: each notification name carries the
/// event it is mapped to, every subscriber gets every event, and a name
/// outside the map is not observed.
///
/// Each test posts into a PRIVATE `NotificationCenter`, so nothing here
/// reaches — or is reached by — another test in the process.
final class AppLifecycleTests: XCTestCase {

  private static let didBecomeActive = Notification.Name("test.didBecomeActive")
  private static let willResignActive = Notification.Name("test.willResignActive")
  private static let didEnterBackground = Notification.Name("test.didEnterBackground")
  private static let willEnterForeground = Notification.Name("test.willEnterForeground")

  private static let events: [Notification.Name: AppLifecycleEvent] = [
    didBecomeActive: .didBecomeActive,
    willResignActive: .willResignActive,
    didEnterBackground: .didEnterBackground,
    willEnterForeground: .willEnterForeground,
  ]

  func testEachNameCarriesItsEventInPostOrder() {
    let center = NotificationCenter()
    let observer = NotificationCenterAppLifecycle(center: center, events: Self.events)

    var received: [AppLifecycleEvent] = []
    let token = observer.appLifecycle.sink { received.append($0) }
    defer { token.cancel() }

    center.post(name: Self.willResignActive, object: nil)
    center.post(name: Self.didEnterBackground, object: nil)
    center.post(name: Self.willEnterForeground, object: nil)
    center.post(name: Self.didBecomeActive, object: nil)

    XCTAssertEqual(
      received, [.willResignActive, .didEnterBackground, .willEnterForeground, .didBecomeActive])
  }

  /// The fan-out contract: no priority, nothing to claim — a second
  /// subscriber does not take the event away from the first.
  func testEverySubscriberGetsEveryEvent() {
    let center = NotificationCenter()
    let observer = NotificationCenterAppLifecycle(center: center, events: Self.events)

    var first: [AppLifecycleEvent] = []
    var second: [AppLifecycleEvent] = []
    let firstToken = observer.appLifecycle.sink { first.append($0) }
    let secondToken = observer.appLifecycle.sink { second.append($0) }
    defer {
      firstToken.cancel()
      secondToken.cancel()
    }

    center.post(name: Self.didBecomeActive, object: nil)

    XCTAssertEqual(first, [.didBecomeActive])
    XCTAssertEqual(second, [.didBecomeActive])
  }

  /// The same transition twice is two events: the stream carries occurrences,
  /// not a current value, so a subscriber that pauses on `willResignActive`
  /// pauses again on the second interruption.
  func testRepeatedTransitionsEmitEachTime() {
    let center = NotificationCenter()
    let observer = NotificationCenterAppLifecycle(center: center, events: Self.events)

    var received: [AppLifecycleEvent] = []
    let token = observer.appLifecycle.sink { received.append($0) }
    defer { token.cancel() }

    center.post(name: Self.willResignActive, object: nil)
    center.post(name: Self.willResignActive, object: nil)

    XCTAssertEqual(received, [.willResignActive, .willResignActive])
  }

  func testNamesOutsideTheMapAreNotObserved() {
    let center = NotificationCenter()
    let observer = NotificationCenterAppLifecycle(
      center: center, events: [Self.didBecomeActive: .didBecomeActive])

    var received: [AppLifecycleEvent] = []
    let token = observer.appLifecycle.sink { received.append($0) }
    defer { token.cancel() }

    center.post(name: Self.willResignActive, object: nil)
    center.post(name: Notification.Name("test.unrelated"), object: nil)

    XCTAssertEqual(received, [])
  }

  /// Cancelling the subscription ends delivery — the observer holds no
  /// registration of its own beyond what a subscriber asks for.
  func testCancellingTheSubscriptionEndsDelivery() {
    let center = NotificationCenter()
    let observer = NotificationCenterAppLifecycle(center: center, events: Self.events)

    var received: [AppLifecycleEvent] = []
    let token = observer.appLifecycle.sink { received.append($0) }
    center.post(name: Self.didBecomeActive, object: nil)
    token.cancel()
    center.post(name: Self.didEnterBackground, object: nil)

    XCTAssertEqual(received, [.didBecomeActive])
  }
}
