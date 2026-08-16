// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import DuetShells
import Foundation

// The inbound registry worker: features register URL (and, on iOS, push)
// handlers and get lifetime-bound cancellables back; the app delegates
// forward incoming events here and the first matching handler in priority
// order takes them. The URL half is platform-neutral (present on the macOS
// host lane, where its logical tests run); the push half is UIKit-guarded.

/// sourcery: CreateMock
@MainActor
public protocol AppServicesURLHandlerRegistering {
  func registerURLHandler(
    _ handler: URLHandling, priority: AppServicePriority
  ) -> AnyCancellable
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
                                        AppServicesAPNSHandlerRegistering {
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
public protocol AppServicesRegistering: AppServicesURLHandlerRegistering {
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

  // MARK: - AppServiceURLHandling

  public func openURLs(_ urls: [URL]) {
    let handlers = urlHandlers.sorted(by: { $0.1.rawValue > $1.1.rawValue }).map { $0.0 }

    for url in urls {
      for handler in handlers where handler.canHandleOpenUrl(url) {
        handler.handleOpenUrl(url)
        break
      }
    }
  }

  #if canImport(UIKit)

  private var notificationHandlers: [(NotificationHandling, AppServicePriority)] = []

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
