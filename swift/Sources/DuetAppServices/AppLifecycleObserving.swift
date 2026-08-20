// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import Foundation

/// One app-lifecycle transition.
///
/// The four an app branches on. `willResignActive` covers interruptions that
/// do not background the app — an incoming call, the Control Centre
/// pull-down, a system alert — so a surface that pauses on
/// `didEnterBackground` alone keeps running under the notification shade.
public enum AppLifecycleEvent: Equatable, Sendable {
  case didBecomeActive
  case willResignActive
  case didEnterBackground
  case willEnterForeground
}

/// The app's own lifecycle transitions, as a publisher. Inbound, like the URL
/// and notification handlers beside it — the system decides when these arrive
/// — and consumed differently: every subscriber gets every event, so there is
/// no priority and nothing to claim.
///
/// It is a port because the notification centre carrying these transitions is
/// process-wide. A feature that subscribes to that centre directly is only
/// testable by posting real lifecycle notifications into the process running
/// the tests, where they reach every other test doing the same. Depend on
/// this protocol instead: a test takes the generated double, or constructs
/// `NotificationCenterAppLifecycle` over a private `NotificationCenter()` and
/// posts into that.
///
/// **Delivery**: the publisher adds no `receive(on:)` hop, so an event
/// arrives on the thread that posted the notification — the main thread, for
/// UIKit's own lifecycle notifications. A hop would deliver
/// `willResignActive` a runloop turn late, after the snapshot the system
/// takes.
///
/// sourcery: CreateMock
public protocol AppLifecycleObserving: AnyObject {
  /// Every transition, in the order the notification centre posts them.
  /// Multiple subscribers are fine; each gets its own subscription.
  var appLifecycle: AnyPublisher<AppLifecycleEvent, Never> { get }
}

/// Notification-centre-backed default: one entry per notification name,
/// carrying the event that name means.
///
/// The map is a parameter rather than a built-in list, which is what lets the
/// mapping compile and run its logical tests on every lane this package
/// builds on, and lets a host whose lifecycle notifications carry other names
/// use the same type. An app takes `init(center:)` below, which fills in
/// UIKit's four names.
public final class NotificationCenterAppLifecycle: AppLifecycleObserving {

  public let appLifecycle: AnyPublisher<AppLifecycleEvent, Never>

  /// - Parameters:
  ///   - center: the centre to observe — `.default` in an app, a private
  ///     `NotificationCenter()` in a test so posts stay inside that test.
  ///   - events: the notification name that means each event. A name absent
  ///     from the map is never subscribed to, and an event absent from the
  ///     map is never emitted.
  public init(center: NotificationCenter, events: [Notification.Name: AppLifecycleEvent]) {
    let streams = events.map { name, event in
      center.publisher(for: name).map { _ in event }.eraseToAnyPublisher()
    }
    appLifecycle = Publishers.MergeMany(streams).eraseToAnyPublisher()
  }
}

#if canImport(UIKit)

import UIKit

extension NotificationCenterAppLifecycle {
  /// The four transitions over UIKit's notification names — the form an app
  /// constructs at its composition root.
  public convenience init(center: NotificationCenter = .default) {
    self.init(
      center: center,
      events: [
        UIApplication.didBecomeActiveNotification: .didBecomeActive,
        UIApplication.willResignActiveNotification: .willResignActive,
        UIApplication.didEnterBackgroundNotification: .didEnterBackground,
        UIApplication.willEnterForegroundNotification: .willEnterForeground,
      ])
  }
}

#endif
