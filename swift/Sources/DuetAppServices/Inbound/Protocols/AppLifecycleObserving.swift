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
/// `InboundAppServicesWorker` over a private `NotificationCenter()` and posts
/// into that.
///
/// **Isolation**: nonisolated, and `InboundAppServicesWorker` witnesses it
/// with `nonisolated` members, so a subscriber off the main actor reads the
/// publisher without a hop. The registry half of that worker is main-actor
/// isolated; this half holds no mutable state to guard.
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
