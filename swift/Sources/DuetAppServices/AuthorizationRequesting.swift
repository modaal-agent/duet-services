// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

// The two permission prompts, as ports. Both signatures are platform-neutral
// — no framework type appears in either — so a feature that asks for a
// permission compiles and runs its logical tests on every lane this package
// builds on, and takes a generated double there. The implementations are
// iOS-bound and live in `OutboundAppServicesWorker`.

/// The App Tracking Transparency prompt.
///
/// The system shows it once per install: a request made while the status is
/// anything other than "not determined" returns the standing answer and
/// displays nothing. Depend on this port rather than calling the tracking
/// manager, so a feature's test asserts the request instead of driving a
/// system alert.
///
/// sourcery: CreateMock
public protocol AppTrackingAuthorizationRequesting: AnyObject {
  /// Shows the prompt when the status is not yet determined; does nothing
  /// otherwise. Fire-and-forget — read `ATTrackingManager`'s status once the
  /// prompt resolves if the app needs the answer.
  func requestTrackingAuthorizationIfNeeded()
}

/// The push-notification permission prompt, together with the remote-
/// notification registration it gates.
///
/// Registration is what produces the APNS device token, which the app
/// delegate hands to `AppServicesWorker.appDidRegisterForRemoteNotifications(deviceToken:)`
/// and the worker dispatches to the registered `NotificationHandling`
/// conformers. Without a call to this port nothing registers and no token
/// arrives.
///
/// sourcery: CreateMock
public protocol PushNotificationAuthorizationRequesting: AnyObject {
  /// Prompts when the authorization status is not yet determined and
  /// registers for remote notifications once permission is in hand; registers
  /// straight away when permission already exists; does nothing when the user
  /// has denied it.
  ///
  /// The default requests `[.alert, .badge, .sound]`. An app that needs
  /// `.provisional` or `.criticalAlert` adds a second method to this port
  /// rather than widening this one — the option set is part of what the call
  /// site means, and callers that want the plain prompt should not have to
  /// name it.
  func requestPushAuthorizationIfNeeded()
}
