// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import DuetShells
import Foundation
import os.log

// The inbound worker: everything the system hands TO the app. Features
// register URL (and, on iOS, push) handlers and get lifetime-bound
// cancellables back; the app delegates forward incoming events here and the
// first matching handler in priority order takes them; lifecycle transitions
// arrive as a publisher, because every subscriber wants every event and there
// is nothing to arbitrate. The URL and lifecycle halves are platform-neutral
// (present on the macOS host lane, where their logical tests run); the push
// half is UIKit-guarded.

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "duet.appservices", category: "AppServices")

/// The one inbound worker, adopted at the composition root
/// (`host.adopt(inboundAppServices)`). Registrations survive for the mount's
/// duration or until their cancellable is torn down, whichever ends first.
///
/// Main-actor isolated via `InboundAppServicesWorking` — the annotation sits
/// on the PROTOCOL, so the isolation reaches every consumer of the seam (the
/// worker rule in the duet framework's docs/workers.md). The registries need
/// no lock: registration, dispatch, and the returned cancellables' closures
/// all run on the main actor — each closure is non-Sendable and formed in an
/// isolated method, so it inherits the isolation. One contract the compiler
/// does not check: an `AnyCancellable` runs its closure from `deinit` on
/// whatever thread drops the last reference, so registration tokens must be
/// owned by main-actor code (the composition root's are).
///
/// The lifecycle members are `nonisolated`: they read two immutable
/// `Sendable` properties and build a publisher per subscription, so a
/// subscriber off the main actor reads them without a hop.
@MainActor
public final class InboundAppServicesWorker: InboundAppServicesWorking {

  private var urlHandlers: [(URLHandling, AppServicePriority)] = []

  /// The launch window's state (`AppServicesRegistrationSettling`).
  /// `handlersSettled` flips once, at `handlersDidRegister()`, and never back.
  private var handlersSettled = false
  private var launchURLBuffer: [URL] = []

  /// Backstop, not a design parameter: the pre-settle window is roughly one
  /// runloop turn, so the cap is only ever reached if the registrar never
  /// runs. Overflow is dropped with a log line rather than growing unbounded.
  private static let launchBufferLimit = 8

  /// Where lifecycle notifications come from. Injected rather than reached
  /// for, so a test posts into a `NotificationCenter()` of its own instead of
  /// into the one every other test in the process is listening to.
  nonisolated private let notificationCenter: NotificationCenter

  /// The notification name that means each lifecycle event. A parameter
  /// rather than a built-in list, which is what lets the mapping compile and
  /// run its logical tests on every lane this package builds on, and lets a
  /// host whose lifecycle notifications carry other names use the same
  /// worker. A name absent from the map is never subscribed to, and an event
  /// absent from the map is never emitted.
  nonisolated private let lifecycleEvents: [Notification.Name: AppLifecycleEvent]

  /// - Parameters:
  ///   - notificationCenter: the centre to observe for lifecycle transitions
  ///     — `.default` in an app, which is where UIKit posts; a private
  ///     `NotificationCenter()` in a test, so posts stay inside that test.
  ///   - lifecycleEvents: the notification name that means each event.
  ///     Defaults to `platformLifecycleEvents`, UIKit's four names.
  public init(
    notificationCenter: NotificationCenter = .default,
    lifecycleEvents: [Notification.Name: AppLifecycleEvent] = InboundAppServicesWorker.platformLifecycleEvents
  ) {
    self.notificationCenter = notificationCenter
    self.lifecycleEvents = lifecycleEvents
  }

  // MARK: - Working

  /// No owned subscriptions — the bracket parks until host teardown; the
  /// registries stay live for the mount's duration, and each lifecycle
  /// subscriber owns its own subscription.
  public func run() async {
    await untilCancelled()
  }

  // MARK: - AppServicesURLHandlerRegistering

  public func registerURLHandler(
    _ handler: URLHandling, priority: AppServicePriority
  ) -> AnyCancellable {
    if let index = urlHandlers.firstIndex(where: { $0.0 === handler }) {
      urlHandlers[index].1 = priority
    } else {
      urlHandlers.append((handler, priority))
    }

    return AnyCancellable { [weak self] in
      self?.urlHandlers.removeAll(where: { $0.0 === handler })
    }
  }

  // MARK: - AppServicesRegistrationSettling

