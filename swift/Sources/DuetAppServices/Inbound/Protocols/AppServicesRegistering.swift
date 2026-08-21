// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import Foundation

/// Registration API for features that want inbound URLs. The returned
/// `AnyCancellable` unregisters the handler when it is cancelled or dropped,
/// so bind it to the registering worker's lifetime — the registry holds
/// handlers strongly until then.
///
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
/// registrar says the burst is complete, `InboundAppServicesWorker` BUFFERS
/// inbound events instead of dispatching them into a registry that is still
/// filling, so a launch-tapped universal link is handled rather than dropped.
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

/// Composed registration API — what a composition root hands to the feature
/// that registers handlers, so the feature sees the registry and none of the
/// dispatch surface.
///
/// NOT CreateMock-annotated: declared in a platform-conditional block, and a
/// generated mock is unconditional — the macOS host lane cannot compile the
/// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServicesRegistering: AppServicesURLHandlerRegistering,
                                        AppServicesAPNSHandlerRegistering,
                                        AppServicesRegistrationSettling {
}
#else
/// Composed registration API — the URL half alone on a lane with no UIKit,
/// where there is no APNS registration to compose.
///
/// NOT CreateMock-annotated: declared in a platform-conditional block, and a
/// generated mock is unconditional — the macOS host lane cannot compile the
/// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServicesRegistering: AppServicesURLHandlerRegistering,
                                        AppServicesRegistrationSettling {
}
#endif
