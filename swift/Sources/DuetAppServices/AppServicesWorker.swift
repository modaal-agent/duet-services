// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import DuetShells
import Foundation
import os.log

// The inbound registry worker: features register URL (and, on iOS, push)
// handlers and get lifetime-bound cancellables back; the app delegates
// forward incoming events here and the first matching handler in priority
// order takes them. The URL half is platform-neutral (present on the macOS
// host lane, where its logical tests run); the push half is UIKit-guarded.

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "duet.appservices", category: "AppServices")

/// sourcery: CreateMock
@MainActor
public protocol AppServicesURLHandlerRegistering {
  func registerURLHandler(
    _ handler: URLHandling, priority: AppServicePriority
  ) -> AnyCancellable
}

/// The launch window's end. Registration is asynchronous — handlers register
/// from the ingress worker's `run()`, which `StoreHost.adopt` starts on its
/// own task — while the scene's cold-launch drain is synchronous. Until the
/// registrar says the burst is complete, `AppServicesWorker` BUFFERS inbound
/// events instead of dispatching them into a registry that is still filling,
/// so a launch-tapped universal link is handled rather than dropped.
///
/// sourcery: CreateMock
@MainActor
public protocol AppServicesRegistrationSettling {
  /// Signals that the registration burst is COMPLETE: buffered events drain
  /// now, in arrival order, against the full priority-ordered registry.
  ///
  /// Draining per-REGISTRATION instead of per-BURST would be wrong — a
  /// lower-priority catch-all registered first would take a URL a
  /// higher-priority handler later in the same burst is meant to claim.
  ///
  /// Idempotent, and one-way: the worker is built once per scene, so a shell
  /// remount cannot re-open the buffer mid-session.
  ///
  /// **Invariant**: ONE registrar calls this — the app's ingress worker, the
  /// same code that registers the handlers. A second registrar means the
  /// signal moves to wherever "all handlers are up" becomes true.
  func handlersDidRegister()
}

/// sourcery: CreateMock
@MainActor
public protocol AppServiceURLHandling: AnyObject {
  /// Dispatch inbound URLs (cold-launch context lists and warm opens alike)
  /// to the first registered handler that claims each one.
  func openURLs(_ urls: [URL])
}

public extension AppServiceURLHandling {
  func openURL(_ url: URL) {
    openURLs([url])
  }
}

#if canImport(UIKit)
import UIKit

// NOT CreateMock-annotated: declared in a platform-conditional block, and a
// generated mock is unconditional — the macOS host lane cannot compile the
// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServicesAPNSHandlerRegistering {
  func registerAPNSNotificationsHandler(
    _ handler: NotificationHandling, priority: AppServicePriority
  ) -> AnyCancellable
}

// NOT CreateMock-annotated: declared in a platform-conditional block, and a
// generated mock is unconditional — the macOS host lane cannot compile the
// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServicesRegistering: AppServicesURLHandlerRegistering,
                                        AppServicesAPNSHandlerRegistering,
                                        AppServicesRegistrationSettling {
}

// NOT CreateMock-annotated: declared in a platform-conditional block, and a
// generated mock is unconditional — the macOS host lane cannot compile the
// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServiceNotificationHandling: AnyObject {
  func appDidRegisterForRemoteNotifications(deviceToken: Data)
  func appDidReceiveRemoteNotification(
    notification: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

// NOT CreateMock-annotated: declared in a platform-conditional block, and a
// generated mock is unconditional — the macOS host lane cannot compile the
// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServicesWorking: Working, AppServicesRegistering,
                                    AppServiceURLHandling, AppServiceNotificationHandling {
}
#else
// NOT CreateMock-annotated: declared in a platform-conditional block, and a
// generated mock is unconditional — the macOS host lane cannot compile the
// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServicesRegistering: AppServicesURLHandlerRegistering,
                                        AppServicesRegistrationSettling {
}

// NOT CreateMock-annotated: declared in a platform-conditional block, and a
// generated mock is unconditional — the macOS host lane cannot compile the
// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServicesWorking: Working, AppServicesRegistering, AppServiceURLHandling {
}
#endif

/// The one registry worker, adopted at the composition root
/// (`host.adopt(appServicesWorker)`). Registrations survive for the mount's
/// duration or until their cancellable is torn down, whichever ends first.
///
/// Main-actor isolated via `AppServicesWorking` — the annotation sits on the
/// PROTOCOL, so the isolation reaches every consumer of the seam (the worker
/// rule in the duet framework's docs/workers.md). The registries need no
/// lock: registration, dispatch, and the returned cancellables' closures all
/// run on the main actor — each closure is non-Sendable and formed in an
/// isolated method, so it inherits the isolation. One contract the compiler
/// does not check: an `AnyCancellable` runs its closure from `deinit` on
/// whatever thread drops the last reference, so registration tokens must be
/// owned by main-actor code (the composition root's are).
@MainActor
public final class AppServicesWorker: AppServicesWorking {

  private var urlHandlers: [(URLHandling, AppServicePriority)] = []

  /// The launch window's state (`AppServicesRegistrationSettling`).
  /// `handlersSettled` flips once, at `handlersDidRegister()`, and never back.
  private var handlersSettled = false
  private var launchURLBuffer: [URL] = []

  /// Backstop, not a design parameter: the pre-settle window is roughly one
  /// runloop turn, so the cap is only ever reached if the registrar never
  /// runs. Overflow is dropped with a log line rather than growing unbounded.
  private static let launchBufferLimit = 8

  public init() {}

  // MARK: - Working

  /// No owned subscriptions — the bracket parks until host teardown; the
  /// registries stay live for the mount's duration.
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
