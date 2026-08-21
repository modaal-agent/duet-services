// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// The push-notification permission prompt, together with the remote-
/// notification registration it gates.
///
/// The signature is platform-neutral — no framework type appears in it — so a
/// feature that asks for the permission compiles and runs its logical tests
/// on every lane this package builds on, and takes a generated double there.
/// The implementation is iOS-bound and lives in
/// `OutboundAppServicesWorker`.
///
/// Registration is what produces the APNS device token, which the app
/// delegate hands to
/// `AppServiceNotificationHandling.appDidRegisterForRemoteNotifications(deviceToken:)`
/// and `InboundAppServicesWorker` dispatches to the registered
/// `NotificationHandling` conformers. Without a call to this port nothing
/// registers and no token arrives.
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