  public func handlersDidRegister() {
    let bufferedURLs = launchURLBuffer
    let urlClaimants = sortedURLHandlers()
    #if canImport(UIKit)
    let tokenClaimants = notificationHandlers.map { $0.0 }
    #endif
    launchURLBuffer.removeAll()
    handlersSettled = true

    // Snapshot first (BOTH registries), then dispatch: a handler callback can
    // re-enter this class (the ingress worker registers and drains in one
    // bracket), and the drain must see the registries as they stood when the
    // burst completed. The full sorted registry is used, so a high-priority
    // handler registered LATE in the burst still out-ranks a catch-all
    // registered early.
    if !bufferedURLs.isEmpty {
      logger.info("url dispatch: draining \(bufferedURLs.count, privacy: .public) buffered URL(s)")
      dispatch(bufferedURLs, to: urlClaimants)
    }

    #if canImport(UIKit)
    if let deviceToken = pendingDeviceToken {
      pendingDeviceToken = nil
      if tokenClaimants.isEmpty {
        logger.error("apns: buffered device token dropped — no notification handler registered")
      } else {
        logger.info("apns: delivering buffered device token")
        for handler in tokenClaimants {
          handler.appDidRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
      }
    }
    #endif
  }

  // MARK: - AppServiceURLHandling

  public func openURLs(_ urls: [URL]) {
    guard handlersSettled else {
      buffer(urls)
      return
    }
    dispatch(urls, to: sortedURLHandlers())
  }

  // MARK: - Private (URL dispatch)

  private func sortedURLHandlers() -> [URLHandling] {
    urlHandlers.sorted(by: { $0.1.rawValue > $1.1.rawValue }).map { $0.0 }
  }

  /// Logs the scheme and nothing else: a link's path and query are where an
  /// app's secrets ride (an invite token, a one-time code).
  private func buffer(_ urls: [URL]) {
    for url in urls {
      guard launchURLBuffer.count < Self.launchBufferLimit else {
        logger.error(
          """
          url dispatch: launch buffer full — dropped \(url.scheme ?? "?", privacy: .public) \
          (the registrar's handlersDidRegister() has not run)
          """)
        continue
      }
      launchURLBuffer.append(url)
      logger.info(
        "url dispatch: buffered \(url.scheme ?? "?", privacy: .public) (handlers not registered yet)"
      )
    }
  }

  private func dispatch(_ urls: [URL], to handlers: [URLHandling]) {
    for url in urls {
      var claimed = false
      for handler in handlers where handler.canHandleOpenUrl(url) {
        handler.handleOpenUrl(url)
        claimed = true
        break
      }
      if !claimed {
        // Scheme and host only — the path is where the secret lives.
        logger.error(
          "url dispatch: no handler claimed \(url.scheme ?? "?", privacy: .public)://\(url.host ?? "?", privacy: .public)"
        )
      }
    }
  }

  // MARK: - AppLifecycleObserving

  /// Built per subscription rather than stored: a stored `AnyPublisher` is
  /// not `Sendable`, and the merge holds nothing worth sharing — the current
  /// implementation already gives every subscriber its own subscription.
  nonisolated public var appLifecycle: AnyPublisher<AppLifecycleEvent, Never> {
    let streams = lifecycleEvents.map { name, event in
      notificationCenter.publisher(for: name).map { _ in event }.eraseToAnyPublisher()
    }
    return Publishers.MergeMany(streams).eraseToAnyPublisher()
  }

  #if canImport(UIKit)

  private var notificationHandlers: [(NotificationHandling, AppServicePriority)] = []

  /// The APNS twin of the URL buffer — last token wins, because a device
  /// token is a current value rather than a stream of events.
  private var pendingDeviceToken: Data?

  // MARK: - AppServicesAPNSHandlerRegistering

  public func registerAPNSNotificationsHandler(
    _ handler: NotificationHandling, priority: AppServicePriority
  ) -> AnyCancellable {
    if let index = notificationHandlers.firstIndex(where: { $0.0 === handler }) {
      notificationHandlers[index].1 = priority
    } else {
      notificationHandlers.append((handler, priority))
    }

    return AnyCancellable { [weak self] in
      self?.notificationHandlers.removeAll(where: { $0.0 === handler })
    }
  }

  // MARK: - AppServiceNotificationHandling

  public func appDidRegisterForRemoteNotifications(deviceToken: Data) {
    guard handlersSettled else {
      pendingDeviceToken = deviceToken
      logger.info("apns: buffered device token (handlers not registered yet)")
      return
    }
    for handler in notificationHandlers.map({ $0.0 }) {
      handler.appDidRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
  }

  public func appDidReceiveRemoteNotification(
    notification: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    let handlers = notificationHandlers.sorted(by: { $0.1.rawValue > $1.1.rawValue }).map { $0.0 }

    for handler in handlers {
      if handler.canHandleRemoteNotification(
        notification: notification, fetchCompletionHandler: completionHandler
      ) {
        handler.handleRemoteNotification(
          notification: notification, fetchCompletionHandler: completionHandler)
        return
      }
    }
  }

  #endif
}

#if canImport(UIKit)

import UIKit

extension InboundAppServicesWorker {
  /// UIKit's four lifecycle notification names, mapped to the events they
  /// mean — the default an app gets by constructing the worker with no
  /// arguments.
  nonisolated public static var platformLifecycleEvents: [Notification.Name: AppLifecycleEvent] {
    [
      UIApplication.didBecomeActiveNotification: .didBecomeActive,
      UIApplication.willResignActiveNotification: .willResignActive,
      UIApplication.didEnterBackgroundNotification: .didEnterBackground,
      UIApplication.willEnterForegroundNotification: .willEnterForeground,
    ]
  }
}

#else

extension InboundAppServicesWorker {
  /// Empty on a lane with no UIKit: there are no platform lifecycle
  /// notifications to observe, and a test that wants the mapping passes its
  /// own.
  nonisolated public static var platformLifecycleEvents: [Notification.Name: AppLifecycleEvent] {
    [:]
  }
}

#endif
